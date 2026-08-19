from __future__ import annotations

import hashlib
from decimal import Decimal, ROUND_HALF_UP

import frappe
from frappe.utils import now_datetime

from omc_app.api import reconciliation_queues, security


CALCULATION_VERSION = "omc-reference-allocation-v1"
COMPONENTS = (
    ("Sales Person", "custom_source", "custom_sales_person", "custom_sales_person_percentage"),
    (
        "Business Partner Consultant",
        None,
        "custom_business_partner_consultant",
        "custom_business_partner_consultant_percentage",
    ),
    (
        "Reference Business Partner",
        None,
        "custom_reference_business_partner",
        "custom_reference_business_partner_percentage",
    ),
)


def _text(value) -> str:
    return str(value or "").strip()


def _money(value, precision=2) -> Decimal:
    return Decimal(str(value or 0)).quantize(
        Decimal(1).scaleb(-precision),
        rounding=ROUND_HALF_UP,
    )


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
    # Vendor ERP code interprets this field during submit and may create a
    # Journal Entry. Clear it only for that submit path; OMC restores the
    # source snapshot afterwards and projects evidence into its own immutable
    # Commission Allocation model.
    doc.custom_structure_name = None


def restore_commission_source(doc) -> None:
    structure = _text(getattr(doc.flags, "omc_commission_structure", None))
    if not structure:
        return
    doc.custom_structure_name = structure
    frappe.db.set_value(
        "Payment Entry",
        doc.name,
        "custom_structure_name",
        structure,
        update_modified=False,
    )


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
            user = _text(
                frappe.db.get_value(beneficiary_type, beneficiary, fieldname)
            )
            if user and frappe.db.exists("User", user):
                return user
    return ""


def _queue_unresolved(payment, reference, component, beneficiary_type, beneficiary):
    source_version = _key(
        payment.name,
        reference.name,
        component,
        beneficiary_type,
        beneficiary,
    )
    return reconciliation_queues.open_human_review(
        domain="Commission",
        source_doctype="Payment Entry",
        source_name=payment.name,
        source_version=source_version,
        reason_code="beneficiary_user_unresolved",
        safe_evidence={
            "component": component,
            "beneficiary_type": beneficiary_type,
            "beneficiary_hash": _key(beneficiary),
            "invoice_hash": _key(reference.reference_name),
        },
    )


def _accounting_gate(payment, reference, request_name: str) -> str:
    base_status = _text(
        frappe.db.get_value(
            "OMC Accounting Link",
            {"base_request_key": request_name},
            "accounting_status",
        )
    )
    source_version = _key(payment.name, payment.modified, reference.name, base_status)
    evidence = {
        "payment_entry": payment.name,
        "service_request": request_name,
        "sales_invoice": reference.reference_name,
        "accounting_status": base_status,
    }
    if base_status == "Quarantined":
        reconciliation_queues.open_technical_quarantine(
            domain="Commission",
            source_doctype="Payment Entry",
            source_name=payment.name,
            source_version=source_version,
            failure_code="accounting_quarantined",
            safe_evidence=evidence,
        )
        return "blocked"
    if base_status == "Review Required":
        reconciliation_queues.open_human_review(
            domain="Commission",
            source_doctype="Payment Entry",
            source_name=payment.name,
            source_version=source_version,
            reason_code="accounting_review_required",
            safe_evidence=evidence,
        )
        return "blocked"
    if base_status in {"Reversed", "Cancelled"}:
        return "reversed"
    if base_status not in {"Partially Settled", "Settled"}:
        return "not_ready"
    # Do not broadly resolve Commission queues here. The same Payment Entry can
    # still have an unrelated beneficiary-resolution review even after its
    # accounting evidence becomes clean; that review must remain open until the
    # beneficiary issue itself is resolved.
    return "ready"


