from __future__ import annotations

import frappe
from frappe.utils import flt

from omc_app.api import mobile, security

PAYMENT_DOCTYPE = "OMC Service Payment"
FINANCIAL_PAYMENT_STATUSES = {"Receipt Submitted", "Under Review", "Paid"}


def _text(value) -> str:
    return str(value or "").strip()


def _required_documents_uploaded(request) -> bool:
    templates = mobile._service_required_documents(request.service)
    documents = frappe.get_all(
        "OMC Service Document",
        filters={"service_request": request.name, "visible_to_customer": 1},
        fields=["document_title", "document_type", "status", "attachment"],
        limit_page_length=1000,
    )
    payload = [
        {
            "document_title": row.document_title or "",
            "document_type": row.document_type or "",
            "status": row.status or "",
            "attachment": row.attachment or "",
        }
        for row in documents
    ]
    return mobile._required_documents_uploaded(templates, payload)


def _financial_processing_started(request_name: str) -> bool:
    if frappe.db.exists("OMC Accounting Link", {"service_request": request_name}):
        return True
    rows = frappe.get_all(
        PAYMENT_DOCTYPE,
        filters={"service_request": request_name, "status": ["!=", "Cancelled"]},
        fields=["status", "receipt_attachment", "linked_payment_entry", "accounting_status"],
        limit_page_length=100,
    )
    return any(
        _text(row.status) in FINANCIAL_PAYMENT_STATUSES
        or bool(_text(row.receipt_attachment))
        or bool(_text(row.linked_payment_entry))
        or _text(row.accounting_status) in {"Settled", "Partially Settled", "Review Required", "Reversed"}
        for row in rows
    )


def financial_processing_started(request_name: str) -> bool:
    return _financial_processing_started(_text(request_name))


def _notify_payment_opened(request, payment) -> None:
    message = (
        f"Payment of {payment.currency} {flt(payment.amount, 6):g} is now available "
        f"for {request.title or request.name}."
    )
    mobile._create_service_timeline_entry(
        service_request=request.name,
        event_type="Payment Updated",
        title="Payment Opened",
        description=message,
        visible_to_customer=1,
    )
    if request.customer_profile:
        mobile._create_customer_notification(
            customer_profile=request.customer_profile,
            title="Payment is ready",
            message=message,
            notification_type="Payment",
            reference_doctype=PAYMENT_DOCTYPE,
            reference_name=payment.name,
        )


def ensure_service_payment(request_name: str):
    """Create or align the single visible unpaid payment for a finalized request.

    This service is intentionally idempotent. It never rewrites a receipt,
    accounting-linked payment, or any settled amount.
    """
    request_name = _text(request_name)
    locked = frappe.db.get_value("OMC Service Request", request_name, "name", for_update=True)
    if not locked:
        frappe.throw("Service request is not available.", frappe.DoesNotExistError)
    request = frappe.get_doc("OMC Service Request", locked)

    if _text(request.request_state) in {"Cancelled", "Expired"}:
        return None
    if _text(request.discount_status) == "Pending Approval":
        return None
    if not _required_documents_uploaded(request):
        return None

    policy = _text(request.payment_policy_snapshot) or "Full Settlement"
    amount = flt(request.payable_amount or 0, 6)
    if policy == "No Charge":
        if amount != 0:
            frappe.throw("No Charge requests must have an exact zero payable amount.", frappe.ValidationError)
        if request.request_state == "Payment Not Required":
            from omc_app.api.bridge_outbox import enqueue_if_eligible

            enqueue_if_eligible(request.name)
        return None
    if amount <= 0:
        frappe.throw("A paid service request must have a positive finalized payable amount.", frappe.ValidationError)

    rows = frappe.get_all(
        PAYMENT_DOCTYPE,
        filters={
            "service_request": request.name,
            "visible_to_customer": 1,
            "status": ["!=", "Cancelled"],
        },
        fields=[
            "name", "amount", "currency", "status", "receipt_attachment",
            "linked_payment_entry", "accounting_status",
        ],
        order_by="creation asc, name asc",
        limit_page_length=10,
    )
    if len(rows) > 1:
        frappe.throw(
            "Multiple active service payments require reconciliation before continuing.",
            frappe.ValidationError,
        )
    if rows:
        row = rows[0]
        existing_amount = flt(row.amount or 0, 6)
        currency = _text(request.pricing_currency) or "PKR"
        if abs(existing_amount - amount) <= 0.000001 and _text(row.currency) == currency:
            return row.name
        if (
            _text(row.status) in FINANCIAL_PAYMENT_STATUSES
            or _text(row.receipt_attachment)
            or _text(row.linked_payment_entry)
            or _text(row.accounting_status) in {"Settled", "Partially Settled", "Review Required", "Reversed"}
        ):
            frappe.throw(
                "Payment amount cannot change after receipt or accounting activity has started.",
                frappe.ValidationError,
            )
        frappe.db.set_value(
            PAYMENT_DOCTYPE,
            row.name,
            {"amount": amount, "currency": currency},
            update_modified=False,
        )
        security.audit_event(
            event_type="payment.open_amount_aligned",
            target_doctype=PAYMENT_DOCTYPE,
            target_name=row.name,
            source_version=_text(request.pricing_version_snapshot),
            safe_reason="pricing_finalized",
        )
        return row.name

    payment = frappe.new_doc(PAYMENT_DOCTYPE)
    payment.service_request = request.name
    payment.payment_title = f"{request.service_title or request.title or 'Service'} Payment"
    payment.amount = amount
    payment.currency = _text(request.pricing_currency) or "PKR"
    payment.status = "Pending"
    payment.visible_to_customer = 1
    payment.remarks = "Payment opened from the finalized server-side pricing snapshot."
    try:
        payment.insert(ignore_permissions=True)
    except frappe.DuplicateEntryError:
        existing = frappe.db.get_value(
            PAYMENT_DOCTYPE,
            {
                "service_request": request.name,
                "visible_to_customer": 1,
                "status": ["!=", "Cancelled"],
            },
            "name",
        )
        if existing:
            return existing
        raise

    security.audit_event(
        event_type="payment.opened",
        target_doctype=PAYMENT_DOCTYPE,
        target_name=payment.name,
        source_version=_text(request.pricing_version_snapshot),
        safe_reason="pricing_finalized",
    )
    _notify_payment_opened(request, payment)
    return payment.name
