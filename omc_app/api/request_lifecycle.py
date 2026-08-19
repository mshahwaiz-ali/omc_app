from __future__ import annotations

from dataclasses import dataclass

import frappe
from frappe.utils import now_datetime

from omc_app.api import security

REQUEST_STATE_TRANSITIONS = {
    "Draft": {"Pending Payment", "Payment Not Required", "Cancelled"},
    "Pending Payment": {"Ready for Activation", "Financial Hold", "Expired", "Cancelled"},
    "Payment Not Required": {"Ready for Activation", "Financial Hold", "Expired", "Cancelled"},
    "Ready for Activation": {"Activating", "Financial Hold", "Cancelled"},
    "Activating": {"Activated", "Activation Failed", "Financial Hold", "Cancelled"},
    "Activated": {"Financial Hold", "Cancelled"},
    "Activation Failed": {"Ready for Activation", "Activating", "Financial Hold", "Cancelled"},
    "Financial Hold": {"Ready for Activation", "Activated", "Cancelled"},
    "Expired": set(),
    "Cancelled": set(),
}

OPERATIONAL_STATUSES = {
    "Open",
    "Waiting for Payment",
    "In Progress",
    "Waiting for Customer",
    "Completed",
    "Cancelled",
}
ACTIVATED_OPERATIONAL_STATUSES = {"In Progress", "Waiting for Customer", "Completed"}


@dataclass(frozen=True)
class TransitionResult:
    request: object
    old_state: str
    new_state: str
    old_status: str
    new_status: str
    changed: bool


def _text(value) -> str:
    return str(value or "").strip()


def compatibility_status(request_state: str, current_status: str = "", *, activated_at=None) -> str:
    state = _text(request_state) or "Draft"
    current = _text(current_status)
    if state == "Pending Payment":
        return "Waiting for Payment"
    if state in {"Draft", "Payment Not Required", "Ready for Activation", "Activating", "Activation Failed"}:
        return "Open"
    if state in {"Expired", "Cancelled"}:
        return "Cancelled"
    if state == "Activated":
        return current if current in ACTIVATED_OPERATIONAL_STATUSES else "In Progress"
    if state == "Financial Hold":
        if activated_at:
            return current if current in {"In Progress", "Waiting for Customer"} else "In Progress"
        return "Waiting for Payment"
    return current or "Open"


def _lock_request(request_name: str):
    name = frappe.db.get_value("OMC Service Request", request_name, "name", for_update=True)
    if not name:
        frappe.throw("Service request is not available.", frappe.DoesNotExistError)
    return frappe.get_doc("OMC Service Request", name)


def _close_todos(reference_type: str, reference_names, status: str) -> None:
    names = [name for name in (reference_names or []) if name]
    if not names:
        return
    todo_names = frappe.get_all(
        "ToDo",
        filters={
            "reference_type": reference_type,
            "reference_name": ["in", names],
            "status": ["not in", ["Closed", "Cancelled"]],
        },
        pluck="name",
        limit_page_length=1000,
    )
    for todo_name in todo_names:
        frappe.db.set_value("ToDo", todo_name, "status", status, update_modified=False)


def _cancel_open_payments(request_name: str) -> None:
    rows = frappe.get_all(
        "OMC Service Payment",
        filters={"service_request": request_name, "status": ["not in", ["Paid", "Cancelled"]]},
        fields=["name", "linked_payment_entry", "accounting_status"],
        limit_page_length=100,
    )
    for row in rows:
        if _text(row.linked_payment_entry) or _text(row.accounting_status) == "Settled":
            continue
        frappe.db.set_value(
            "OMC Service Payment",
            row.name,
            {"status": "Cancelled", "visible_to_customer": 0},
            update_modified=False,
        )


def _cancel_bridge_operations(request_name: str) -> None:
    names = frappe.get_all(
        "OMC Bridge Operation",
        filters={
            "service_request": request_name,
            "state": ["in", ["Pending", "Retry", "Processing"]],
        },
        pluck="name",
        limit_page_length=100,
    )
    for name in names:
        frappe.db.set_value(
            "OMC Bridge Operation",
            name,
            {
                "state": "Cancelled",
                "last_safe_error": "Service request is no longer activation-eligible.",
            },
            update_modified=False,
        )


