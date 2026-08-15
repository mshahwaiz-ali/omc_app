"""Canonical ERP finance bridge for verified OMC service payments.

OMC Service Payment remains the mobile/payment-review authority until a
payment is verified. After verification this adapter posts the corresponding
Sales Invoice and Payment Entry into ERPNext.

This module never commits. Callers own transaction boundaries.
"""

from __future__ import annotations

from typing import Any

import frappe
from frappe.utils import flt, nowdate

from erpnext.accounts.doctype.payment_entry.payment_entry import (
    get_payment_entry,
)
from erpnext.accounts.doctype.payment_entry.payment_entry import (
    get_default_bank_cash_account,
)

from omc_app.api import erp_customer_resolver


PAYMENT_DOCTYPE = "OMC Service Payment"
REQUEST_DOCTYPE = "OMC Service Request"


def _text(value: Any) -> str:
    return str(value or "").strip()


def _settings():
    return frappe.get_single("OMC Mobile Settings")


def _profile_for_request(request):
    profile_name = _text(getattr(request, "customer_profile", None))
    if not profile_name:
        frappe.throw(
            "The service request has no customer profile.",
            frappe.ValidationError,
        )

    if not frappe.db.exists("OMC Customer Profile", profile_name):
        frappe.throw(
            "The linked customer profile does not exist.",
            frappe.DoesNotExistError,
        )

    return frappe.get_doc("OMC Customer Profile", profile_name)


def _validate_configuration(settings):
    company = _text(getattr(settings, "erp_company", None))
    item_code = _text(getattr(settings, "erp_service_item", None))
    mode_of_payment = _text(
        getattr(settings, "erp_default_payment_mode", None)
    )

    if not company or not frappe.db.exists("Company", company):
        frappe.throw(
            "OMC ERP Company is not configured correctly.",
            frappe.ValidationError,
        )

    if not item_code or not frappe.db.exists("Item", item_code):
        frappe.throw(
            "OMC ERP Service Item is not configured correctly.",
            frappe.ValidationError,
        )

    item = frappe.get_doc("Item", item_code)
    if int(getattr(item, "disabled", 0) or 0):
        frappe.throw(
            "The configured ERP Service Item is disabled.",
            frappe.ValidationError,
        )

    if int(getattr(item, "is_stock_item", 0) or 0):
        frappe.throw(
            "The configured ERP Service Item must be a non-stock item.",
            frappe.ValidationError,
        )

    if not mode_of_payment or not frappe.db.exists(
        "Mode of Payment",
        mode_of_payment,
    ):
        frappe.throw(
            "OMC ERP Default Payment Mode is not configured correctly.",
            frappe.ValidationError,
        )

    return {
        "company": company,
        "item_code": item_code,
        "mode_of_payment": mode_of_payment,
    }


def _mode_account(company: str, mode_of_payment: str) -> str:
    bank = get_default_bank_cash_account(
        company,
        "Bank",
        mode_of_payment=mode_of_payment,
    )

    if not bank:
        bank = get_default_bank_cash_account(
            company,
            "Cash",
            mode_of_payment=mode_of_payment,
        )

    account = _text(getattr(bank, "account", None) if bank else None)
    if not account:
        frappe.throw(
            (
                f"Mode of Payment {mode_of_payment} has no Bank/Cash "
                f"account configured for company {company}."
            ),
            frappe.ValidationError,
        )

    return account


def _resolve_customer(request):
    existing = _text(getattr(request, "erp_customer", None))
    if existing and frappe.db.exists("Customer", existing):
        return existing

    profile = _profile_for_request(request)
    result = erp_customer_resolver.resolve_profile_customer(profile)

    customer = _text(result.get("customer"))
    if not customer:
        frappe.throw(
            result.get("reason")
            or "ERP Customer could not be resolved.",
            frappe.ValidationError,
        )

    request.erp_customer = customer
    frappe.db.set_value(
        REQUEST_DOCTYPE,
        request.name,
        "erp_customer",
        customer,
        update_modified=False,
    )

    return customer


