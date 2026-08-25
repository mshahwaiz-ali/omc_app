"""Explicit, evidence-driven migration of legacy commission liabilities.

This module reads existing ERP accounting evidence but never mutates ERPNext.
Safe legacy liabilities are projected into the canonical OMC Commission
Allocation ledger. Ambiguous/unmatched accounting is routed to the existing
OMC Reconciliation Review queue under the Commission domain.
"""

from __future__ import annotations

import hashlib
from collections import Counter
from decimal import Decimal, ROUND_HALF_UP

import frappe

from omc_app.api import reconciliation_queues


PROVENANCE = "Historical Legacy"
CALCULATION_VERSION = "historical-legacy-commission-v1"
COMMISSION_ACCOUNT = "Commission Payable - O"
HOUSE_SALES_PERSON = "omc@omchouse.com"
COMPONENT = "Sales Person"


def _text(value) -> str:
    return str(value or "").strip()


def _money(value) -> Decimal:
    return Decimal(str(value or 0)).quantize(
        Decimal("0.01"),
        rounding=ROUND_HALF_UP,
    )


def _key(*values) -> str:
    return hashlib.sha256(
        "|".join(_text(value) for value in values).encode("utf-8")
    ).hexdigest()


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
    candidates = set()
    for fieldname in ("user_link", "user_id", "user"):
        if not meta.get_field(fieldname):
            continue
        user = _text(frappe.db.get_value(beneficiary_type, beneficiary, fieldname))
        if user and frappe.db.exists("User", user):
            candidates.add(user)
    if len(candidates) != 1:
        return ""

    user = next(iter(candidates))
    enabled, user_type = frappe.db.get_value(
        "User", user, ["enabled", "user_type"]
    ) or (0, "")
    if not int(enabled or 0) or _text(user_type) != "System User":
        return ""
    return user


def _commission_rows():
    if not frappe.db.exists("DocType", "Journal Entry"):
        return []
    return frappe.get_all(
        "Journal Entry Account",
        filters={"account": COMMISSION_ACCOUNT},
        fields=[
            "name",
            "parent",
            "party_type",
            "party",
            "credit_in_account_currency",
            "reference_type",
            "reference_name",
        ],
        order_by="parent asc, idx asc",
        limit_page_length=0,
    )


def _journal_states(parents):
    names = sorted({_text(value) for value in parents if _text(value)})
    if not names:
        return {}
    rows = frappe.get_all(
        "Journal Entry",
        filters={"name": ["in", names]},
        fields=["name", "docstatus", "posting_date", "company", "remark", "user_remark"],
        limit_page_length=0,
    )
    return {row.name: row for row in rows}


def _payment_fields():
    candidates = [
        "name",
        "docstatus",
        "posting_date",
        "party_type",
        "party",
        "paid_amount",
        "custom_structure_name",
        "custom_source",
        "custom_sales_person",
        "custom_sales_person_percentage",
        "custom_sales_person_amount",
        "custom_omc_customer",
    ]
    meta = frappe.get_meta("Payment Entry")
    fields = []
    for fieldname in candidates:
        if fieldname in {"name", "docstatus", "posting_date", "party_type", "party", "paid_amount"}:
            fields.append(fieldname)
        elif meta.get_field(fieldname) or frappe.db.has_column("Payment Entry", fieldname):
            fields.append(fieldname)
    return fields


def _payments(names):
    names = sorted({_text(value) for value in names if _text(value)})
    if not names:
        return {}
    rows = frappe.get_all(
        "Payment Entry",
        filters={"name": ["in", names]},
        fields=_payment_fields(),
        limit_page_length=0,
    )
    return {row.name: row for row in rows}


def _is_house_direct(payment) -> bool:
    if int(payment.get("custom_omc_customer") or 0):
        return True
    customer = _text(payment.get("party"))
    if _text(payment.get("party_type")) == "Customer" and customer and frappe.db.exists("Customer", customer):
        sales_person = _text(frappe.db.get_value("Customer", customer, "sales_person")).lower()
        return sales_person == HOUSE_SALES_PERSON
    return False


