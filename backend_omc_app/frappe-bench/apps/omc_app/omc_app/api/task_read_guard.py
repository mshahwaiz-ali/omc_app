from __future__ import annotations

import frappe

from omc_app.api import mobile

REFERENCE_DOCTYPES = {
    "customer_profile": "OMC Customer Profile",
    "service_request": "OMC Service Request",
    "support_ticket": "OMC Support Ticket",
}


def _task_not_found():
    frappe.throw("Task not found", frappe.DoesNotExistError)


def _sanitize_task_payload(payload):
    if not isinstance(payload, dict):
        return payload

    sanitized = dict(payload)
    for fieldname, doctype in REFERENCE_DOCTYPES.items():
        value = (sanitized.get(fieldname) or "").strip()
        if value and not frappe.db.exists(doctype, value):
            sanitized[fieldname] = ""
    return sanitized


def _load_task(task_id):
    if not task_id or not frappe.db.exists("OMC Task", task_id):
        _task_not_found()
    return frappe.get_doc("OMC Task", task_id)


@frappe.whitelist()
def get_tasks():
    user = mobile._assert_internal_workspace_access()
    capabilities = mobile._require_canonical_capability(
        "can_manage_tasks",
        "can_manage_assigned_tasks",
        message="You do not have permission to view tasks.",
    )

    filters = {}
    if not capabilities.get("can_manage_tasks"):
        filters["assigned_to"] = user

    task_names = frappe.get_all(
        "OMC Task",
        filters=filters,
        pluck="name",
        order_by="modified desc",
        limit_page_length=100,
    )

    tasks = []
    for task_name in task_names:
        try:
            task = _load_task(task_name)
        except frappe.DoesNotExistError:
            continue
        tasks.append(_sanitize_task_payload(mobile._task_to_dict(task)))
    return {"tasks": tasks}


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

    task = _load_task(task_id)
    if (
        not capabilities.get("can_manage_tasks")
        and (task.assigned_to or "") != user
    ):
        frappe.throw(
            "You do not have permission to view this task.",
            frappe.PermissionError,
        )

    return {"task": _sanitize_task_payload(mobile._task_to_dict(task))}
