from __future__ import annotations

import frappe
from frappe.utils import flt, now_datetime

from omc_app.api import (
    access,
    bridge_outbox,
    idempotency,
    mobile,
    payments,
    security,
)


PAYMENT_DOCTYPE = payments.PAYMENT_DOCTYPE
RECEIPT_DOCTYPE = payments.RECEIPT_DOCTYPE
REQUEST_DOCTYPE = "OMC Service Request"
ELIGIBLE_PAYMENT_STATUSES = {"Pending", "Rejected"}
BLOCKING_RECEIPT_STATUSES = {"Submitted", "Verified"}
BLOCKING_ACCOUNTING_STATUSES = {
    "Partially Settled",
    "Settled",
    "Review Required",
    "Quarantined",
    "Reversed",
}


def _text(value) -> str:
    return str(value or "").strip()


def _money(value) -> float:
    return round(flt(value or 0), 6)


def _current_user() -> str:
    return _text(getattr(getattr(frappe, "session", None), "user", None)) or "Guest"


def _approval_capabilities(actor: str) -> dict:
    values = access.get_mobile_capabilities(user=actor)
    if (
        actor == "Guest"
        or not values.get("can_access_internal_workspace")
        or not values.get("can_approve_post_paid")
    ):
        frappe.throw(
            "You do not have permission to approve Pay Later.",
            frappe.PermissionError,
        )
    return values


def _load_payment_request(payment_id: str, *, for_update: bool = False):
    payment_id = _text(payment_id)
    row = frappe.db.get_value(
        PAYMENT_DOCTYPE,
        payment_id,
        ["name", "service_request"],
        as_dict=True,
    )
    if not row or not _text(row.service_request):
        frappe.throw("Payment not found.", frappe.DoesNotExistError)

    request_name = _text(row.service_request)
    if for_update:
        locked_request = frappe.db.get_value(
            REQUEST_DOCTYPE,
            request_name,
            "name",
            for_update=True,
        )
        if not locked_request:
            frappe.throw("Service request was not found.", frappe.DoesNotExistError)

        locked_payment = frappe.db.get_value(
            PAYMENT_DOCTYPE,
            payment_id,
            "name",
            for_update=True,
        )
        if not locked_payment:
            frappe.throw("Payment not found.", frappe.DoesNotExistError)

    payment = frappe.get_doc(PAYMENT_DOCTYPE, payment_id)
    request = frappe.get_doc(REQUEST_DOCTYPE, request_name)
    if _text(payment.service_request) != request.name:
        frappe.throw("Payment does not belong to this service request.", frappe.ValidationError)
    return payment, request


def _is_pay_later_approved(request) -> bool:
    return bool(
        _text(getattr(request, "payment_execution_mode", None)) == "Pay Later"
        and _text(getattr(request, "post_paid_approved_by", None))
        and getattr(request, "post_paid_approved_at", None)
        and _text(getattr(request, "pay_later_reason", None))
    )


def _accounting_activity_exists(request_name: str) -> bool:
    links = frappe.get_all(
        "OMC Accounting Link",
        filters={"service_request": request_name},
        fields=[
            "sales_invoice",
            "payment_entry",
            "allocated_amount",
            "accounting_status",
        ],
        limit_page_length=100,
    )
    for row in links:
        if _text(getattr(row, "sales_invoice", None)):
            return True
        if _text(getattr(row, "payment_entry", None)):
            return True
        if _money(getattr(row, "allocated_amount", 0)) > 0:
            return True
        if _text(getattr(row, "accounting_status", None)) in BLOCKING_ACCOUNTING_STATUSES:
            return True

    payment_rows = frappe.get_all(
        PAYMENT_DOCTYPE,
        filters={
            "service_request": request_name,
            "status": ["!=", "Cancelled"],
        },
        fields=[
            "status",
            "accounted_amount",
            "accounting_status",
            "linked_invoice",
            "linked_payment_entry",
        ],
        limit_page_length=100,
    )
    for row in payment_rows:
        if _text(getattr(row, "linked_invoice", None)):
            return True
        if _text(getattr(row, "linked_payment_entry", None)):
            return True
        if _money(getattr(row, "accounted_amount", 0)) > 0:
            return True
        if _text(getattr(row, "accounting_status", None)) in BLOCKING_ACCOUNTING_STATUSES:
            return True
        if _text(getattr(row, "status", None)) in {"Partially Paid", "Paid"}:
            return True
    return False