def _classify():
    rows = _commission_rows()
    journals = _journal_states(row.parent for row in rows)
    referenced_payments = {
        _text(row.reference_name)
        for row in rows
        if _text(row.reference_type) == "Payment Entry" and _text(row.reference_name)
    }
    payments = _payments(referenced_payments)

    exact_matches_by_payment = {}
    row_decisions = []

    for row in rows:
        journal = journals.get(_text(row.parent))
        reason = ""
        payment = None
        beneficiary_user = ""

        if not journal or int(journal.docstatus or 0) != 1:
            reason = "legacy_journal_not_submitted"
        elif _text(row.reference_type) != "Payment Entry" or not _text(row.reference_name):
            reason = "legacy_durable_payment_reference_missing"
        else:
            payment = payments.get(_text(row.reference_name))
            if not payment:
                reason = "legacy_payment_entry_missing"
            elif int(payment.docstatus or 0) != 1:
                reason = "legacy_payment_entry_not_submitted"
            elif _is_house_direct(payment):
                reason = "legacy_house_direct_suppressed"
            elif _text(payment.get("party_type")) != "Customer" or not _text(payment.get("party")):
                reason = "legacy_payment_customer_missing"
            elif not frappe.db.exists("Customer", _text(payment.get("party"))):
                reason = "legacy_erp_customer_missing"
            elif not _text(payment.get("custom_structure_name")):
                reason = "legacy_structure_snapshot_missing"
            elif not _text(payment.get("custom_source")) or not _text(payment.get("custom_sales_person")):
                reason = "legacy_beneficiary_snapshot_missing"
            elif _money(payment.get("custom_sales_person_amount")) <= 0:
                reason = "legacy_commission_amount_not_positive"
            elif _money(row.credit_in_account_currency) != _money(payment.get("custom_sales_person_amount")):
                reason = "legacy_je_amount_mismatch"
            elif _text(row.party_type) != _text(payment.get("custom_source")):
                reason = "legacy_je_party_type_mismatch"
            elif _text(row.party) != _text(payment.get("custom_sales_person")):
                reason = "legacy_je_beneficiary_mismatch"
            elif _money(payment.get("paid_amount")) <= 0:
                reason = "legacy_paid_amount_not_positive"
            else:
                expected_amount = (
                    _money(payment.get("paid_amount"))
                    * Decimal(str(payment.get("custom_sales_person_percentage") or 0))
                    / Decimal("100")
                ).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
                if expected_amount != _money(payment.get("custom_sales_person_amount")):
                    reason = "legacy_paid_amount_formula_mismatch"
                else:
                    beneficiary_user = _beneficiary_user(
                        _text(payment.get("custom_source")),
                        _text(payment.get("custom_sales_person")),
                    )
                    if not beneficiary_user:
                        reason = "legacy_beneficiary_user_unresolved"

        decision = {
            "action": "review" if reason else "allocate",
            "reason": reason,
            "journal_entry": _text(row.parent),
            "journal_row": _text(row.name),
            "payment_entry": _text(row.reference_name) if _text(row.reference_type) == "Payment Entry" else "",
            "payment": payment,
            "beneficiary_user": beneficiary_user,
        }
        row_decisions.append(decision)
        if not reason and payment:
            exact_matches_by_payment.setdefault(payment.name, []).append(decision)

    # One frozen Payment Entry must map to exactly one safe legacy liability.
    # Duplicate matching JE rows are review-only rather than guessed/deduped.
    for payment_name, decisions in exact_matches_by_payment.items():
        if len(decisions) == 1:
            continue
        for decision in decisions:
            decision["action"] = "review"
            decision["reason"] = "legacy_multiple_exact_commission_rows"

    return row_decisions


