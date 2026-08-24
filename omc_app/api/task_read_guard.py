from __future__ import annotations

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
    """Current open ERP assignments.

    Retained as a compatibility helper for non-mobile internal code/tests.
    Mobile task visibility no longer depends on assignment ownership.
    """
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
    """Compatibility helper only; not a mobile task visibility boundary."""
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
    """Optional OMC enrichment for ERP Tasks.

    An ERP Task does not need an OMC Service Request link to be visible.
    """
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
    result: dict[str, dict[str, Any]] = {}

    # Rows are newest first. Preserve the first link only if legacy data
    # contains more than one request pointing at the same ERP Task.
    for row in rows:
        task_name = _text(row.get("erp_task"))
        if task_name and task_name not in result:
            result[task_name] = row

    return result


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


def _task_fields() -> list[str]:
    meta = frappe.get_meta("Task")
    fields = [
        "name",
        "subject",
        "status",
        "priority",
        "creation",
        "modified",
    ]

    for fieldname in (
        "description",
        "task_details",
        "workflow_state",
        "custom_operation_status",
        "type",
        "customer",
        "full_name",
        "source",
        "company",
        "progress",
        "exp_start_date",
        "exp_end_date",
        "due_date",
        "expected_end_date",
        "actual_end_date",
        "completed_on",
    ):
        if meta.has_field(fieldname):
            fields.append(fieldname)

    return fields


def _erp_task_rows(
    *,
    limit_start: int,
    limit_page_length: int,
    search: str = "",
    status: str = "",
    priority: str = "",
):
    """Read directly from ERP Task, which is the tracking source of truth."""
    clean_search = _text(search)[:140]
    clean_status = _text(status)
    clean_priority = _text(priority)

    filters: dict[str, Any] = {}
    if clean_status:
        filters["status"] = clean_status
    if clean_priority:
        filters["priority"] = clean_priority

    kwargs: dict[str, Any] = {
        "filters": filters,
        "fields": _task_fields(),
        "order_by": "modified desc, name desc",
        "limit_start": limit_start,
        "limit_page_length": limit_page_length,
    }

    if clean_search:
        like_value = f"%{clean_search}%"
        meta = frappe.get_meta("Task")
        searchable = ["name", "subject"]
        if meta.has_field("description"):
            searchable.append("description")

        kwargs["or_filters"] = [
            ["Task", fieldname, "like", like_value]
            for fieldname in searchable
        ]

    return frappe.get_all("Task", **kwargs)


def _task_assignment_display_map(
    task_names: set[str],
) -> dict[str, list[str]]:
    """Resolve display assignees without N+1 queries.

    Open ToDo assignments are preferred. For terminal tasks whose ToDos were
    closed/cancelled, the latest historical assignee is retained for tracking.
    """
    clean_names = {_text(name) for name in task_names if _text(name)}
    if not clean_names:
        return {}

    result: dict[str, list[str]] = {}
    query_limit = max(200, len(clean_names) * 20)

    open_rows = frappe.get_all(
        "ToDo",
        filters={
            "reference_type": "Task",
            "reference_name": ["in", sorted(clean_names)],
            "status": "Open",
        },
        fields=["reference_name", "allocated_to"],
        order_by="creation asc",
        limit_page_length=query_limit,
    )

    for row in open_rows:
        task_name = _text(row.get("reference_name"))
        user = _text(row.get("allocated_to"))
        if not task_name or not user:
            continue
        users = result.setdefault(task_name, [])
        if user not in users:
            users.append(user)

    missing = clean_names.difference(result)
    if missing:
        historical_rows = frappe.get_all(
            "ToDo",
            filters={
                "reference_type": "Task",
                "reference_name": ["in", sorted(missing)],
            },
            fields=[
                "reference_name",
                "allocated_to",
                "status",
                "creation",
                "modified",
            ],
            order_by="modified desc, creation desc",
            limit_page_length=max(200, len(missing) * 20),
        )

        for row in historical_rows:
            task_name = _text(row.get("reference_name"))
            user = _text(row.get("allocated_to"))
            if (
                task_name
                and user
                and task_name not in result
            ):
                result[task_name] = [user]

    return result


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


def _task_expected_start_date(task) -> str:
    value = getattr(task, "exp_start_date", None)
    return str(value) if value else ""


