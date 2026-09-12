from __future__ import annotations

import frappe
from frappe.utils import flt

from omc_app.api import accounting_reconciliation, identity, payments, security


OPEN_REQUEST_STATES = {"Pending Payment", "Financial Hold", "Activation Failed"}


def _text(value) -> str:
    return str(value or "").strip()


def _current_user() -> str:
    return _text(getattr(getattr(frappe, "session", None), "user", None)) or "Guest"


def _canonical_link(request_name: str):
    return frappe.db.get_value(
        "OMC Accounting Link",
        {"base_request_key": request_name},
        ["sales_invoice", "accounting_status"],
        as_dict=True,
    )


def _authoritative_remaining(request) -> tuple[float, str, str]:
    link = _canonical_link(request.name)
    if not link:
        return (
            max(flt(request.payable_amount or 0, 6), 0),
            "Unmatched",
            "",
        )
    result = accounting_reconciliation.reconcile_request(request.name)
    invoice = ""
    invoices = result.get("linked_invoices") or []
    if invoices:
        invoice = invoices[0]
    elif link.sales_invoice:
        invoice = link.sales_invoice
    return (
        max(flt(result.get("remaining_amount") or 0, 6), 0),
        _text(result.get("accounting_status")) or "Unmatched",
        invoice,
    )


def _open_payment(request_name: str):
    rows = frappe.get_all(
        payments.PAYMENT_DOCTYPE,
        filters={
            "service_request": request_name,
            "visible_to_customer": 1,
            "status": ["!=", "Cancelled"],
        },
        fields=["name", "status", "linked_payment_entry"],
        order_by="creation desc",
        limit_page_length=100,
    )
    for row in rows:
        status = _text(row.status)
        if status == "Paid":
            continue
        entry = _text(row.linked_payment_entry)
        if entry and frappe.db.get_value("Payment Entry", entry, "docstatus") == 1:
            continue
        return frappe.get_doc(payments.PAYMENT_DOCTYPE, row.name)
    return None


@frappe.whitelist(methods=["POST"])
def create_installment(service_request=None, amount=None):
    actor = _current_user()
    if actor == "Guest":
        frappe.throw("Login is required.", frappe.PermissionError)
    security.enforce_rate_limit("customer_mutation", actor=actor)

    request_name = _text(service_request)
    if not request_name:
        frappe.throw("service_request is required.", frappe.ValidationError)

    locked = frappe.db.get_value(
        "OMC Service Request",
        request_name,
        "name",
        for_update=True,
    )
    if not locked:
        frappe.throw("Service request was not found.", frappe.DoesNotExistError)

    request = frappe.get_doc("OMC Service Request", locked)
    context = identity.require_customer_context()
    if not identity.request_is_owned(request, context):
        frappe.throw(
            "You do not have permission to create a payment for this request.",
            frappe.PermissionError,
        )
    if _text(request.status) in {"Completed", "Cancelled"}:
        frappe.throw(
            "A new payment cannot be created for a closed service request.",
            frappe.ValidationError,
        )
    if _text(request.request_state) not in OPEN_REQUEST_STATES:
        frappe.throw(
            "This service request is not currently accepting another payment.",
            frappe.ValidationError,
        )

    existing = _open_payment(request.name)
    if existing:
        return {
            "created": False,
            "payment": existing.name,
            "amount": flt(existing.amount or 0, 6),
            "currency": existing.currency or request.pricing_currency or "PKR",
            "status": existing.status,
            "message": "An open installment already exists for this request.",
        }

    remaining, accounting_status, invoice = _authoritative_remaining(request)
    if accounting_status == "Settled" or remaining <= 0:
        frappe.throw("This request is already fully settled.", frappe.ValidationError)

    installment_amount = flt(amount if amount is not None else remaining, 6)
    if installment_amount <= 0:
        frappe.throw("Installment amount must be greater than zero.", frappe.ValidationError)
    if installment_amount > remaining + 0.000001:
        frappe.throw(
            f"Installment amount cannot exceed the current outstanding amount of {remaining:g}.",
            frappe.ValidationError,
        )

    sequence = frappe.db.count(
        payments.PAYMENT_DOCTYPE,
        filters={"service_request": request.name},
    ) + 1
    payment = frappe.new_doc(payments.PAYMENT_DOCTYPE)
    payment.service_request = request.name
    payment.payment_title = f"{request.service_title or request.title or 'Service'} Payment {sequence}"
    payment.amount = installment_amount
    payment.accounted_amount = 0
    payment.currency = request.pricing_currency or "PKR"
    payment.status = "Pending"
    payment.receipt_status = "Not Submitted"
    payment.accounting_status = "Unmatched"
    payment.quarantine_status = "Not Required"
    payment.linked_invoice = invoice or None
    payment.visible_to_customer = 1
    payment.remarks = "Installment opened against the authoritative ERP outstanding amount."
    payment.insert(ignore_permissions=True)

    payments.mobile._create_service_timeline_entry(
        service_request=request.name,
        event_type="Payment Updated",
        title="Payment Installment Opened",
        description=(
            f"A payment installment of {payment.currency} {installment_amount:g} "
            "is ready for receipt submission."
        ),
        visible_to_customer=1,
    )
    security.audit_event(
        event_type="payment.installment_opened",
        target_doctype=payments.PAYMENT_DOCTYPE,
        target_name=payment.name,
        actor=actor,
        safe_reason="customer_installment",
    )

    return {
        "created": True,
        "payment": payment.name,
        "amount": installment_amount,
        "currency": payment.currency,
        "status": payment.status,
        "accounting_status": accounting_status,
        "remaining_before_payment": remaining,
        "maximum_payment_amount": remaining,
        "linked_invoice": invoice,
    }