def _unresolved_receipt_exists(request_name: str) -> bool:
    rows = frappe.get_all(
        RECEIPT_DOCTYPE,
        filters={"service_request": request_name},
        fields=["review_status", "accounting_state"],
        limit_page_length=100,
    )
    for row in rows:
        review_status = _text(getattr(row, "review_status", None))
        accounting_state = _text(getattr(row, "accounting_state", None))
        if review_status in BLOCKING_RECEIPT_STATUSES:
            return True
        if accounting_state in {"Pending", "Processing", "Retry", "Completed"}:
            return True
    return False


def _approval_block_reason(request, payment) -> str:
    if _text(getattr(request, "status", None)) in {"Completed", "Cancelled"}:
        return "Pay Later cannot be approved for a closed service request."

    state = _text(getattr(request, "request_state", None))
    if state != "Pending Payment":
        return "Pay Later can only be approved while the request is pending payment."

    if _text(getattr(request, "payment_policy_snapshot", None)) == "No Charge":
        return "No Charge requests do not require Pay Later approval."

    if _money(getattr(request, "payable_amount", 0)) <= 0:
        return "Pay Later requires a positive finalized payable amount."

    if _text(getattr(payment, "status", None)) not in ELIGIBLE_PAYMENT_STATUSES:
        return "Resolve the current payment state before approving Pay Later."

    if _text(getattr(payment, "linked_invoice", None)) or _text(
        getattr(payment, "linked_payment_entry", None)
    ):
        return "Existing ERP accounting activity must be resolved before Pay Later can be approved."

    if _money(getattr(payment, "accounted_amount", 0)) > 0:
        return "Existing ERP payment evidence prevents Pay Later approval."

    if _text(getattr(payment, "accounting_status", None)) in BLOCKING_ACCOUNTING_STATUSES:
        return "Existing ERP accounting activity prevents Pay Later approval."

    if _unresolved_receipt_exists(request.name):
        return (
            "Resolve or reject the submitted payment receipt before approving Pay Later."
        )

    if (
        _text(getattr(payment, "receipt_attachment", None))
        and _text(getattr(payment, "status", None)) != "Rejected"
    ):
        return (
            "Resolve or reject the submitted payment receipt before approving Pay Later."
        )

    if _accounting_activity_exists(request.name):
        return (
            "Existing ERP accounting history prevents switching this request to Pay Later."
        )

    mode = _text(getattr(request, "payment_execution_mode", None)) or "Prepaid"
    if mode not in {"Prepaid", "Pay Later"}:
        return "Payment execution mode requires reconciliation before Pay Later approval."

    if mode == "Pay Later" and not _is_pay_later_approved(request):
        return "The existing Pay Later decision is incomplete and requires reconciliation."

    return ""


def _approval_payload(payment, request, *, operation="") -> dict:
    return {
        "payment": payment.name,
        "service_request": request.name,
        "payment_status": _text(payment.status) or "Pending",
        "payment_execution_mode": (
            _text(getattr(request, "payment_execution_mode", None)) or "Prepaid"
        ),
        "approved": _is_pay_later_approved(request),
        "approved_by": _text(getattr(request, "post_paid_approved_by", None)),
        "approved_at": str(getattr(request, "post_paid_approved_at", None) or ""),
        "reason": _text(getattr(request, "pay_later_reason", None)),
        "request_state": _text(getattr(request, "request_state", None)),
        "bridge_operation": _text(operation),
    }


@frappe.whitelist()
def get_approval_context(payment_id=None):
    actor = _current_user()
    capabilities = access.get_mobile_capabilities(user=actor)
    if actor == "Guest" or not capabilities.get("can_access_internal_workspace"):
        frappe.throw("Login is required.", frappe.PermissionError)

    if not capabilities.get("can_approve_post_paid"):
        return {
            "payment": _text(payment_id),
            "can_approve": False,
            "eligible": False,
            "approved": False,
            "block_reason": "",
        }

    payment, request = _load_payment_request(_text(payment_id))
    payments._assert_service_request_payment_access(
        request.name,
        internal_user=actor,
    )
    approved = _is_pay_later_approved(request)
    block_reason = "" if approved else _approval_block_reason(request, payment)
    return {
        **_approval_payload(payment, request),
        "can_approve": True,
        "eligible": bool(not approved and not block_reason),
        "block_reason": block_reason,
    }


