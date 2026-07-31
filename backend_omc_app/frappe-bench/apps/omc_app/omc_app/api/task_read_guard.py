from __future__ import annotations

import json
from typing import Any

import frappe

from omc_app.api import mobile


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


def _request_links() -> list[dict[str, Any]]:
    return frappe.get_all(
        "OMC Service Request",
        filters={"erp_task": ["is", "set"]},
        fields=[
            "name",
            "erp_task",
            "erp_service",
            "customer_profile",
        ],
        order_by="modified desc",
        limit_page_length=100,
    )


def _request_link_map() -> dict[str, dict[str, Any]]:
    return {
        _text(row.get("erp_task")): row
        for row in _request_links()
        if _text(row.get("erp_task"))
    }


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
    assigned_to = assigned_users[0] if assigned_users else ""

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
        "assigned_users": assigned_users,
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
def get_tasks():
    user = mobile._assert_internal_workspace_access()
    capabilities = mobile._require_canonical_capability(
        "can_manage_tasks",
        "can_manage_assigned_tasks",
        message="You do not have permission to view tasks.",
    )

    link_map = _request_link_map()
    eligible_names = list(link_map)
    if not capabilities.get("can_manage_tasks"):
        assigned_names = _task_assignment_names(user)
        eligible_names = [
            name for name in eligible_names if name in assigned_names
        ]

    tasks = []
    for task_name in eligible_names:
        try:
            task = _load_task(task_name)
        except frappe.DoesNotExistError:
            continue
        tasks.append(_task_to_payload(task, link_map[task_name]))

    tasks.sort(
        key=lambda row: row.get("updated_at") or row.get("created_at") or "",
        reverse=True,
    )
    return {"tasks": tasks[:100]}


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

    link_map = _request_link_map()
    request_link = link_map.get(_text(task_id))
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
