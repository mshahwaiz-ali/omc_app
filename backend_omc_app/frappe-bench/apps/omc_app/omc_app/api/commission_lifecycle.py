from __future__ import annotations

from decimal import Decimal, ROUND_HALF_UP

import frappe
from frappe.utils import getdate, now_datetime, today

from omc_app.api import capabilities, reconciliation_queues, security


APPROVABLE = {"Calculated", "Held"}
REJECTABLE = {"Calculated", "Held", "Approved", "Payable"}
PAYABLE_FROM = {"Approved"}
PAID_FROM = {"Payable"}
LEGACY_COMMISSION_ACCOUNT = "Commission Payable - O"
HOUSE_SALES_PERSON = "omc@omchouse.com"


def _text(value) -> str:
    return str(value or "").strip()


def _money(value) -> Decimal:
    return Decimal(str(value or 0)).quantize(
        Decimal("0.01"),
        rounding=ROUND_HALF_UP,
    )


def _locked_allocation(name: str):
    name = _text(name)
    locked = frappe.db.get_value("OMC Commission Allocation", name, "name", for_update=True)
    if not locked:
        frappe.throw("Commission allocation was not found.", frappe.DoesNotExistError)
    return frappe.get_doc("OMC Commission Allocation", locked)


def _is_house_direct(payment, allocation) -> bool:
    if frappe.db.has_column("Payment Entry", "custom_omc_customer"):
        if int(
            frappe.db.get_value(
                "Payment Entry", payment.name, "custom_omc_customer"
            )
            or 0
        ):
            return True

    customer = _text(getattr(allocation, "erp_customer", None))
    if customer and frappe.db.exists("Customer", customer):
        sales_person = _text(
            frappe.db.get_value("Customer", customer, "sales_person")
        ).lower()
        if sales_person == HOUSE_SALES_PERSON:
            return True
    return False


def _historical_evidence_state(allocation) -> tuple[str, str]:
    payment_name = _text(allocation.payment_entry)
    journal_name = _text(getattr(allocation, "legacy_journal_entry", None))

    if not payment_name or not frappe.db.exists("Payment Entry", payment_name):
        return "Missing", "historical_payment_entry_missing"
    payment = frappe.get_doc("Payment Entry", payment_name)
    if int(payment.docstatus or 0) != 1:
        return "Reversed", "historical_payment_entry_not_submitted"

    if _is_house_direct(payment, allocation):
        return "Reversed", "historical_house_direct_suppression"

    if not journal_name or not frappe.db.exists("Journal Entry", journal_name):
        return "Missing", "historical_journal_entry_missing"
    journal = frappe.get_doc("Journal Entry", journal_name)
    if int(journal.docstatus or 0) != 1:
        return "Reversed", "historical_journal_entry_not_submitted"

    expected_type = _text(allocation.beneficiary_type)
    expected_party = _text(allocation.beneficiary)
    expected_amount = _money(allocation.commission_amount)

    matching_rows = []
    for row in journal.accounts or []:
        if _text(row.account) != LEGACY_COMMISSION_ACCOUNT:
            continue
        if _text(getattr(row, "reference_type", None)) != "Payment Entry":
            continue
        if _text(getattr(row, "reference_name", None)) != payment_name:
            continue
        if _text(getattr(row, "party_type", None)) != expected_type:
            continue
        if _text(getattr(row, "party", None)) != expected_party:
            continue
        if _money(getattr(row, "credit_in_account_currency", 0)) != expected_amount:
            continue
        matching_rows.append(row)

    if len(matching_rows) != 1:
        return (
            "Review Required",
            "historical_commission_payable_row_ambiguous"
            if matching_rows
            else "historical_commission_payable_row_missing",
        )

    return "Matched", "matched"


def _current_evidence_state(allocation) -> tuple[str, str]:
    if not frappe.db.exists("Payment Entry", allocation.payment_entry):
        return "Missing", "payment_entry_missing"
    payment_docstatus = frappe.db.get_value("Payment Entry", allocation.payment_entry, "docstatus")
    if int(payment_docstatus or 0) != 1:
        return "Reversed", "payment_entry_not_submitted"

    if not frappe.db.exists("Sales Invoice", allocation.sales_invoice):
        return "Missing", "sales_invoice_missing"
    invoice = frappe.db.get_value(
        "Sales Invoice",
        allocation.sales_invoice,
        ["docstatus", "is_return"],
        as_dict=True,
    )
    if int(invoice.docstatus or 0) != 1 or int(invoice.is_return or 0):
        return "Reversed", "sales_invoice_reversed"

    payment_link = frappe.db.get_value(
        "OMC Accounting Link",
        {
            "service_request": allocation.service_request,
            "sales_invoice": allocation.sales_invoice,
            "payment_entry": allocation.payment_entry,
            "payment_reference_row": allocation.payment_reference_row,
        },
        ["name", "accounting_status"],
        as_dict=True,
    )
    if not payment_link:
        return "Missing", "payment_accounting_link_missing"

    base_status = _text(
        frappe.db.get_value(
            "OMC Accounting Link",
            {"base_request_key": allocation.service_request},
            "accounting_status",
        )
    )
    if base_status == "Quarantined":
        return "Quarantined", "request_accounting_quarantined"
    if base_status == "Review Required":
        return "Review Required", "request_accounting_review_required"
    if base_status in {"Reversed", "Cancelled"}:
        return "Reversed", "request_accounting_reversed"
    if base_status not in {"Partially Settled", "Settled"}:
        return "Missing", "settlement_evidence_not_ready"

    return "Matched", "matched"