def _existing_invoice(payment):
    invoice = _text(getattr(payment, "erp_sales_invoice", None))
    if not invoice:
        return None

    if not frappe.db.exists("Sales Invoice", invoice):
        frappe.throw(
            "The linked ERP Sales Invoice no longer exists.",
            frappe.ValidationError,
        )

    doc = frappe.get_doc("Sales Invoice", invoice)
    if doc.docstatus == 2:
        frappe.throw(
            "The linked ERP Sales Invoice is cancelled.",
            frappe.ValidationError,
        )

    return doc


def _create_invoice(
    payment,
    request,
    *,
    customer: str,
    company: str,
    item_code: str,
):
    amount = flt(getattr(payment, "amount", 0))
    if amount <= 0:
        frappe.throw(
            "Verified payment amount must be greater than zero.",
            frappe.ValidationError,
        )

    invoice = frappe.new_doc("Sales Invoice")
    invoice.company = company
    invoice.customer = customer
    invoice.posting_date = nowdate()
    invoice.due_date = nowdate()

    title = (
        _text(getattr(request, "service_title", None))
        or _text(getattr(payment, "payment_title", None))
        or "OMC Professional Service"
    )

    invoice.append(
        "items",
        {
            "item_code": item_code,
            "item_name": title,
            "description": (
                f"{title}\nOMC Service Request: {request.name}"
            ),
            "qty": 1,
            "rate": amount,
        },
    )

    invoice.set_missing_values()
    invoice.calculate_taxes_and_totals()

    if flt(invoice.grand_total) != amount:
        frappe.throw(
            (
                "ERP Sales Invoice total does not match the verified "
                "OMC payment amount."
            ),
            frappe.ValidationError,
        )

    invoice.insert(ignore_permissions=True)
    invoice.submit()

    payment.erp_sales_invoice = invoice.name
    frappe.db.set_value(
        PAYMENT_DOCTYPE,
        payment.name,
        "erp_sales_invoice",
        invoice.name,
        update_modified=False,
    )

    return invoice


def _ensure_invoice(payment, request, config, customer):
    invoice = _existing_invoice(payment)
    if invoice:
        return invoice, False

    return (
        _create_invoice(
            payment,
            request,
            customer=customer,
            company=config["company"],
            item_code=config["item_code"],
        ),
        True,
    )


def _existing_payment_entry(payment):
    payment_entry = _text(
        getattr(payment, "erp_payment_entry", None)
    )
    if not payment_entry:
        return None

    if not frappe.db.exists("Payment Entry", payment_entry):
        frappe.throw(
            "The linked ERP Payment Entry no longer exists.",
            frappe.ValidationError,
        )

    doc = frappe.get_doc("Payment Entry", payment_entry)
    if doc.docstatus == 2:
        frappe.throw(
            "The linked ERP Payment Entry is cancelled.",
            frappe.ValidationError,
        )

    return doc


