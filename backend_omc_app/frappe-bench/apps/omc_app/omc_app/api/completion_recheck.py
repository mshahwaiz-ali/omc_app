from __future__ import annotations

import frappe

from omc_app.api import erp_task_status_sync


def _text(value) -> str:
    return str(value or "").strip()


def recheck_completed_task(request_name: str) -> dict:
    """Re-run canonical Task completion after a blocker is resolved.

    A Task can legitimately reach Completed while payment or document evidence
    still blocks final OMC completion. When a later dependency clears, no new
    Task on_update event is guaranteed. This helper reads the existing Task and
    delegates back to the normal Task status projection without editing the
    ERP Task itself.
    """

    name = _text(request_name)
    if not name or not frappe.db.exists("OMC Service Request", name):
        return {"updated": False, "reason": "service request is unavailable"}

    request = frappe.get_doc("OMC Service Request", name)
    if _text(getattr(request, "status", None)) in {"Completed", "Cancelled"}:
        return {"updated": False, "reason": "service request is terminal"}
    if _text(getattr(request, "request_state", None)) != "Activated":
        return {"updated": False, "reason": "service request is not activated"}

    task_name = _text(getattr(request, "erp_task", None))
    if not task_name or not frappe.db.exists("Task", task_name):
        return {"updated": False, "reason": "linked ERP Task is unavailable"}

    task = frappe.get_doc("Task", task_name)
    projected = erp_task_status_sync.customer_status(
        getattr(task, "status", None),
        getattr(task, "custom_operation_status", None),
    )
    if projected != "Completed":
        return {"updated": False, "reason": "linked ERP Task is not complete"}

    return erp_task_status_sync.sync_task_status(
        task,
        method="dependency_recheck",
    )
