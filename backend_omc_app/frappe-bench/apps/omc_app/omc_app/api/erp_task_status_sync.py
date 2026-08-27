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
    "under review": "In Review",
    "pending review": "In Review",
    "overdue": "Overdue",
    "pending at client": "Waiting for Customer",
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


HISTORICAL_TASK_STATUS_MAP = {
    "open": "Open",
    "working": "In Progress",
    "in progress": "In Progress",
    "under review": "In Review",
    "pending review": "In Review",
    "overdue": "Overdue",
    "completed": "Completed",
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


def historical_customer_status(
    task_status: Any,
    operation_status: Any = None,
) -> str:
    """Project historical work from authoritative ERP Task.status only."""

    normalized = _text(task_status).lower()
    return HISTORICAL_TASK_STATUS_MAP.get(normalized, "Historical")


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


def cancel_linked_erp_records(request) -> dict[str, Any]:
    """Cancel the linked ERP work without firing the Task hook recursively."""

    task_name = _text(getattr(request, "erp_task", None))
    service_name = _text(getattr(request, "erp_service", None))
    result = {
        "erp_task": task_name,
        "erp_service": service_name,
        "task_cancelled": False,
        "service_cancelled": False,
    }

    if task_name:
        if not frappe.db.exists("Task", task_name):
            frappe.throw(
                f"Linked ERP Task {task_name} does not exist. Contact OMC support.",
                frappe.ValidationError,
            )
        allowed_task_statuses = _allowed_options("Task", "status")
        if allowed_task_statuses and "Cancelled" not in allowed_task_statuses:
            frappe.throw(
                "Linked ERP Task cannot be moved to Cancelled with the current configuration.",
                frappe.ValidationError,
            )
        values = {"status": "Cancelled"}
        operation_statuses = _allowed_options("Task", "custom_operation_status")
        if "Cancelled" in operation_statuses:
            values["custom_operation_status"] = "Cancelled"
        frappe.db.set_value(
            "Task",
            task_name,
            values,
            update_modified=True,
        )
        result["task_cancelled"] = True

    if service_name:
        if not frappe.db.exists("Service", service_name):
            frappe.throw(
                f"Linked ERP Service {service_name} does not exist. Contact OMC support.",
                frappe.ValidationError,
            )
        service_status = _service_status_value("Cancelled", "Cancelled")
        if service_status:
            frappe.db.set_value(
                "Service",
                service_name,
                "status",
                service_status,
                update_modified=True,
            )
            result["service_cancelled"] = True

    return result


def _task_notification_changed(doc) -> bool:
    getter = getattr(doc, "get_doc_before_save", None)
    if not callable(getter):
        return False

    before = getter()
    if not before:
        return False

    for fieldname in ("status", "custom_operation_status", "workflow_state"):
        if _text(getattr(before, fieldname, None)) != _text(
            getattr(doc, fieldname, None)
        ):
            return True

    return False


def _notify_task_recipients(doc, request) -> int:
    task_name = _text(getattr(doc, "name", None))
    if not task_name:
        return 0

    recipients = set()

    assigned_staff = _text(getattr(request, "assigned_staff", None))
    if assigned_staff:
        recipients.add(assigned_staff)

    rows = frappe.get_all(
        "ToDo",
        filters={
            "reference_type": "Task",
            "reference_name": task_name,
            "status": ["not in", ["Closed", "Cancelled"]],
        },
        pluck="allocated_to",
        limit_page_length=100,
    )
    for user in rows:
        user = _text(user)
        if user:
            recipients.add(user)

    if not recipients:
        return 0

    raw_status = _text(getattr(doc, "status", None))
    operation_status = _text(
        getattr(doc, "custom_operation_status", None)
    )
    workflow_state = _text(getattr(doc, "workflow_state", None))

    details = []
    if raw_status:
        details.append(f"ERP status: {raw_status}")
    if workflow_state:
        details.append(f"Workflow: {workflow_state}")
    if operation_status:
        details.append(f"Operation: {operation_status}")

    message = f"{task_name} was updated."
    if details:
        message = f"{message} {' | '.join(details)}"

    from omc_app.api import mobile

    created = 0
    for recipient in sorted(recipients):
        if not frappe.db.exists(
            "User",
            {"name": recipient, "enabled": 1},
        ):
            continue

        notification = mobile._create_customer_notification(
            recipient_user=recipient,
            title="Task updated",
            message=message,
            notification_type="Task",
            reference_doctype="Task",
            reference_name=task_name,
        )
        created += int(bool(notification))

    return created


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
    request_state = _text(getattr(request, "request_state", None))
    historical_import = (
        request_state == "Historical"
        and _text(getattr(request, "source_channel", None)) == "Imported"
    )

    if request_state == "Financial Hold":
        return {
            "updated": False,
            "reason": "financial hold prevents ERP Task projection",
            "request": request_name,
            "customer_status": current_status,
        }
    # Blank is a supported compatibility projection for pre-redesign records.
    # Only canonical non-activated states block the one-way ERP projection.
    canonical_states = {
        "Draft", "Pending Payment", "Payment Not Required",
        "Ready for Activation", "Activating", "Activated", "Expired",
        "Cancelled", "Activation Failed", "Financial Hold",
    }
    if request_state in canonical_states and request_state != "Activated":
        return {
            "updated": False,
            "reason": "request is not activated",
            "request": request_name,
            "customer_status": current_status,
        }
    raw_status = _text(getattr(doc, "status", None))
    operation_status = _text(getattr(doc, "custom_operation_status", None))
    mapped_status = (
        historical_customer_status(raw_status, operation_status)
        if historical_import
        else customer_status(raw_status, operation_status)
    )

    if historical_import:
        closed_on = None
        if mapped_status in {"Completed", "Cancelled"}:
            closed_on = (
                getattr(doc, "completed_on", None)
                or getattr(doc, "modified", None)
                or frappe.utils.now_datetime()
            )

        frappe.db.set_value(
            "OMC Service Request",
            request_name,
            {
                "status": mapped_status,
                "closed_on": closed_on,
            },
            update_modified=True,
        )

        request.status = mapped_status
        request.closed_on = closed_on

        return {
            "updated": True,
            "historical": True,
            "request": request_name,
            "erp_service": _text(getattr(request, "erp_service", None)),
            "task_status": raw_status,
            "operation_status": operation_status,
            "customer_status": mapped_status,
            "service_status": "",
        }

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
    if mapped_status == "Cancelled":
        request_values["request_state"] = "Cancelled"
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
    elif mapped_status == "Cancelled" and current_status != "Cancelled":
        from omc_app.api import workflow_automation

        workflow_automation.finalize_cancelled_case(
            request,
            reason="The linked ERP Task was cancelled by OMC staff.",
            cancelled_by_customer=False,
            sync_erp=False,
        )

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

    notifications_created = 0
    if _task_notification_changed(doc):
        notifications_created = _notify_task_recipients(doc, request)

    return {
        "updated": True,
        "request": request_name,
        "erp_service": erp_service,
        "task_status": raw_status,
        "operation_status": operation_status,
        "customer_status": mapped_status,
        "service_status": service_status or "",
        "notifications_created": notifications_created,
    }