def _allocation_values(decision):
    payment = decision["payment"]
    allocation_key = _key(
        CALCULATION_VERSION,
        decision["payment_entry"],
        decision["journal_entry"],
        COMPONENT,
        payment.get("custom_source"),
        payment.get("custom_sales_person"),
    )
    return {
        "doctype": "OMC Commission Allocation",
        "allocation_key": allocation_key,
        "provenance": PROVENANCE,
        "payment_entry": decision["payment_entry"],
        "payment_reference_row": None,
        "sales_invoice": None,
        "service_request": None,
        "erp_customer": _text(payment.get("party")),
        "legacy_journal_entry": decision["journal_entry"],
        "referral_attribution": None,
        "component": COMPONENT,
        "beneficiary_type": _text(payment.get("custom_source")),
        "beneficiary": _text(payment.get("custom_sales_person")),
        "beneficiary_user": decision["beneficiary_user"],
        "source_persona_snapshot": _text(payment.get("custom_source")),
        "currency": "PKR",
        "exchange_rate": 1,
        "basis_amount": float(_money(payment.get("paid_amount"))),
        "commission_percent_snapshot": float(payment.get("custom_sales_person_percentage") or 0),
        "commission_amount": float(_money(payment.get("custom_sales_person_amount"))),
        "structure_snapshot": _text(payment.get("custom_structure_name")),
        "calculation_version": CALCULATION_VERSION,
        "status": "Payable",
        "earned_on": payment.get("posting_date"),
        "accounting_evidence_status": "Matched",
    }


def preflight():
    """Read-only historical commission classification."""
    decisions = _classify()
    safe = [decision for decision in decisions if decision["action"] == "allocate"]
    review = [decision for decision in decisions if decision["action"] != "allocate"]
    reasons = Counter(decision["reason"] or "unknown" for decision in review)
    total = sum(
        (_money(decision["payment"].get("custom_sales_person_amount")) for decision in safe),
        Decimal("0.00"),
    )
    return {
        "read_only": True,
        "provenance": PROVENANCE,
        "calculation_version": CALCULATION_VERSION,
        "safe_allocations": len(safe),
        "review_required": len(review),
        "safe_liability_total": float(total),
        "review_reason_counts": dict(sorted(reasons.items())),
        "safe_samples": [
            {
                "payment_entry": decision["payment_entry"],
                "journal_entry": decision["journal_entry"],
                "beneficiary_user": decision["beneficiary_user"],
                "amount": float(_money(decision["payment"].get("custom_sales_person_amount"))),
            }
            for decision in safe[:20]
        ],
        "review_samples": [
            {
                "journal_entry": decision["journal_entry"],
                "payment_entry": decision["payment_entry"],
                "reason": decision["reason"],
            }
            for decision in review[:20]
        ],
    }


def apply(*, commit=False):
    """Idempotently project safe legacy liabilities and queue ambiguity."""
    decisions = _classify()
    result = {
        "provenance": PROVENANCE,
        "created": 0,
        "existing": 0,
        "review_queued": 0,
        "review_reason_counts": Counter(),
        "changed": False,
    }

    for decision in decisions:
        if decision["action"] == "allocate":
            values = _allocation_values(decision)
            if frappe.db.exists(
                "OMC Commission Allocation",
                {"allocation_key": values["allocation_key"]},
            ):
                result["existing"] += 1
                continue
            doc = frappe.get_doc(values)
            doc.insert(ignore_permissions=True)
            result["created"] += 1
            result["changed"] = True
            continue

        reason = _text(decision.get("reason")) or "legacy_commission_review_required"
        source_name = decision["journal_entry"] or decision["journal_row"]
        source_version = _key(
            CALCULATION_VERSION,
            decision["journal_entry"],
            decision["journal_row"],
            decision["payment_entry"],
            reason,
        )
        reconciliation_queues.open_human_review(
            domain="Commission",
            source_doctype="Journal Entry",
            source_name=source_name,
            source_version=source_version,
            reason_code=reason,
            safe_evidence={
                "journal_entry": decision["journal_entry"],
                "payment_entry": decision["payment_entry"],
                "journal_row": decision["journal_row"],
            },
        )
        result["review_queued"] += 1
        result["review_reason_counts"][reason] += 1
        result["changed"] = True

    result["review_reason_counts"] = dict(
        sorted(result["review_reason_counts"].items())
    )
    if commit and result["changed"]:
        frappe.db.commit()
    return result
