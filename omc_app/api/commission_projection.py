from __future__ import annotations

import hashlib
from decimal import Decimal, ROUND_HALF_UP

import frappe
from frappe.utils import now_datetime


CALCULATION_VERSION = "omc-reference-allocation-v1"
COMPONENTS = (
    ("Sales Person", "custom_source", "custom_sales_person", "custom_sales_person_percentage"),
    ("Business Partner Consultant", None, "custom_business_partner_consultant", "custom_business_partner_consultant_percentage"),
    ("Reference Business Partner", None, "custom_reference_business_partner", "custom_reference_business_partner_percentage"),
)


def _text(value) -> str:
    return str(value or "").strip()


def _money(value, precision=2) -> Decimal:
    return Decimal(str(value or 0)).quantize(Decimal(1).scaleb(-precision), rounding=ROUND_HALF_UP)


def _key(*values) -> str:
    return hashlib.sha256("|".join(_text(value) for value in values).encode()).hexdigest()


def suppress_legacy_commission_writer(doc, method=None):
    """Prevent the vendor controller from creating unlinked commission Journal Entries."""
    structure = _text(getattr(doc, "custom_structure_name", None))
    if not structure:
        return
    invoice_names = {
        row.reference_name
        for row in (doc.references or [])
        if row.reference_doctype == "Sales Invoice" and row.reference_name
    }
    if not invoice_names:
        return
    linked_invoices = set(
        frappe.get_all(
            "OMC Accounting Link",
            filters={"sales_invoice": ["in", sorted(invoice_names)]},
            pluck="sales_invoice",
            limit_page_length=min(len(invoice_names), 1000),
        )
    )
    if not linked_invoices:
        return
    if linked_invoices != invoice_names:
        frappe.throw(
            "A commission-bearing Payment Entry cannot mix OMC-linked and unrelated invoices.",
            frappe.ValidationError,
        )
    doc.flags.omc_commission_structure = structure
    doc.custom_structure_name = None


def restore_commission_source(doc) -> None:
    structure = _text(getattr(doc.flags, "omc_commission_structure", None))
    if not structure:
        return
    doc.custom_structure_name = structure
    frappe.db.set_value("Payment Entry", doc.name, "custom_structure_name", structure, update_modified=False)


def _beneficiary_user(beneficiary_type: str, beneficiary: str) -> str:
    beneficiary_type = _text(beneficiary_type)
    beneficiary = _text(beneficiary)
    if not beneficiary:
        return ""
    if beneficiary_type == "User" and frappe.db.exists("User", beneficiary):
        return beneficiary
    if not beneficiary_type or not frappe.db.exists("DocType", beneficiary_type):
        return ""
    if not frappe.db.exists(beneficiary_type, beneficiary):
        return ""
    meta = frappe.get_meta(beneficiary_type)
    for fieldname in ("user_link", "user_id", "user"):
        if meta.get_field(fieldname):
            user = _text(frappe.db.get_value(beneficiary_type, beneficiary, fieldname))
            if user and frappe.db.exists("User", user):
                return user
    return ""


def _queue_unresolved(payment, reference, component, beneficiary_type, beneficiary):
    key = _key(payment.name, reference.name, component, beneficiary_type, beneficiary)
    if frappe.db.exists(
        "OMC Reconciliation Review",
        {
            "domain": "Commission",
            "source_doctype": "Payment Entry",
            "source_name": _key(payment.name),
            "source_version": key,
            "reason_code": "beneficiary_user_unresolved",
        },
    ):
        return
    frappe.get_doc({
        "doctype": "OMC Reconciliation Review",
        "domain": "Commission",
        "source_doctype": "Payment Entry",
        "source_name": _key(payment.name),
        "source_version": key,
        "safe_evidence_json": frappe.as_json({
            "component": component,
            "beneficiary_type": beneficiary_type,
            "beneficiary_hash": _key(beneficiary),
            "reference_hash": _key(reference.reference_name),
        }),
        "status": "Open",
        "reason_code": "beneficiary_user_unresolved",
    }).insert(ignore_permissions=True)


