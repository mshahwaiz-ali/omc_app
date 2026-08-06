"""Controlled mobile write adapter for OMC-linked ERP Tasks."""

from __future__ import annotations

from typing import Any

import frappe

from omc_app.api import mobile
from omc_app.api import service_assignment
from omc_app.api import task_read_guard
from omc_app.api import task_workflow_contract


ALLOWED_OPERATION_STATUSES = set(
    task_workflow_contract.OPERATION_STATUSES
)


def _text(value: Any) -> str:
    return str(value or "").strip()


def _load_linked_task(task_id: str):
    clean_task_id = _text(task_id)
    if not clean_task_id:
        frappe.throw("task_id is required")

    request_link = task_read_guard._request_link(clean_task_id)
    if not request_link:
        frappe.throw("Task not found", frappe.DoesNotExistError)

    task = task_read_guard._load_task(clean_task_id)
    return task, request_link


def _assert_write_access(
    task_name: str,
    *,
    user: str,
    capabilities: dict[str, Any],
) -> None:
    if capabilities.get("can_manage_tasks"):
        return

    if task_name not in task_read_guard._task_assignment_names(user):
        frappe.throw(
            "You do not have permission to update this task.",
            frappe.PermissionError,
        )


@frappe.whitelist()
def update_task_operation_status(
    task_id=None,
    operation_status=None,
    status=None,
    **kwargs,
):
    user = mobile._assert_internal_workspace_access()
    capabilities = mobile._require_canonical_capability(
        "can_manage_tasks",
        "can_manage_assigned_tasks",
        message="You do not have permission to update tasks.",
    )

    task, request_link = _load_linked_task(task_id)
    _assert_write_access(
        task.name,
        user=user,
        capabilities=capabilities,
    )

    requested_status = _text(
        operation_status
        or status
        or kwargs.get("custom_operation_status")
    )
    if requested_status not in ALLOWED_OPERATION_STATUSES:
        frappe.throw(
            "Unsupported task operation status.",
            frappe.ValidationError,
        )

    current_status = (
        _text(getattr(task, "custom_operation_status", None))
        or "Open"
    )
    erp_status = _text(getattr(task, "status", None))

    if current_status == requested_status:
        return {
            "task": task_read_guard._task_to_payload(
                task,
                request_link,
            ),
            "updated": False,
        }

    if erp_status in {"Completed", "Cancelled"}:
        frappe.throw(
            "A completed or cancelled ERP Task cannot be updated.",
            frappe.ValidationError,
        )

    if not task_workflow_contract.is_transition_allowed(
        current_status,
        requested_status,
    ):
        frappe.throw(
            (
                f"Task cannot move from {current_status} "
                f"to {requested_status}."
            ),
            frappe.ValidationError,
        )

    if not task.meta.has_field("custom_operation_status"):
        frappe.throw(
            "ERP Task operation status is not configured.",
            frappe.ValidationError,
        )

    previous_operation_status = current_status
    previous_task_status = _text(getattr(task, "status", None))
    previous_completed_on = getattr(task, "completed_on", None)
    task.custom_operation_status = requested_status
    task_assignment_names = []
    savepoint = "omc_task_operation_status"
    frappe.db.savepoint(savepoint)
    try:
        if requested_status == "Submitted by QC":
            # ERPNext's Task validation closes assignments through a permission
            # checked Desk helper. The temporary Cancelled state is isolated by
            # a savepoint so a failed Task save cannot corrupt assignments.
            task_assignment_names = frappe.get_all(
                "ToDo",
                filters={
                    "reference_type": "Task",
                    "reference_name": task.name,
                    "status": ["not in", ["Closed", "Cancelled"]],
                },
                pluck="name",
            )
            for assignment_name in task_assignment_names:
                frappe.db.set_value(
                    "ToDo",
                    assignment_name,
                    "status",
                    "Cancelled",
                    update_modified=False,
                )
            task.status = "Completed"
            task.completed_on = frappe.utils.now_datetime()
        task.save(ignore_permissions=True)
        for assignment_name in task_assignment_names:
            frappe.db.set_value(
                "ToDo",
                assignment_name,
                "status",
                "Closed",
                update_modified=False,
            )
    except Exception:
        frappe.db.rollback(save_point=savepoint)
        task.custom_operation_status = previous_operation_status
        task.status = previous_task_status
        task.completed_on = previous_completed_on
        raise

    return {
        "task": task_read_guard._task_to_payload(
            task,
            request_link,
        ),
        "updated": True,
    }


