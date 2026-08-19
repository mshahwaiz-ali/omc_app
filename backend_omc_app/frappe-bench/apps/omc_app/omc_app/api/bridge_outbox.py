from __future__ import annotations

import hashlib

import frappe
from frappe.utils import add_to_date, cint, now_datetime

from omc_app.api import (
    capabilities,
    erp_service_task_adapter,
    request_lifecycle,
    security,
    service_assignment,
)

PROCESSING_LEASE_MINUTES = 15
MAX_ATTEMPTS = 5


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
    if state == "Activated":
        return {"eligible": False, "reason": "request is already activated"}
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
        eligible = bool(request.post_paid_approved_by and request.post_paid_approved_at) and state in {
            "Pending Payment", "Ready for Activation", "Activation Failed"
        }
        return {
            "eligible": eligible,
            "reason": "Finance approval is required." if not eligible else "",
        }
    settled = bool(
        frappe.db.exists(
            "OMC Accounting Link",
            {"service_request": request.name, "accounting_status": "Settled"},
        )
    )
    return {
        "eligible": settled and state in {"Pending Payment", "Ready for Activation", "Activation Failed"},
        "reason": "Full ERP settlement is required." if not settled else "Request is not activation-eligible.",
    }


def _enqueue_operation(operation_name: str) -> None:
    frappe.enqueue(
        "omc_app.api.bridge_outbox.process_operation",
        queue="short",
        enqueue_after_commit=True,
        job_name=f"omc-bridge-{operation_name}",
        operation_name=operation_name,
    )


def enqueue_if_eligible(request_name: str):
    locked = frappe.db.get_value("OMC Service Request", request_name, "name", for_update=True)
    if not locked:
        return None
    request = frappe.get_doc("OMC Service Request", locked)
    status = eligibility(request)
    if not status["eligible"]:
        return None

    if request.request_state in {"Pending Payment", "Payment Not Required", "Activation Failed"}:
        result = request_lifecycle.transition_request_state(
            request.name,
            "Ready for Activation",
            reason="Activation eligibility confirmed.",
            actor=frappe.session.user,
            idempotency_key=f"ready:{request.name}:{cint(request.activation_version or 1)}",
        )
        request = result.request

    key = _operation_key(request)
    name = frappe.db.get_value("OMC Bridge Operation", {"operation_key": key}, "name")
    if name:
        state = _text(frappe.db.get_value("OMC Bridge Operation", name, "state"))
        if state in {"Pending", "Retry"}:
            _enqueue_operation(name)
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
        name = doc.name
    except frappe.DuplicateEntryError:
        name = frappe.db.get_value("OMC Bridge Operation", {"operation_key": key}, "name")
    if name:
        _enqueue_operation(name)
    return name


def _profile_for_request(request):
    if request.customer_profile and frappe.db.exists("OMC Customer Profile", request.customer_profile):
        return frappe.get_doc("OMC Customer Profile", request.customer_profile)
    return None


def _mark_operation_retry(operation_name: str, attempts: int) -> str:
    next_state = "Failed" if attempts >= MAX_ATTEMPTS else "Retry"
    values = {
        "state": next_state,
        "attempt_count": attempts,
        "next_attempt_at": (
            None
            if next_state == "Failed"
            else add_to_date(now_datetime(), minutes=min(2 ** attempts, 60))
        ),
        "last_error_category": "bridge_failure",
        "last_safe_error": "ERP activation could not be completed.",
    }
    frappe.db.set_value("OMC Bridge Operation", operation_name, values, update_modified=False)
    return next_state


