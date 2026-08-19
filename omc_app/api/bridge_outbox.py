from __future__ import annotations

import hashlib

import frappe
from frappe.utils import add_to_date, cint, now_datetime

from omc_app.api import erp_service_task_adapter, security, service_assignment


def _text(value) -> str:
    return str(value or "").strip()


def _operation_key(request) -> str:
    return hashlib.sha256(
        f"activate|{request.name}|{cint(request.activation_version or 1)}".encode()
    ).hexdigest()


def eligibility(request) -> dict:
    state = _text(request.request_state)
    policy = _text(request.payment_policy_snapshot) or "Full Settlement"
    if state in {"Cancelled", "Expired", "Financial Hold"}:
        return {"eligible": False, "reason": f"request is {state}"}
    if policy == "No Charge":
        eligible = not request.payable_amount and state in {
            "Payment Not Required", "Ready for Activation", "Activation Failed"
        }
        return {
            "eligible": eligible,
            "reason": (
                "No Charge policy requires a zero payable amount."
                if request.payable_amount
                else ("No Charge request is not ready for activation." if not eligible else "")
            ),
        }
    if policy == "Post-paid Approval":
        return {
            "eligible": bool(request.post_paid_approved_by and request.post_paid_approved_at),
            "reason": "Finance approval is required.",
        }
    settled = bool(
        frappe.db.exists(
            "OMC Accounting Link",
            {"service_request": request.name, "accounting_status": "Settled"},
        )
    )
    return {"eligible": settled, "reason": "Full ERP settlement is required."}


def enqueue_if_eligible(request_name: str):
    locked = frappe.db.get_value("OMC Service Request", request_name, "name", for_update=True)
    if not locked:
        return None
    request = frappe.get_doc("OMC Service Request", locked)
    status = eligibility(request)
    if not status["eligible"]:
        return None
    if request.request_state in {"Payment Not Required", "Activation Failed"}:
        frappe.db.set_value(
            request.doctype, request.name,
            {"request_state": "Ready for Activation", "ready_for_activation_at": now_datetime(), "status": "Open"},
            update_modified=False,
        )
        request.request_state = "Ready for Activation"
    key = _operation_key(request)
    name = frappe.db.get_value("OMC Bridge Operation", {"operation_key": key}, "name")
    if name:
        return name
    doc = frappe.get_doc({
        "doctype": "OMC Bridge Operation",
        "operation_key": key,
        "operation_type": "Activate Request",
        "service_request": request.name,
        "source_version": hashlib.sha256(
            f"{request.name}|{request.pricing_version_snapshot}|{request.modified}".encode()
        ).hexdigest(),
        "state": "Pending",
        "attempt_count": 0,
        "next_attempt_at": now_datetime(),
    })
    try:
        doc.insert(ignore_permissions=True)
    except frappe.DuplicateEntryError:
        return frappe.db.get_value("OMC Bridge Operation", {"operation_key": key}, "name")
    return doc.name


def _profile_for_request(request):
    if request.customer_profile and frappe.db.exists("OMC Customer Profile", request.customer_profile):
        return frappe.get_doc("OMC Customer Profile", request.customer_profile)
    return None


