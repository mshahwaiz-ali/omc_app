from __future__ import annotations

import json
from typing import Any

import frappe

from omc_app.api import mobile


DEFAULT_PAGE_LENGTH = 100
MAX_PAGE_LENGTH = 100


def _text(value: Any) -> str:
    return str(value or "").strip()


def _task_not_found():
    frappe.throw("Task not found", frappe.DoesNotExistError)


def _assigned_users(task_name: str) -> list[str]:
    users = frappe.get_all(
        "ToDo",
        filters={
            "reference_type": "Task",
            "reference_name": task_name,
            "status": "Open",
        },
        pluck="allocated_to",
        order_by="creation asc",
    )
    return [user for user in users if _text(user)]


def _task_assignment_names(user: str) -> set[str]:
    if not user:
        return set()
    return set(
        frappe.get_all(
            "ToDo",
            filters={
                "reference_type": "Task",
                "allocated_to": user,
                "status": "Open",
            },
            pluck="reference_name",
        )
    )


def _request_links(
    *,
    task_names: set[str] | None = None,
    limit_start: int = 0,
    limit_page_length: int = DEFAULT_PAGE_LENGTH,
) -> list[dict[str, Any]]:
    if task_names is not None and not task_names:
        return []

    filters: dict[str, Any] = {"erp_task": ["is", "set"]}
    if task_names is not None:
        filters["erp_task"] = ["in", sorted(task_names)]

    return frappe.get_all(
        "OMC Service Request",
        filters=filters,
        fields=[
            "name",
            "erp_task",
            "erp_service",
            "customer_profile",
            "assigned_staff",
        ],
        order_by="modified desc, name desc",
        limit_start=limit_start,
        limit_page_length=limit_page_length,
    )


def _request_link_map(
    rows: list[dict[str, Any]],
) -> dict[str, dict[str, Any]]:
    return {
        _text(row.get("erp_task")): row
        for row in rows
        if _text(row.get("erp_task"))
    }


def _request_link(task_name: str) -> dict[str, Any] | None:
    clean_task_name = _text(task_name)
    if not clean_task_name:
        return None

    rows = _request_links(
        task_names={clean_task_name},
        limit_page_length=1,
    )
    return rows[0] if rows else None


def _non_negative_int(value: Any, *, default: int = 0) -> int:
    try:
        return max(0, int(value))
    except (TypeError, ValueError):
        return default


def _page_length(value: Any) -> int:
    requested = _non_negative_int(value, default=DEFAULT_PAGE_LENGTH)
    if requested < 1:
        requested = DEFAULT_PAGE_LENGTH
    return min(requested, MAX_PAGE_LENGTH)


def _load_task(task_id: str):
    if not task_id or not frappe.db.exists("Task", task_id):
        _task_not_found()
    return frappe.get_doc("Task", task_id)


def _task_description(task) -> str:
    return _text(
        getattr(task, "description", None)
        or getattr(task, "task_details", None)
    )


def _task_due_date(task) -> str:
    value = (
        getattr(task, "exp_end_date", None)
        or getattr(task, "due_date", None)
        or getattr(task, "expected_end_date", None)
    )
    return str(value) if value else ""


def _task_completed_on(task) -> str:
    value = (
        getattr(task, "actual_end_date", None)
        or getattr(task, "completed_on", None)
    )
    return str(value) if value else ""


def _task_to_payload(task, request_link: dict[str, Any]) -> dict[str, Any]:
    assigned_users = _assigned_users(task.name)
    service_request_assignee = _text(request_link.get("assigned_staff"))

    # Open ToDo assignments are the live ERP Task authority. Terminal tasks have
    # their ToDos closed, so preserve the linked service request's canonical
    # assignee as the display fallback instead of incorrectly showing Unassigned.
    assigned_to = (
        assigned_users[0]
        if assigned_users
        else service_request_assignee
    )
    payload_assigned_users = (
        assigned_users
        if assigned_users
        else ([service_request_assignee] if service_request_assignee else [])
    )

    return {
        "name": task.name,
        "title": _text(
            getattr(task, "subject", None)
            or getattr(task, "title", None)
            or getattr(task, "task_name", None)
        ),
        "description": _task_description(task),
        "status": _text(getattr(task, "custom_operation_status", None))
        or _text(getattr(task, "status", None)),
        "priority": _text(getattr(task, "priority", None)) or "Normal",
        "due_date": _task_due_date(task),
        "assigned_to": assigned_to,
        "assigned_users": payload_assigned_users,
        "customer_profile": _text(request_link.get("customer_profile")),
        "service_request": _text(request_link.get("name")),
        "erp_service": _text(request_link.get("erp_service")),
        "support_ticket": "",
        "completed_on": _task_completed_on(task),
        "created_at": (
            str(task.creation)
            if getattr(task, "creation", None)
            else ""
        ),
        "updated_at": (
            str(task.modified)
            if getattr(task, "modified", None)
            else ""
        ),
        "source_doctype": "Task",
    }


def _can_read_task(
    task_name: str,
    *,
    user: str,
    capabilities: dict[str, Any],
) -> bool:
    if capabilities.get("can_manage_tasks"):
        return True
    return task_name in _task_assignment_names(user)


@frappe.whitelist()
def get_tasks(limit_start=0, page_length=None):
    user = mobile._assert_internal_workspace_access()
    capabilities = mobile._require_canonical_capability(
        "can_manage_tasks",
        "can_manage_assigned_tasks",
        message="You do not have permission to view tasks.",
    )

    start = _non_negative_int(limit_start)
    limit = _page_length(page_length)
    assigned_names = None
    if not capabilities.get("can_manage_tasks"):
        assigned_names = _task_assignment_names(user)

    rows = _request_links(
        task_names=assigned_names,
        limit_start=start,
        limit_page_length=limit + 1,
    )
    has_more = len(rows) > limit
    page_rows = rows[:limit]
    link_map = _request_link_map(page_rows)

    tasks = []
    for task_name, request_link in link_map.items():
        try:
            task = _load_task(task_name)
        except frappe.DoesNotExistError:
            continue
        tasks.append(_task_to_payload(task, request_link))

    return {
        "tasks": tasks,
        "pagination": {
            "limit_start": start,
            "page_length": limit,
            "has_more": has_more,
            "next_start": start + limit if has_more else None,
        },
    }


@frappe.whitelist()
def get_task(task_id=None):
    user = mobile._assert_internal_workspace_access()
    capabilities = mobile._require_canonical_capability(
        "can_manage_tasks",
        "can_manage_assigned_tasks",
        message="You do not have permission to view tasks.",
    )
    if not task_id:
        frappe.throw("task_id is required")

    request_link = _request_link(_text(task_id))
    if not request_link:
        _task_not_found()

    if not _can_read_task(
        _text(task_id),
        user=user,
        capabilities=capabilities,
    ):
        frappe.throw(
            "You do not have permission to view this task.",
            frappe.PermissionError,
        )

    task = _load_task(_text(task_id))
    return {"task": _task_to_payload(task, request_link)}