def evidence_state(allocation) -> tuple[str, str]:
    """Return durable commission evidence state without creating accounting docs."""
    provenance = _text(getattr(allocation, "provenance", None)) or "Current OMC"
    if provenance == "Historical Legacy":
        return _historical_evidence_state(allocation)
    if provenance != "Current OMC":
        return "Review Required", "unsupported_commission_provenance"
    return _current_evidence_state(allocation)


def refresh_evidence(allocation) -> tuple[str, str]:
    state, code = evidence_state(allocation)
    frappe.db.set_value(
        "OMC Commission Allocation",
        allocation.name,
        "accounting_evidence_status",
        state,
        update_modified=False,
    )
    allocation.accounting_evidence_status = state

    safe_evidence = {
        "provenance": _text(getattr(allocation, "provenance", None)) or "Current OMC",
        "payment_entry": _text(getattr(allocation, "payment_entry", None)),
        "sales_invoice": _text(getattr(allocation, "sales_invoice", None)),
        "service_request": _text(getattr(allocation, "service_request", None)),
        "legacy_journal_entry": _text(getattr(allocation, "legacy_journal_entry", None)),
    }

    if state == "Review Required":
        reconciliation_queues.open_human_review(
            domain="Commission",
            source_doctype="OMC Commission Allocation",
            source_name=allocation.name,
            source_version=allocation.calculation_version,
            reason_code=code,
            safe_evidence=safe_evidence,
        )
    elif state in {"Missing", "Quarantined"}:
        reconciliation_queues.open_technical_quarantine(
            domain="Commission",
            source_doctype="OMC Commission Allocation",
            source_name=allocation.name,
            source_version=allocation.calculation_version,
            failure_code=code,
            safe_evidence=safe_evidence,
        )
    elif state == "Matched":
        reconciliation_queues.resolve_source_queues(
            domain="Commission",
            source_doctype="OMC Commission Allocation",
            source_name=allocation.name,
        )
    return state, code


def _require_matched_evidence(allocation) -> None:
    state, _code = refresh_evidence(allocation)
    if state != "Matched":
        frappe.throw(
            "Commission accounting evidence is not currently eligible for this action.",
            frappe.ValidationError,
        )


def _set_status(allocation, new_status: str, values: dict | None = None) -> dict:
    old_status = _text(allocation.status)
    payload = {"status": new_status, **(values or {})}
    frappe.db.set_value(
        "OMC Commission Allocation",
        allocation.name,
        payload,
        update_modified=False,
    )
    security.audit_event(
        event_type="commission.status_changed",
        capability=(
            "can_mark_commissions_paid"
            if new_status in {"Payable", "Paid"}
            else "can_approve_commissions"
        ),
        target_doctype="OMC Commission Allocation",
        target_name=allocation.name,
        old_state=old_status,
        new_state=new_status,
        source_version=allocation.calculation_version,
        safe_reason=_text((values or {}).get("rejection_reason"))[:500],
    )
    return {
        "allocation": allocation.name,
        "old_status": old_status,
        "status": new_status,
        "accounting_evidence_status": allocation.accounting_evidence_status,
    }


@frappe.whitelist(methods=["POST"])
def review_allocation(allocation=None, decision=None, reason=None):
    capabilities.require("can_approve_commissions")
    security.enforce_rate_limit("staff_mutation")
    doc = _locked_allocation(allocation)
    decision = _text(decision).lower()
    reason = _text(reason)

    if decision == "approve":
        if doc.status not in APPROVABLE:
            frappe.throw("Commission allocation is not reviewable for approval.", frappe.ValidationError)
        _require_matched_evidence(doc)
        return _set_status(
            doc,
            "Approved",
            {
                "approved_by": frappe.session.user,
                "approved_at": now_datetime(),
                "rejected_by": None,
                "rejected_at": None,
                "rejection_reason": None,
            },
        )

    if decision == "reject":
        if doc.status not in REJECTABLE:
            frappe.throw("Commission allocation is not reviewable for rejection.", frappe.ValidationError)
        if not reason:
            frappe.throw("A rejection reason is required.", frappe.ValidationError)
        return _set_status(
            doc,
            "Rejected",
            {
                "rejected_by": frappe.session.user,
                "rejected_at": now_datetime(),
                "rejection_reason": reason[:1000],
            },
        )

    frappe.throw("decision must be approve or reject.", frappe.ValidationError)


@frappe.whitelist(methods=["POST"])
def mark_payable(allocation=None):
    capabilities.require("can_mark_commissions_paid")
    security.enforce_rate_limit("staff_mutation")
    doc = _locked_allocation(allocation)
    if doc.status not in PAYABLE_FROM:
        frappe.throw("Only an approved commission can become payable.", frappe.ValidationError)
    _require_matched_evidence(doc)
    return _set_status(
        doc,
        "Payable",
        {
            "payable_marked_by": frappe.session.user,
            "payable_marked_at": now_datetime(),
        },
    )


@frappe.whitelist(methods=["POST"])
def mark_paid(allocation=None, settlement_reference=None, settled_on=None):
    capabilities.require("can_mark_commissions_paid")
    security.enforce_rate_limit("staff_mutation")
    doc = _locked_allocation(allocation)
    if doc.status not in PAID_FROM:
        frappe.throw("Only a payable commission can be marked paid.", frappe.ValidationError)
    reference = _text(settlement_reference)
    if not reference:
        frappe.throw(
            "An external settlement/accounting reference is required. OMC does not create Journal Entries automatically.",
            frappe.ValidationError,
        )
    _require_matched_evidence(doc)
    paid_date = getdate(settled_on) if settled_on else getdate(today())
    return _set_status(
        doc,
        "Paid",
        {
            "settlement_reference": reference[:140],
            "settled_by": frappe.session.user,
            "settled_on": paid_date,
        },
    )