def process_operation(operation_name: str) -> dict:
    locked = frappe.db.get_value("OMC Bridge Operation", operation_name, "name", for_update=True)
    if not locked:
        return {"status": "missing"}
    operation = frappe.get_doc("OMC Bridge Operation", locked)
    if operation.state == "Completed":
        return {"status": "completed", "erp_service": operation.erp_service, "erp_task": operation.erp_task}
    if operation.state in {"Failed", "Cancelled"}:
        return {"status": operation.state.lower(), "reason": operation.last_safe_error or ""}

    recovered_stale_lease = False
    if operation.state == "Processing":
        lease_cutoff = add_to_date(now_datetime(), minutes=-PROCESSING_LEASE_MINUTES)
        if operation.last_attempt_at and operation.last_attempt_at > lease_cutoff:
            return {"status": "processing"}
        frappe.db.set_value(
            operation.doctype,
            operation.name,
            {
                "state": "Retry",
                "next_attempt_at": now_datetime(),
                "last_safe_error": "A stale processing lease was recovered.",
            },
            update_modified=False,
        )
        operation.state = "Retry"
        recovered_stale_lease = True

    request_name = frappe.db.get_value(
        "OMC Service Request", operation.service_request, "name", for_update=True
    )
    if not request_name:
        frappe.db.set_value(
            operation.doctype,
            operation.name,
            {"state": "Failed", "next_attempt_at": None, "last_safe_error": "Service request is missing."},
            update_modified=False,
        )
        return {"status": "failed"}

    request = frappe.get_doc("OMC Service Request", request_name)
    if recovered_stale_lease and request.request_state == "Activating":
        recovered = request_lifecycle.transition_request_state(
            request.name,
            "Activation Failed",
            reason="A stale bridge processing lease was recovered for a safe retry.",
            actor="bridge",
            idempotency_key=f"stale-lease-recovered:{operation.operation_key}",
        )
        request = recovered.request

    allowed = eligibility(request)
    if not allowed["eligible"] and request.request_state != "Ready for Activation":
        frappe.db.set_value(
            operation.doctype,
            operation.name,
            {"state": "Cancelled", "next_attempt_at": None, "last_safe_error": allowed["reason"]},
            update_modified=False,
        )
        return {"status": "ineligible", "reason": allowed["reason"]}

    # Re-check settlement under the request row lock immediately before any ERP write.
    if request.payment_policy_snapshot == "Full Settlement" and not frappe.db.exists(
        "OMC Accounting Link",
        {"service_request": request.name, "accounting_status": "Settled"},
    ):
        request_lifecycle.transition_request_state(
            request.name,
            "Financial Hold",
            reason="Settlement was reversed before activation.",
            actor="bridge",
            idempotency_key=f"hold:{operation.operation_key}",
        )
        frappe.db.set_value(
            operation.doctype,
            operation.name,
            {"state": "Cancelled", "next_attempt_at": None, "last_safe_error": "Settlement is no longer complete."},
            update_modified=False,
        )
        return {"status": "ineligible", "reason": "Settlement is no longer complete."}

    attempts = cint(operation.attempt_count or 0) + 1
    frappe.db.set_value(
        operation.doctype,
        operation.name,
        {"state": "Processing", "attempt_count": attempts, "last_attempt_at": now_datetime()},
        update_modified=False,
    )
    request_lifecycle.transition_request_state(
        request.name,
        "Activating",
        reason="Durable ERP activation started.",
        actor="bridge",
        idempotency_key=f"activating:{operation.operation_key}:{attempts}",
    )

    bridge_savepoint = "omc_bridge_operational_write"
    frappe.db.savepoint(bridge_savepoint)
    try:
        request.reload()
        # Final eligibility check while the request lock is still held.
        if request.payment_policy_snapshot == "Full Settlement" and not frappe.db.exists(
            "OMC Accounting Link",
            {"service_request": request.name, "accounting_status": "Settled"},
        ):
            raise frappe.ValidationError("Settlement changed before ERP activation.")

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
        if not frappe.db.exists("Service", request.erp_service) or not frappe.db.exists("Task", request.erp_task):
            raise frappe.ValidationError("ERP activation links were not committed.")

        decision = service_assignment.resolve_assignee(
            service, referral_owner=request.referral_owner
        )
        assignment = service_assignment.apply_assignment(request, decision)
        activated = request_lifecycle.transition_request_state(
            request.name,
            "Activated",
            reason="ERP Service and Task activation completed.",
            actor="bridge",
            operational_status="In Progress",
            idempotency_key=f"activated:{operation.operation_key}",
        )
        request = activated.request
        frappe.db.set_value(
            operation.doctype,
            operation.name,
            {
                "state": "Completed",
                "erp_service": request.erp_service,
                "erp_task": request.erp_task,
                "completed_at": now_datetime(),
                "next_attempt_at": None,
                "last_safe_error": None,
                "last_error_category": None,
            },
            update_modified=False,
        )
        security.audit_event(
            event_type="bridge.request_activated",
            target_doctype=request.doctype,
            target_name=request.name,
            old_state="activating",
            new_state="activated",
            idempotency_key=operation.operation_key,
            safe_reason="bridge_completed",
            actor="bridge",
        )
        return {
            "status": "completed",
            "erp_service": request.erp_service,
            "erp_task": request.erp_task,
            "assignment": assignment,
        }
    except Exception:
        frappe.db.rollback(save_point=bridge_savepoint)
        next_state = _mark_operation_retry(operation.name, attempts)
        current_state = _text(frappe.db.get_value("OMC Service Request", request.name, "request_state"))
        if current_state == "Activating":
            request_lifecycle.transition_request_state(
                request.name,
                "Activation Failed",
                reason="ERP activation could not be completed.",
                actor="bridge",
                idempotency_key=f"activation-failed:{operation.operation_key}:{attempts}",
            )
        frappe.log_error(frappe.get_traceback(), f"OMC Bridge Activation Failed: {request.name}")
        return {"status": next_state.lower(), "reason": "ERP activation could not be completed."}