def project_payment_entry(payment):
    restore_commission_source(payment)
    if payment.docstatus != 1:
        return {"created": 0, "skipped": 0, "blocked": 0}
    structure = _text(getattr(payment, "custom_structure_name", None))
    if not structure:
        return {"created": 0, "skipped": 0, "blocked": 0}

    summary = {"created": 0, "skipped": 0, "unresolved": 0, "blocked": 0}
    for reference in payment.references or []:
        if (
            reference.reference_doctype != "Sales Invoice"
            or not reference.reference_name
        ):
            continue
        accounting = frappe.get_all(
            "OMC Accounting Link",
            filters={
                "payment_entry": payment.name,
                "payment_reference_row": reference.name,
                "sales_invoice": reference.reference_name,
            },
            fields=[
                "service_request",
                "erp_customer",
                "allocated_amount",
                "exchange_rate",
                "invoice_currency",
            ],
            limit_page_length=1,
        )
        if not accounting:
            base_request = frappe.db.get_value(
                "OMC Accounting Link",
                {"sales_invoice": reference.reference_name, "base_invoice_key": reference.reference_name},
                "service_request",
            )
            if base_request:
                reconciliation_queues.open_technical_quarantine(
                    domain="Commission",
                    source_doctype="Payment Entry",
                    source_name=payment.name,
                    source_version=_key(payment.name, payment.modified, reference.name),
                    failure_code="payment_accounting_link_missing",
                    safe_evidence={
                        "payment_entry": payment.name,
                        "sales_invoice": reference.reference_name,
                        "service_request": base_request,
                    },
                )
                summary["blocked"] += 1
            continue

        link = accounting[0]
        gate = _accounting_gate(payment, reference, link.service_request)
        if gate != "ready":
            summary["blocked"] += 1
            continue

        request = frappe.get_doc("OMC Service Request", link.service_request)
        invoice_total = Decimal(
            str(
                frappe.db.get_value(
                    "Sales Invoice",
                    reference.reference_name,
                    "grand_total",
                )
                or 0
            )
        )
        basis = _money(min(Decimal(str(link.allocated_amount or 0)), invoice_total))
        if basis <= 0:
            continue

        attribution = _text(request.referral_attribution)
        persona = ""
        if attribution and frappe.db.exists("OMC Referral Attribution", attribution):
            persona = _text(
                frappe.db.get_value(
                    "OMC Referral Attribution",
                    attribution,
                    "owner_persona_snapshot",
                )
            )

        for component, type_field, beneficiary_field, percent_field in COMPONENTS:
            beneficiary = _text(getattr(payment, beneficiary_field, None))
            percent = Decimal(str(getattr(payment, percent_field, 0) or 0))
            if not beneficiary or percent <= 0:
                continue
            beneficiary_type = (
                _text(getattr(payment, type_field, None))
                if type_field
                else (
                    "Consultant"
                    if component == "Business Partner Consultant"
                    else "Business Partner"
                )
            )
            beneficiary_user = _beneficiary_user(beneficiary_type, beneficiary)
            if not beneficiary_user:
                _queue_unresolved(
                    payment,
                    reference,
                    component,
                    beneficiary_type,
                    beneficiary,
                )
                summary["unresolved"] += 1
                continue

            allocation_key = _key(
                payment.name,
                reference.name,
                component,
                beneficiary_type,
                beneficiary,
                CALCULATION_VERSION,
            )
            if frappe.db.exists(
                "OMC Commission Allocation",
                {"allocation_key": allocation_key},
            ):
                summary["skipped"] += 1
                continue

            amount = (basis * percent / Decimal("100")).quantize(
                Decimal("0.01"),
                rounding=ROUND_HALF_UP,
            )
            if amount <= 0:
                continue

            doc = frappe.get_doc(
                {
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
                }
            )
            doc.insert(ignore_permissions=True)
            security.audit_event(
                event_type="commission.allocation_created",
                target_doctype="OMC Commission Allocation",
                target_name=doc.name,
                new_state="calculated",
                source_version=CALCULATION_VERSION,
            )
            summary["created"] += 1
    return summary


def reverse_payment_entry(payment, *, reason: str):
    rows = frappe.get_all(
        "OMC Commission Allocation",
        filters={
            "payment_entry": payment.name,
            "status": ["!=", "Reversed"],
        },
        fields=["name", "status", "calculation_version"],
        limit_page_length=1000,
    )
    for row in rows:
        frappe.db.set_value(
            "OMC Commission Allocation",
            row.name,
            {
                "status": "Reversed",
                "reversal_reason": _text(reason)[:1000],
                "reversed_on": now_datetime(),
                "accounting_evidence_status": "Reversed",
            },
            update_modified=False,
        )
        reconciliation_queues.resolve_source_queues(
            domain="Commission",
            source_doctype="OMC Commission Allocation",
            source_name=row.name,
            resolution_note="Underlying Payment Entry was reversed.",
        )
        security.audit_event(
            event_type="commission.allocation_reversed",
            target_doctype="OMC Commission Allocation",
            target_name=row.name,
            old_state=_text(row.status),
            new_state="reversed",
            source_version=row.calculation_version,
            safe_reason="payment_entry_reversed",
        )
    return {"reversed": len(rows)}