def _assert_assignable_user(user: str) -> None:
    clean_user = _text(user)
    if not clean_user:
        frappe.throw("assigned_to is required")

    user_row = frappe.db.get_value(
        "User",
        clean_user,
        ["name", "enabled", "user_type"],
        as_dict=True,
    )
    if not user_row or not user_row.enabled:
        frappe.throw("Selected assignee is not an active user.")

    if clean_user == "Guest" or user_row.user_type == "Website User":
        frappe.throw(
            "Selected user cannot receive internal tasks.",
            frappe.PermissionError,
        )

    capabilities = mobile.get_mobile_capabilities(user=clean_user)
    if not (
        capabilities.get("can_manage_tasks")
        or capabilities.get("can_manage_assigned_tasks")
    ):
        frappe.throw(
            "Selected user is not eligible for task assignment.",
            frappe.PermissionError,
        )


def _close_open_assignments(task_name: str) -> list[str]:
    rows = frappe.get_all(
        "ToDo",
        filters={
            "reference_type": "Task",
            "reference_name": task_name,
            "status": "Open",
        },
        fields=["name", "allocated_to"],
    )
    previous_users = []

    for row in rows:
        allocated_to = _text(row.get("allocated_to"))
        if allocated_to:
            previous_users.append(allocated_to)

        frappe.db.set_value(
            "ToDo",
            row["name"],
            "status",
            "Closed",
            update_modified=False,
        )

    return previous_users


def _create_assignment(task, assigned_to: str):
    todo = frappe.new_doc("ToDo")
    todo.allocated_to = assigned_to
    todo.reference_type = "Task"
    todo.reference_name = task.name
    todo.description = (
        _text(getattr(task, "subject", None))
        or _text(getattr(task, "task_name", None))
        or task.name
    )
    todo.status = "Open"
    todo.priority = _text(getattr(task, "priority", None)) or "Medium"
    todo.insert(ignore_permissions=True)
    return todo


@frappe.whitelist()
def get_task_assignment_options(task_id=None):
    mobile._assert_internal_workspace_access()
    capabilities = mobile._require_canonical_capability(
        "can_manage_tasks",
        message="Only task managers may view assignment options.",
    )

    if not capabilities.get("can_manage_tasks"):
        frappe.throw(
            "Only task managers may view assignment options.",
            frappe.PermissionError,
        )

    task, request_link = _load_linked_task(task_id)

    candidates = sorted(
        {
            user
            for role in service_assignment.ASSIGNABLE_SERVICE_ROLES
            for user in service_assignment.users_for_role(role)
        }
    )

    assigned_users = task_read_guard._assigned_users(task.name)

    priority_field = frappe.get_meta("Task").get_field("priority")
    priority_options = [
        option.strip()
        for option in str(getattr(priority_field, "options", "") or "").splitlines()
        if option.strip()
    ]

    return {
        "task_id": task.name,
        "current_assignee": (
            assigned_users[0]
            if assigned_users
            else _text(request_link.get("assigned_staff"))
        ),
        "priority_options": priority_options,
        "assignment_candidates": [
            {
                "user_id": user,
                "full_name": (
                    frappe.db.get_value("User", user, "full_name")
                    or user
                ),
            }
            for user in candidates
        ],
    }