def process_operation(operation_name: str) -> dict:
    locked = frappe.db.get_value("OMC Bridge Operation", operation_name, "name", for_update=True)
    if not locked:
        return {"status": "missing"}
    operation = frappe.get_doc("OMC Bridge Operation", locked)
    if operation.state == "Completed":
        return {"status": "completed", "erp_service": operation.erp_service, "erp_task": operation.erp_task}
    request_name = frappe.db.get_value(
        "OMC Service Request", operation.service_request, "name", for_update=True
    )
    if not request_name:
        operation.db_set({"state": "Failed", "last_safe_error": "Service request is missing."}, update_modified=False)
        return {"status": "failed"}
    request = frappe.get_doc("OMC Service Request", request_name)
    allowed = eligibility(request)
    if not allowed["eligible"]:
        operation.db_set({"state": "Cancelled", "last_safe_error": allowed["reason"]}, update_modified=False)
        return {"status": "ineligible", "reason": allowed["reason"]}
    operation.db_set(
        {"state": "Processing", "attempt_count": cint(operation.attempt_count or 0) + 1, "last_attempt_at": now_datetime()},
        update_modified=False,
    )
    frappe.db.set_value(
        request.doctype, request.name,
        {"request_state": "Activating", "status": "Open"}, update_modified=False,
    )
    bridge_savepoint = "omc_bridge_operational_write"
    frappe.db.savepoint(bridge_savepoint)
    try:
        service = frappe.get_doc("OMC Service", request.service)
        result = erp_service_task_adapter.sync_request(
            request,
            service=service,
            profile=_profile_for_request(request),
            repair=True,
        )
        request.reload()
        if result.get("status") != "Synced" or not request.erp_service or not request.erp_task:
            raise frappe.ValidationError(result.get("reason") or "ERP bridge did not produce committed links.")
        decision = service_assignment.resolve_assignee(
            service, referral_owner=request.referral_owner
        )
        assignment = service_assignment.apply_assignment(request, decision)
        frappe.db.set_value(
            request.doctype, request.name,
            {"request_state": "Activated", "status": "In Progress", "activated_at": now_datetime()},
            update_modified=False,
        )
        operation.db_set(
            {
                "state": "Completed", "erp_service": request.erp_service,
                "erp_task": request.erp_task, "completed_at": now_datetime(),
                "last_safe_error": None, "last_error_category": None,
            },
            update_modified=False,
        )
        security.audit_event(
            event_type="bridge.request_activated", target_doctype=request.doctype,
            target_name=request.name, old_state="activating", new_state="activated",
            idempotency_key=operation.operation_key,
        )
        return {"status": "completed", "erp_service": request.erp_service, "erp_task": request.erp_task, "assignment": assignment}
    except Exception:
        # Do not preserve a half-created Service/Task/ToDo graph. Retry state is
        # written after the savepoint rollback and can safely reuse prior links.
        frappe.db.rollback(save_point=bridge_savepoint)
        attempts = cint(operation.attempt_count or 0)
        next_state = "Failed" if attempts >= 5 else "Retry"
        operation.db_set(
            {
                "state": next_state, "attempt_count": attempts,
                "next_attempt_at": add_to_date(now_datetime(), minutes=min(2 ** attempts, 60)),
                "last_error_category": "bridge_failure",
                "last_safe_error": "ERP activation could not be completed.",
            },
            update_modified=False,
        )
        frappe.db.set_value(
            request.doctype, request.name,
            {"request_state": "Activation Failed", "status": "Open"}, update_modified=False,
        )
        frappe.log_error(frappe.get_traceback(), f"OMC Bridge Activation Failed: {request.name}")
        return {"status": next_state.lower(), "reason": "ERP activation could not be completed."}


def process_pending(limit: int = 25):
    names = frappe.get_all(
        "OMC Bridge Operation",
        filters={"state": ["in", ["Pending", "Retry"]], "next_attempt_at": ["<=", now_datetime()]},
        pluck="name", order_by="next_attempt_at asc, creation asc", limit_page_length=min(max(cint(limit), 1), 100),
    )
    return [process_operation(name) for name in names]


def expire_pending_requests(limit: int = 100):
    names = frappe.get_all(
        "OMC Service Request",
        filters={"request_state": ["in", ["Pending Payment", "Payment Not Required"]], "expires_at": ["<", now_datetime()]},
        pluck="name", order_by="expires_at asc", limit_page_length=min(max(cint(limit), 1), 500),
    )
    for name in names:
        frappe.db.set_value(
            "OMC Service Request", name,
            {"request_state": "Expired", "status": "Cancelled", "closed_on": now_datetime()},
            update_modified=False,
        )
    return {"expired": len(names)}