def _archive_documents(request_name: str, terminal_status: str) -> None:
    try:
        from omc_app.api.customer_documents import archive_service_documents_for_status

        archive_service_documents_for_status(request_name, terminal_status)
    except Exception:
        frappe.log_error(frappe.get_traceback(), "OMC lifecycle document archival failed")


def _terminal_cleanup(request, *, target_state: str, reason: str, customer_cancelled: bool) -> None:
    document_names = frappe.get_all(
        "OMC Service Document",
        filters={"service_request": request.name},
        pluck="name",
        limit_page_length=1000,
    )
    payment_names = frappe.get_all(
        "OMC Service Payment",
        filters={"service_request": request.name},
        pluck="name",
        limit_page_length=1000,
    )
    _close_todos("OMC Service Request", [request.name], "Cancelled")
    _close_todos("OMC Service Document", document_names, "Cancelled")
    _close_todos("OMC Service Payment", payment_names, "Cancelled")

    try:
        from omc_app.api import review_routing

        review_routing.close_parent_review_todos(request.name, cancelled=True)
    except Exception:
        frappe.log_error(frappe.get_traceback(), "OMC lifecycle review ToDo cleanup failed")

    _cancel_open_payments(request.name)
    _cancel_bridge_operations(request.name)
    _archive_documents(request.name, "Cancelled" if target_state == "Cancelled" else "Expired")

    if target_state == "Cancelled":
        from omc_app.api import workflow_automation

        workflow_automation.finalize_cancelled_case(
            request,
            reason=reason,
            cancelled_by_customer=customer_cancelled,
            sync_erp=True,
        )
    else:
        from omc_app.api import mobile, workflow_automation

        message = f"{request.title or request.name} expired before payment was completed."
        mobile._create_service_timeline_entry(
            service_request=request.name,
            event_type="Expired",
            title="Service Request Expired",
            description=message,
            visible_to_customer=1,
        )
        if request.customer_profile:
            workflow_automation._notify_once(
                title="Service request expired",
                message=message,
                notification_type="Service",
                reference_doctype="OMC Service Request",
                reference_name=request.name,
                customer_profile=request.customer_profile,
                dedupe_hours=24 * 365,
            )


def transition_request_state(
    request_name: str,
    target_state: str,
    *,
    reason: str = "",
    actor: str | None = None,
    capability: str = "",
    operational_status: str | None = None,
    customer_cancelled: bool = False,
    idempotency_key: str = "",
) -> TransitionResult:
    request = _lock_request(_text(request_name))
    actor = _text(actor) or frappe.session.user
    target = _text(target_state)
    current = _text(request.request_state) or "Draft"
    old_status = _text(request.status)

    if target not in REQUEST_STATE_TRANSITIONS:
        frappe.throw("Unsupported service request state.", frappe.ValidationError)

    if current == target:
        projected = compatibility_status(current, old_status, activated_at=request.get("activated_at"))
        return TransitionResult(request, current, target, old_status, projected, False)

    if target not in REQUEST_STATE_TRANSITIONS.get(current, set()):
        frappe.throw(
            f"Request state cannot change from {current} to {target}.",
            frappe.ValidationError,
        )

    if target in {"Pending Payment", "Payment Not Required"} and not request.final_confirmation:
        frappe.throw("Final confirmation is required before submitting a request.", frappe.ValidationError)
    if target == "Activated" and not request.erp_task:
        frappe.throw("An ERP Task is required before activation can complete.", frappe.ValidationError)

    values = {"request_state": target}
    if target == "Ready for Activation" and not request.ready_for_activation_at:
        values["ready_for_activation_at"] = now_datetime()
    if target == "Activated" and not request.activated_at:
        values["activated_at"] = now_datetime()
    if target in {"Cancelled", "Expired"}:
        values["closed_on"] = request.closed_on or now_datetime()
    else:
        values["closed_on"] = None

    projected = _text(operational_status) or compatibility_status(
        target,
        old_status,
        activated_at=(values.get("activated_at") or request.get("activated_at")),
    )
    if projected not in OPERATIONAL_STATUSES:
        frappe.throw("Unsupported operational service status.", frappe.ValidationError)
    values["status"] = projected

    frappe.db.set_value(request.doctype, request.name, values, update_modified=False)
    request.update(values)

    if target in {"Cancelled", "Expired"}:
        _terminal_cleanup(
            request,
            target_state=target,
            reason=_text(reason),
            customer_cancelled=customer_cancelled,
        )

    security.audit_event(
        event_type=f"service_request.state.{target.lower().replace(' ', '_')}",
        capability=_text(capability),
        target_doctype=request.doctype,
        target_name=request.name,
        old_state=current,
        new_state=target,
        idempotency_key=_text(idempotency_key),
        safe_reason="workflow_transition",
        actor=actor,
    )
    return TransitionResult(request, current, target, old_status, projected, True)