@frappe.whitelist()
def assign_task(task_id=None, assigned_to=None, **kwargs):
    mobile._assert_internal_workspace_access()
    capabilities = mobile._require_canonical_capability(
        "can_manage_tasks",
        message="Only task managers may assign or reassign tasks.",
    )

    if not capabilities.get("can_manage_tasks"):
        frappe.throw(
            "Only task managers may assign or reassign tasks.",
            frappe.PermissionError,
        )

    task, request_link = _load_linked_task(task_id)
    clean_assignee = _text(assigned_to or kwargs.get("user"))
    _assert_assignable_user(clean_assignee)

    current_users = task_read_guard._assigned_users(task.name)
    if current_users == [clean_assignee]:
        return {
            "task": task_read_guard._task_to_payload(task, request_link),
            "updated": False,
            "previous_assignees": current_users,
        }

    previous_users = _close_open_assignments(task.name)
    _create_assignment(task, clean_assignee)

    request_name = _text(request_link.get("name"))
    if request_name and frappe.db.exists("OMC Service Request", request_name):
        frappe.db.set_value(
            "OMC Service Request",
            request_name,
            "assigned_staff",
            clean_assignee,
            update_modified=False,
        )

    return {
        "task": task_read_guard._task_to_payload(task, request_link),
        "updated": True,
        "previous_assignees": previous_users,
    }


ALLOWED_PRIORITIES = {"Low", "Medium", "High", "Urgent"}


def _normalise_due_date(value):
    clean_value = _text(value)
    if not clean_value:
        return None

    try:
        return frappe.utils.getdate(clean_value)
    except Exception:
        frappe.throw(
            "due_date must be a valid date.",
            frappe.ValidationError,
        )


@frappe.whitelist()
def update_task_details(
    task_id=None,
    priority=None,
    due_date=None,
    **kwargs,
):
    mobile._assert_internal_workspace_access()
    capabilities = mobile._require_canonical_capability(
        "can_manage_tasks",
        message="Only task managers may update task planning details.",
    )

    if not capabilities.get("can_manage_tasks"):
        frappe.throw(
            "Only task managers may update task planning details.",
            frappe.PermissionError,
        )

    task, request_link = _load_linked_task(task_id)

    requested_priority = _text(priority or kwargs.get("task_priority"))
    requested_due_date = (
        due_date
        if due_date is not None
        else kwargs.get("exp_end_date")
    )

    updates = {}
    if requested_priority:
        if requested_priority not in ALLOWED_PRIORITIES:
            frappe.throw(
                "Unsupported task priority.",
                frappe.ValidationError,
            )
        if _text(getattr(task, "priority", None)) != requested_priority:
            updates["priority"] = requested_priority

    if requested_due_date is not None:
        normalised_due_date = _normalise_due_date(requested_due_date)
        current_due_date = getattr(task, "exp_end_date", None)
        if current_due_date != normalised_due_date:
            updates["exp_end_date"] = normalised_due_date

    if not updates:
        return {
            "task": task_read_guard._task_to_payload(task, request_link),
            "updated": False,
        }

    for fieldname, value in updates.items():
        setattr(task, fieldname, value)

    task.save(ignore_permissions=True)

    request_name = _text(request_link.get("name"))
    if request_name and frappe.db.exists("OMC Service Request", request_name):
        request_meta = frappe.get_meta("OMC Service Request")
        request_updates = {}

        if "priority" in updates and request_meta.has_field("priority"):
            request_updates["priority"] = updates["priority"]

        if (
            "exp_end_date" in updates
            and request_meta.has_field("expected_completion_date")
        ):
            request_updates["expected_completion_date"] = updates[
                "exp_end_date"
            ]

        if request_updates:
            frappe.db.set_value(
                "OMC Service Request",
                request_name,
                request_updates,
                update_modified=False,
            )

    return {
        "task": task_read_guard._task_to_payload(task, request_link),
        "updated": True,
    }