@frappe.whitelist(methods=["POST"])
def approve_pay_later(
    payment_id=None,
    reason=None,
    idempotency_key=None,
):
    actor = _current_user()
    _approval_capabilities(actor)
    security.enforce_rate_limit("staff_mutation", actor=actor)

    payment_id = _text(payment_id)
    reason = _text(reason)
    if not payment_id:
        frappe.throw("payment_id is required.", frappe.ValidationError)

    if not idempotency.request_key({"idempotency_key": idempotency_key}):
        frappe.throw("An idempotency key is required.", frappe.ValidationError)

    claim = idempotency.begin(
        operation="payment.pay_later_approve",
        actor=actor,
        payload={
            "idempotency_key": idempotency_key,
            "payment_id": payment_id,
            "reason": reason,
        },
    )
    if claim and claim.replay is not None:
        return claim.replay

    savepoint = "omc_pay_later_approval"
    frappe.db.savepoint(savepoint)
    try:
        payment, request = _load_payment_request(payment_id, for_update=True)
        payments._assert_service_request_payment_access(
            request.name,
            internal_user=actor,
        )

        if _is_pay_later_approved(request):
            if _text(payment.status) in ELIGIBLE_PAYMENT_STATUSES:
                payment.status = "Deferred"
                payment.save(ignore_permissions=True)

            if getattr(request, "expires_at", None):
                frappe.db.set_value(
                    REQUEST_DOCTYPE,
                    request.name,
                    "expires_at",
                    None,
                    update_modified=False,
                )
                request.expires_at = None

            operation = bridge_outbox.enqueue_if_eligible(request.name)
            request_state = _text(
                frappe.db.get_value(REQUEST_DOCTYPE, request.name, "request_state")
            )
            request.request_state = request_state or request.request_state
            response = {
                **_approval_payload(payment, request, operation=operation),
                "updated": False,
                "message": "Pay Later is already approved.",
            }
            return idempotency.complete(
                claim,
                response,
                reference_doctype=REQUEST_DOCTYPE,
                reference_name=request.name,
            )

        if not reason:
            frappe.throw(
                "A reason is required to approve Pay Later.",
                frappe.ValidationError,
            )

        block_reason = _approval_block_reason(request, payment)
        if block_reason:
            frappe.throw(block_reason, frappe.ValidationError)

        approved_at = now_datetime()
        values = {
            "payment_execution_mode": "Pay Later",
            "post_paid_approved_by": actor,
            "post_paid_approved_at": approved_at,
            "pay_later_reason": reason,
            "expires_at": None,
        }
        frappe.db.set_value(
            REQUEST_DOCTYPE,
            request.name,
            values,
            update_modified=False,
        )
        for fieldname, value in values.items():
            setattr(request, fieldname, value)

        payment.status = "Deferred"
        payment.save(ignore_permissions=True)

        request.add_comment(
            "Comment",
            text=(
                f"Pay Later approved by {actor}. Reason: {reason}"
            ),
        )
        message = (
            "Pay Later approved. Service can start before payment. "
            "The invoice will follow the completed service task workflow."
        )
        mobile._create_service_timeline_entry(
            service_request=request.name,
            event_type="Payment Updated",
            title="Pay Later Approved",
            description=message,
            visible_to_customer=1,
        )
        if request.customer_profile:
            mobile._create_customer_notification(
                customer_profile=request.customer_profile,
                title="Pay Later approved",
                message=message,
                notification_type="Payment",
                reference_doctype=PAYMENT_DOCTYPE,
                reference_name=payment.name,
            )

        security.audit_event(
            event_type="payment.pay_later_approved",
            capability="can_approve_post_paid",
            target_doctype=REQUEST_DOCTYPE,
            target_name=request.name,
            old_state="Prepaid",
            new_state="Pay Later",
            actor=actor,
            safe_reason="authorized_deferment",
        )

        operation = bridge_outbox.enqueue_if_eligible(request.name)
        request_state = _text(
            frappe.db.get_value(REQUEST_DOCTYPE, request.name, "request_state")
        )
        request.request_state = request_state or request.request_state

        response = {
            **_approval_payload(payment, request, operation=operation),
            "updated": True,
            "message": "Pay Later approved. ERP activation has been queued.",
        }
        return idempotency.complete(
            claim,
            response,
            reference_doctype=REQUEST_DOCTYPE,
            reference_name=request.name,
        )
    except Exception:
        frappe.db.rollback(save_point=savepoint)
        idempotency.fail(claim)
        raise