def update_operational_status(
    request_name: str,
    target_status: str,
    *,
    reason: str = "",
    actor: str | None = None,
    capability: str = "can_update_service_status",
) -> TransitionResult:
    request = _lock_request(_text(request_name))
    target = _text(target_status)
    current_state = _text(request.request_state) or "Draft"
    old_status = _text(request.status)

    if target == "Cancelled":
        return transition_request_state(
            request.name,
            "Cancelled",
            reason=reason,
            actor=actor,
            capability=capability,
        )
    if target not in OPERATIONAL_STATUSES - {"Cancelled"}:
        frappe.throw("Invalid operational status.", frappe.ValidationError)
    if target == "Waiting for Payment":
        if current_state != "Financial Hold":
            frappe.throw(
                "Waiting for Payment is controlled by accounting reconciliation.",
                frappe.ValidationError,
            )
    elif current_state != "Activated":
        frappe.throw(
            "Operational status can only change after activation.",
            frappe.ValidationError,
        )
    elif target not in ACTIVATED_OPERATIONAL_STATUSES:
        frappe.throw("Invalid status for an activated request.", frappe.ValidationError)

    if target == "Completed":
        from omc_app.api import workflow_automation

        blockers = workflow_automation.completion_blockers(request)
        if blockers:
            frappe.throw(
                "Cannot complete this service request: " + " ".join(blockers),
                frappe.ValidationError,
            )

    if old_status == target:
        return TransitionResult(request, current_state, current_state, old_status, target, False)

    values = {"status": target}
    if target == "Completed":
        values["closed_on"] = request.closed_on or now_datetime()
    else:
        values["closed_on"] = None

    from omc_app.api import mobile, workflow_automation

    if target == "Completed":
        attribution = workflow_automation.record_completion_attribution(
            request,
            source="Canonical Lifecycle",
            actor=actor or frappe.session.user,
        )
        if attribution.get("completed_by"):
            values["completed_by"] = attribution["completed_by"]
        if attribution.get("completion_source"):
            values["completion_source"] = attribution["completion_source"]

    frappe.db.set_value(request.doctype, request.name, values, update_modified=False)
    request.update(values)

    if target == "Completed":
        workflow_automation.finalize_completed_case(request)
    mobile._create_service_timeline_entry(
        service_request=request.name,
        event_type="Status Updated",
        title=f"Status Updated: {target}",
        description=_text(reason) or f"Status changed from {old_status or 'Unknown'} to {target}.",
        visible_to_customer=1,
    )
    security.audit_event(
        event_type="service_request.operational_status_changed",
        capability=capability,
        target_doctype=request.doctype,
        target_name=request.name,
        old_state=old_status,
        new_state=target,
        safe_reason="workflow_transition",
        actor=actor or frappe.session.user,
    )
    return TransitionResult(request, current_state, current_state, old_status, target, True)


def expire_request(request_name: str) -> bool:
    request = _lock_request(_text(request_name))
    if _text(request.request_state) not in {"Pending Payment", "Payment Not Required"}:
        return False
    if not request.expires_at or request.expires_at >= now_datetime():
        return False
    transition_request_state(
        request.name,
        "Expired",
        reason="Pending request expired before payment/activation eligibility.",
        actor="scheduler",
        idempotency_key=f"expiry:{request.name}",
    )
    return True
