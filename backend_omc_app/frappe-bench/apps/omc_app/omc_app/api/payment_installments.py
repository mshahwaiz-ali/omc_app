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


def _assert_customer_owns_request(request):
    context = identity.require_customer_context()
    if not identity.request_is_owned(request, context):
        frappe.throw(
            "You do not have permission to access payments for this request.",
            frappe.PermissionError,
        )
    return context


def _read_accounting_summary(request) -> dict:
    required = max(flt(request.payable_amount or 0, 6), 0)
    currency = _text(request.pricing_currency) or "PKR"
    link = _canonical_link(request.name)
    invoice_name = _text(getattr(link, "sales_invoice", None)) if link else ""
    accounting_status = _text(getattr(link, "accounting_status", None)) if link else "Unmatched"
    invoice_total = required
    outstanding = required

    if invoice_name and frappe.db.exists("Sales Invoice", invoice_name):
        invoice = frappe.db.get_value(
            "Sales Invoice",
            invoice_name,
            ["docstatus", "grand_total", "outstanding_amount", "currency"],
            as_dict=True,
        )
        invoice_total = max(flt(invoice.grand_total or 0, 6), 0)
        outstanding = max(flt(invoice.outstanding_amount or 0, 6), 0)
        currency = _text(invoice.currency) or currency
        if int(invoice.docstatus or 0) != 1:
            accounting_status = "Reversed"
        elif outstanding <= 0.000001 and invoice_total > 0:
            accounting_status = "Settled"
        elif outstanding + 0.000001 < invoice_total:
            accounting_status = "Partially Settled"
        elif not accounting_status:
            accounting_status = "Unmatched"

    paid_amount = max(flt(invoice_total - outstanding, 6), 0)
    if required > 0:
        paid_amount = min(paid_amount, required)
        outstanding = min(outstanding, required)

    history = frappe.get_all(
        payments.PAYMENT_DOCTYPE,
        filters={
            "service_request": request.name,
            "visible_to_customer": 1,
        },
        fields=[
            "name",
            "payment_title",
            "amount",
            "accounted_amount",
            "currency",
            "status",
            "receipt_status",
            "accounting_status",
            "linked_invoice",
            "linked_payment_entry",
            "paid_on",
            "creation",
        ],
        order_by="creation desc",
        limit_page_length=100,
    )
    payment_history = [
        {
            "payment": row.name,
            "title": row.payment_title or "Service Payment",
            "amount": flt(row.amount or 0, 6),
            "accounted_amount": flt(row.accounted_amount or 0, 6),
            "currency": row.currency or currency,
            "status": row.status or "Pending",
            "receipt_status": row.receipt_status or "Not Submitted",
            "accounting_status": row.accounting_status or "Unmatched",
            "linked_invoice": row.linked_invoice or "",
            "linked_payment_entry": row.linked_payment_entry or "",
            "paid_on": str(row.paid_on) if row.paid_on else "",
            "created_at": str(row.creation) if row.creation else "",
        }
        for row in history
    ]

    open_payment = _open_payment(request.name)
    can_make_payment = bool(
        outstanding > 0.000001
        and _text(request.request_state) in OPEN_REQUEST_STATES
        and _text(request.status) not in {"Completed", "Cancelled"}
        and not open_payment
    )
    if accounting_status == "Settled" or outstanding <= 0.000001:
        activation_status = _text(request.request_state) or "Ready for Activation"
    else:
        activation_status = "Awaiting Full Settlement"

    return {
        "request": request.name,
        "canonical_invoice": invoice_name,
        "currency": currency,
        "invoice_total": invoice_total,
        "paid_amount": paid_amount,
        "outstanding_amount": outstanding,
        "accounting_status": accounting_status or "Unmatched",
        "activation_status": activation_status,
        "request_state": _text(request.request_state),
        "can_make_payment": can_make_payment,
        "maximum_payment_amount": outstanding if can_make_payment else 0,
        "open_payment": open_payment.name if open_payment else "",
        "payments": payment_history,
    }


@frappe.whitelist()
def get_accounting_summary(service_request=None):
    request_name = _text(service_request)
    if not request_name or not frappe.db.exists("OMC Service Request", request_name):
        frappe.throw("Service request was not found.", frappe.DoesNotExistError)
    request = frappe.get_doc("OMC Service Request", request_name)
    _assert_customer_owns_request(request)
    return _read_accounting_summary(request)


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
    _assert_customer_owns_request(request)
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