def project_payment_entry(payment):
    restore_commission_source(payment)
    if payment.docstatus != 1:
        return {"created": 0, "skipped": 0}
    structure = _text(getattr(payment, "custom_structure_name", None))
    if not structure:
        return {"created": 0, "skipped": 0}
    summary = {"created": 0, "skipped": 0, "unresolved": 0}
    for reference in payment.references or []:
        if reference.reference_doctype != "Sales Invoice" or not reference.reference_name:
            continue
        accounting = frappe.get_all(
            "OMC Accounting Link",
            filters={
                "payment_entry": payment.name,
                "payment_reference_row": reference.name,
                "sales_invoice": reference.reference_name,
            },
            fields=["service_request", "erp_customer", "allocated_amount", "exchange_rate", "invoice_currency"],
            limit_page_length=1,
        )
        if not accounting:
            continue
        link = accounting[0]
        request = frappe.get_doc("OMC Service Request", link.service_request)
        basis = _money(min(Decimal(str(link.allocated_amount or 0)), Decimal(str(frappe.db.get_value("Sales Invoice", reference.reference_name, "grand_total") or 0))))
        if basis <= 0:
            continue
        attribution = _text(request.referral_attribution)
        persona = ""
        if attribution and frappe.db.exists("OMC Referral Attribution", attribution):
            persona = _text(frappe.db.get_value("OMC Referral Attribution", attribution, "owner_persona_snapshot"))
        for component, type_field, beneficiary_field, percent_field in COMPONENTS:
            beneficiary = _text(getattr(payment, beneficiary_field, None))
            percent = Decimal(str(getattr(payment, percent_field, 0) or 0))
            if not beneficiary or percent <= 0:
                continue
            beneficiary_type = _text(getattr(payment, type_field, None)) if type_field else (
                "Consultant" if component == "Business Partner Consultant" else "Business Partner"
            )
            beneficiary_user = _beneficiary_user(beneficiary_type, beneficiary)
            if not beneficiary_user:
                _queue_unresolved(payment, reference, component, beneficiary_type, beneficiary)
                summary["unresolved"] += 1
                continue
            allocation_key = _key(
                payment.name, reference.name, component, beneficiary_type,
                beneficiary, CALCULATION_VERSION,
            )
            if frappe.db.exists("OMC Commission Allocation", {"allocation_key": allocation_key}):
                summary["skipped"] += 1
                continue
            amount = (basis * percent / Decimal("100")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
            if amount <= 0:
                continue
            frappe.get_doc({
                "doctype": "OMC Commission Allocation",
                "allocation_key": allocation_key,
                "payment_entry": payment.name,
                "payment_reference_row": reference.name,
                "sales_invoice": reference.reference_name,
                "service_request": request.name,
                "erp_customer": link.erp_customer,
                "referral_attribution": attribution or None,
                "component": component,
                "beneficiary_type": beneficiary_type,
                "beneficiary": beneficiary,
                "beneficiary_user": beneficiary_user,
                "source_persona_snapshot": persona,
                "currency": link.invoice_currency or "PKR",
                "exchange_rate": link.exchange_rate or 1,
                "basis_amount": float(basis),
                "commission_percent_snapshot": float(percent),
                "commission_amount": float(amount),
                "structure_snapshot": structure,
                "calculation_version": CALCULATION_VERSION,
                "status": "Calculated",
                "earned_on": payment.posting_date,
                "accounting_evidence_status": "Matched",
            }).insert(ignore_permissions=True)
            summary["created"] += 1
    return summary


def reverse_payment_entry(payment, *, reason: str):
    rows = frappe.get_all(
        "OMC Commission Allocation", filters={"payment_entry": payment.name, "status": ["!=", "Reversed"]},
        pluck="name", limit_page_length=1000,
    )
    for name in rows:
        frappe.db.set_value(
            "OMC Commission Allocation", name,
            {
                "status": "Reversed", "reversal_reason": _text(reason)[:1000],
                "reversed_on": now_datetime(), "accounting_evidence_status": "Reversed",
            },
            update_modified=False,
        )
    return {"reversed": len(rows)}