def _recover_failed_operation(operation_name: str, *, actor: str, reason: str = "") -> dict:
    locked = frappe.db.get_value("OMC Bridge Operation", operation_name, "name", for_update=True)
    if not locked:
        frappe.throw("Bridge operation was not found.", frappe.DoesNotExistError)
    operation = frappe.get_doc("OMC Bridge Operation", locked)
    if operation.state == "Completed":
        return {"operation": operation.name, "state": "Completed", "recovered": False}
    if operation.state != "Failed":
        frappe.throw("Only a terminal failed bridge operation requires manual recovery.", frappe.ValidationError)

    request = request_lifecycle._lock_request(operation.service_request)
    if request.request_state == "Activation Failed":
        recovered = request_lifecycle.transition_request_state(
            request.name,
            "Ready for Activation",
            reason=reason or "Authorized bridge recovery requested.",
            actor=actor,
            capability="can_retry_sync",
            idempotency_key=f"bridge-recovery-ready:{operation.operation_key}",
        )
        request = recovered.request
    elif request.request_state != "Ready for Activation":
        frappe.throw("Service request is not ready for bridge recovery.", frappe.ValidationError)

    allowed = eligibility(request_lifecycle._lock_request(request.name))
    if not allowed["eligible"]:
        frappe.throw(allowed["reason"] or "Service request is not activation-eligible.", frappe.ValidationError)

    frappe.db.set_value(
        operation.doctype,
        operation.name,
        {
            "state": "Retry",
            "attempt_count": 0,
            "next_attempt_at": now_datetime(),
            "last_safe_error": None,
            "last_error_category": None,
        },
        update_modified=False,
    )
    security.audit_event(
        event_type="bridge.recovery_requested",
        capability="can_retry_sync",
        target_doctype="OMC Bridge Operation",
        target_name=operation.name,
        old_state="Failed",
        new_state="Retry",
        safe_reason="authorized_recovery",
        actor=actor,
    )
    _enqueue_operation(operation.name)
    return {"operation": operation.name, "state": "Retry", "recovered": True}


@frappe.whitelist(methods=["POST"])
def recover_failed_operation(operation_name=None, reason=None) -> dict:
    actor = _text(getattr(getattr(frappe, "session", None), "user", None))
    if not actor or actor == "Guest":
        frappe.throw("Login is required.", frappe.PermissionError)
    capabilities.require("can_retry_sync", user=actor)
    security.enforce_rate_limit("staff_mutation", actor=actor)
    operation_name = _text(operation_name)
    if not operation_name:
        frappe.throw("operation_name is required.", frappe.ValidationError)
    return _recover_failed_operation(
        operation_name,
        actor=actor,
        reason=_text(reason),
    )


def process_pending(limit: int = 25):
    now = now_datetime()
    stale_cutoff = add_to_date(now, minutes=-PROCESSING_LEASE_MINUTES)
    names = frappe.get_all(
        "OMC Bridge Operation",
        filters=[
            ["OMC Bridge Operation", "state", "in", ["Pending", "Retry", "Processing"]],
            ["OMC Bridge Operation", "next_attempt_at", "<=", now],
        ],
        pluck="name",
        order_by="next_attempt_at asc, creation asc",
        limit_page_length=min(max(cint(limit), 1), 100),
    )
    # Some stale Processing rows may not have a useful next_attempt_at from an
    # interrupted worker, so add them explicitly to the recovery sweep.
    stale = frappe.get_all(
        "OMC Bridge Operation",
        filters={"state": "Processing", "last_attempt_at": ["<=", stale_cutoff]},
        pluck="name",
        order_by="last_attempt_at asc, creation asc",
        limit_page_length=min(max(cint(limit), 1), 100),
    )
    ordered = list(dict.fromkeys([*names, *stale]))[: min(max(cint(limit), 1), 100)]
    return [process_operation(name) for name in ordered]


def expire_pending_requests(limit: int = 100):
    names = frappe.get_all(
        "OMC Service Request",
        filters={
            "request_state": ["in", ["Pending Payment", "Payment Not Required"]],
            "expires_at": ["<", now_datetime()],
        },
        pluck="name",
        order_by="expires_at asc",
        limit_page_length=min(max(cint(limit), 1), 500),
    )
    expired = 0
    for name in names:
        expired += int(request_lifecycle.expire_request(name))
    return {"expired": expired}