def _task_to_payload(
    task,
    request_link: dict[str, Any] | None = None,
    *,
    assigned_users: list[str] | None = None,
    can_view_linked_service_case: bool = False,
) -> dict[str, Any]:
    request_link = request_link or {}

    if assigned_users is None:
        assigned_users = _task_assignment_display_map(
            {_text(task.name)}
        ).get(_text(task.name), [])

    service_request_assignee = _text(
        request_link.get("assigned_staff")
    )

    if not assigned_users and service_request_assignee:
        assigned_users = [service_request_assignee]

    assigned_to = assigned_users[0] if assigned_users else ""

    erp_status = _text(getattr(task, "status", None)) or "Open"
    operation_status = _text(
        getattr(task, "custom_operation_status", None)
    )
    # ERPNext Task.status is the canonical tracking authority.
    # custom_operation_status is supplemental metadata only.
    display_status = erp_status

    return {
        "name": task.name,
        "title": _text(
            getattr(task, "subject", None)
            or getattr(task, "title", None)
            or getattr(task, "task_name", None)
        ),
        "description": _task_description(task),
        "status": display_status,
        "display_status": display_status,
        "erp_status": erp_status,
        "workflow_state": _text(
            getattr(task, "workflow_state", None)
        ),
        "operation_status": operation_status,

        # Direct ERP Task context. These are display-only tracking fields.
        "task_type": _text(getattr(task, "type", None)),
        "customer": _text(getattr(task, "customer", None)),
        "customer_name": _text(
            getattr(task, "full_name", None)
            or getattr(task, "customer", None)
        ),
        "source": _text(getattr(task, "source", None)),
        "company": _text(getattr(task, "company", None)),
        "progress": getattr(task, "progress", None),
        "expected_start_date": _task_expected_start_date(task),

        # OMC mobile is a tracking surface only. ERPNext is the sole write
        # authority for Task status, assignment and planning.
        "allowed_transitions": [],
        "can_manage_tasks": False,
        "can_manage_assigned_tasks": False,
        "read_only": True,
        "write_authority": "ERPNext",

        "priority": _text(getattr(task, "priority", None)) or "Normal",
        "due_date": _task_due_date(task),
        "assigned_to": assigned_to,
        "assigned_users": list(assigned_users),
        "customer_profile": _text(
            request_link.get("customer_profile")
        ),
        "service_request": _text(request_link.get("name")),
        "can_view_linked_service_case": bool(
            can_view_linked_service_case
            and _text(request_link.get("name"))
        ),
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


def _linked_case_is_readable(
    request_link: dict[str, Any] | None,
    allowed_case_names: list[str] | set[str] | None,
) -> bool:
    case_name = _text((request_link or {}).get("name"))
    if not case_name:
        return False
    if allowed_case_names is None:
        return True
    return case_name in allowed_case_names


def _can_read_task(
    task_name: str,
    *,
    user: str,
    capabilities: dict[str, Any],
) -> bool:
    # All approved/current internal staff share the same read-only ERP Task
    # tracking universe. Assignment is display data, not authorization.
    return bool(capabilities.get("can_view_tasks"))


@frappe.whitelist()
def get_tasks(
    limit_start=0,
    page_length=None,
    search=None,
    status=None,
    priority=None,
):
    user = mobile._assert_internal_workspace_access()
    capabilities = mobile._require_canonical_capability(
        "can_view_tasks",
        message="You do not have permission to view tasks.",
    )
    allowed_case_names = mobile._service_case_scope_names(
        capabilities,
        user,
    )
    if allowed_case_names is not None:
        allowed_case_names = set(allowed_case_names)

    start = _non_negative_int(limit_start)
    limit = _page_length(page_length)

    rows = _erp_task_rows(
        limit_start=start,
        limit_page_length=limit + 1,
        search=_text(search),
        status=_text(status),
        priority=_text(priority),
    )

    has_more = len(rows) > limit
    page_rows = rows[:limit]
    task_names = {
        _text(row.name)
        for row in page_rows
        if _text(row.name)
    }

    request_links = _request_links(
        task_names=task_names,
        limit_page_length=max(100, len(task_names) * 2),
    )
    link_map = _request_link_map(request_links)
    assignment_map = _task_assignment_display_map(task_names)

    tasks = [
        _task_to_payload(
            task,
            link_map.get(_text(task.name)),
            assigned_users=assignment_map.get(_text(task.name), []),
            can_view_linked_service_case=_linked_case_is_readable(
                link_map.get(_text(task.name)),
                allowed_case_names,
            ),
        )
        for task in page_rows
    ]

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
        "can_view_tasks",
        message="You do not have permission to view tasks.",
    )
    allowed_case_names = mobile._service_case_scope_names(
        capabilities,
        user,
    )
    if allowed_case_names is not None:
        allowed_case_names = set(allowed_case_names)

    clean_task_id = _text(task_id)
    if not clean_task_id:
        frappe.throw("task_id is required")

    task = _load_task(clean_task_id)

    # OMC linkage is optional enrichment; it is never a prerequisite for
    # internal staff to inspect an ERP Task.
    request_link = _request_link(clean_task_id)
    assignment_map = _task_assignment_display_map({clean_task_id})

    return {
        "task": _task_to_payload(
            task,
            request_link,
            assigned_users=assignment_map.get(clean_task_id, []),
            can_view_linked_service_case=_linked_case_is_readable(
                request_link,
                allowed_case_names,
            ),
        )
    }
