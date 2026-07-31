"""Scoped ERP Task status propagation for OMC service requests."""

from __future__ import annotations

from typing import Any

import frappe


CUSTOMER_STATUS_MAP = {
    "open": "Open",
    "pending": "Open",
    "not started": "Open",
    "working": "In Progress",
    "in progress": "In Progress",
    "started": "In Progress",
    "under review": "In Progress",
    "waiting for customer": "Waiting for Customer",
    "customer action required": "Waiting for Customer",
    "awaiting customer": "Waiting for Customer",
    "payment pending": "Waiting for Payment",
    "waiting for payment": "Waiting for Payment",
    "awaiting payment": "Waiting for Payment",
    "completed": "Completed",
    "complete": "Completed",
    "closed": "Completed",
    "cancelled": "Cancelled",
    "canceled": "Cancelled",
}


def _text(value: Any) -> str:
    return str(value or "").strip()


def customer_status(task_status: Any, operation_status: Any = None) -> str:
    for value in (operation_status, task_status):
        normalized = _text(value).lower()
        if normalized in CUSTOMER_STATUS_MAP:
            return CUSTOMER_STATUS_MAP[normalized]
    return "In Progress"


def _allowed_options(doctype: str, fieldname: str) -> set[str]:
    field = frappe.get_meta(doctype).get_field(fieldname)
    if not field or not getattr(field, "options", None):
        return set()
    return {
        option.strip()
        for option in str(field.options).splitlines()
        if option.strip()
    }


def _service_status_value(mapped_status: str, raw_status: str) -> str | None:
    allowed = _allowed_options("Service", "status")
    if not allowed:
        return None
    if mapped_status in allowed:
        return mapped_status
    if raw_status in allowed:
        return raw_status
    return None


def sync_task_status(doc, method=None) -> dict[str, Any]:
    task_name = _text(getattr(doc, "name", None))
    if not task_name:
        return {"updated": False, "reason": "missing task name"}

    request_name = frappe.db.get_value(
        "OMC Service Request",
        {"erp_task": task_name},
        "name",
    )
    if not request_name:
        return {
            "updated": False,
            "reason": "task is not linked to an OMC request",
        }

    request = frappe.get_doc("OMC Service Request", request_name)
    current_status = _text(getattr(request, "status", None))
    raw_status = _text(getattr(doc, "status", None))
    operation_status = _text(getattr(doc, "custom_operation_status", None))
    mapped_status = customer_status(raw_status, operation_status)

    if current_status in {"Completed", "Cancelled"} and mapped_status != current_status:
        return {
            "updated": False,
            "reason": (
                "terminal OMC service request cannot be reopened "
                "by ERP Task status sync"
            ),
            "request": request_name,
            "customer_status": current_status,
        }

    if mapped_status == "Completed":
        from omc_app.api import workflow_automation

        blockers = workflow_automation.completion_blockers(request)
        if blockers:
            return {
                "updated": False,
                "reason": " ".join(blockers),
                "request": request_name,
                "customer_status": current_status,
                "requested_status": mapped_status,
            }

    request_values = {"status": mapped_status}
    if mapped_status == "Completed" and current_status != "Completed":
        from omc_app.api import workflow_automation

        workflow_automation.record_completion_attribution(
            request,
            source="ERP Task",
            actor=getattr(request, "assigned_staff", None),
        )
        if getattr(request, "completed_by", None):
            request_values["completed_by"] = request.completed_by
        if getattr(request, "completion_source", None):
            request_values["completion_source"] = request.completion_source

    if mapped_status in {"Completed", "Cancelled"}:
        request_values["closed_on"] = frappe.utils.now_datetime()
    else:
        request_values["closed_on"] = None

    frappe.db.set_value(
        "OMC Service Request",
        request_name,
        request_values,
        update_modified=True,
    )

    request.status = mapped_status
    request.closed_on = request_values["closed_on"]

    if mapped_status == "Completed" and current_status != "Completed":
        from omc_app.api import workflow_automation

        workflow_automation.finalize_completed_case(request)

    erp_service = _text(getattr(request, "erp_service", None))
    service_status = _service_status_value(mapped_status, raw_status)
    if erp_service and service_status and frappe.db.exists("Service", erp_service):
        frappe.db.set_value(
            "Service",
            erp_service,
            "status",
            service_status,
            update_modified=True,
        )

    return {
        "updated": True,
        "request": request_name,
        "erp_service": erp_service,
        "task_status": raw_status,
        "operation_status": operation_status,
        "customer_status": mapped_status,
        "service_status": service_status or "",
    }