def _create_payment_entry(payment, invoice, config):
    # The payment record is the transaction-level source of truth.
    # The global setting remains a backward-compatible fallback only.
    mode_of_payment = (
        _text(getattr(payment, "payment_method", None))
        or config["mode_of_payment"]
    )

    if not frappe.db.exists("Mode of Payment", mode_of_payment):
        frappe.throw(
            f"Mode of Payment {mode_of_payment} does not exist.",
            frappe.ValidationError,
        )

    account = _mode_account(
        config["company"],
        mode_of_payment,
    )

    payment_entry = get_payment_entry(
        "Sales Invoice",
        invoice.name,
        bank_account=account,
        ignore_permissions=True,
    )

    payment_entry.mode_of_payment = mode_of_payment

    # Compatibility with client ERPNext builds that contain legacy
    # Payment Entry commission hooks but no corresponding Custom Fields.
    # These are transient document attributes only; ERPNext core/schema
    # remains untouched.
    if not payment_entry.meta.has_field("custom_structure_name"):
        payment_entry.custom_structure_name = None

    if not payment_entry.meta.has_field("custom_omc_customer"):
        payment_entry.custom_omc_customer = None

    reference = (
        _text(getattr(payment, "payment_reference", None))
        or f"OMC-{payment.name}"
    )

    payment_entry.reference_no = reference
    payment_entry.reference_date = nowdate()

    payment_entry.remarks = (
        f"OMC verified payment {payment.name} "
        f"for service request {payment.service_request}."
    )

    payment_entry.insert(ignore_permissions=True)
    payment_entry.submit()

    payment.erp_payment_entry = payment_entry.name
    frappe.db.set_value(
        PAYMENT_DOCTYPE,
        payment.name,
        "erp_payment_entry",
        payment_entry.name,
        update_modified=False,
    )

    return payment_entry


def _ensure_payment_entry(payment, invoice, config):
    existing = _existing_payment_entry(payment)
    if existing:
        return existing, False

    return _create_payment_entry(payment, invoice, config), True


def finalize_verified_payment(payment):
    """Post a verified OMC payment into ERPNext exactly once."""
    payment = (
        frappe.get_doc(PAYMENT_DOCTYPE, payment)
        if isinstance(payment, str)
        else payment
    )

    if not payment or payment.doctype != PAYMENT_DOCTYPE:
        frappe.throw(
            "A valid OMC Service Payment is required.",
            frappe.ValidationError,
        )

    request_name = _text(getattr(payment, "service_request", None))
    if not request_name or not frappe.db.exists(
        REQUEST_DOCTYPE,
        request_name,
    ):
        frappe.throw(
            "The linked service request does not exist.",
            frappe.ValidationError,
        )

    request = frappe.get_doc(REQUEST_DOCTYPE, request_name)
    settings = _settings()
    config = _validate_configuration(settings)

    customer = _resolve_customer(request)

    try:
        payment.erp_finance_status = "Pending"
        payment.erp_finance_error = ""
        payment.save(ignore_permissions=True)

        invoice, invoice_created = _ensure_invoice(
            payment,
            request,
            config,
            customer,
        )

        if invoice.docstatus != 1:
            frappe.throw(
                "ERP Sales Invoice must be submitted.",
                frappe.ValidationError,
            )

        payment_entry, payment_entry_created = _ensure_payment_entry(
            payment,
            invoice,
            config,
        )

        if payment_entry.docstatus != 1:
            frappe.throw(
                "ERP Payment Entry must be submitted.",
                frappe.ValidationError,
            )

        invoice.reload()

        if flt(invoice.outstanding_amount) > 0:
            frappe.throw(
                (
                    "ERP Payment Entry was submitted but the Sales Invoice "
                    "still has an outstanding balance."
                ),
                frappe.ValidationError,
            )

        payment.erp_finance_status = "Posted"
        payment.erp_finance_error = ""
        payment.erp_sales_invoice = invoice.name
        payment.erp_payment_entry = payment_entry.name
        payment.save(ignore_permissions=True)

        from omc_app.api import referral_commissions

        commission = referral_commissions.create_earning_for_posted_payment(
            payment,
            request=request,
            invoice=invoice,
        )

        return {
            "status": "Posted",
            "customer": customer,
            "sales_invoice": invoice.name,
            "payment_entry": payment_entry.name,
            "invoice_created": invoice_created,
            "payment_entry_created": payment_entry_created,
            "invoice_outstanding": flt(invoice.outstanding_amount),
            "commission": commission,
        }

    except Exception as error:
        payment.erp_finance_status = "Failed"
        payment.erp_finance_error = _text(error)[:1000]
        payment.save(ignore_permissions=True)
        raise
