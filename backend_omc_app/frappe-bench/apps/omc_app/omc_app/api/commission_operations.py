"""Finance-safe mobile reads for commission lifecycle operations.

Beneficiary reads remain isolated in referral_commissions.py. This module exposes
allocation queues only to staff who hold commission mutation authority, and it
returns business-safe evidence/status fields without exposing raw accounting or
reconciliation internals.
"""

from __future__ import annotations

from typing import Any

import frappe

from omc_app.api import capabilities, commission_lifecycle, security


DOCTYPE = "OMC Commission Allocation"
DEFAULT_LIMIT = 20
MAX_LIMIT = 100
STATUSES = {
    "Calculated", "Held", "Approved", "Payable", "Paid", "Rejected", "Reversed",
}
EVIDENCE_STATES = {
    "Unverified", "Matched", "Missing", "Review Required", "Quarantined", "Reversed",
}


def _text(value: Any) -> str:
    return str(value or "").strip()


def _page(value: Any, *, default: int, minimum: int, maximum: int) -> int:
    try:
        return max(minimum, min(int(value), maximum))
    except (TypeError, ValueError):
        return default


def _finance_capabilities() -> dict[str, Any]:
    values = capabilities.effective()
    if not (values.get("can_approve_commissions") or values.get("can_mark_commissions_paid")):
        frappe.throw(
            "You do not have permission to manage commission allocations.",
            frappe.PermissionError,
        )
    return values


def _validated_status(value: Any) -> str:
    status = _text(value).title()
    if status and status not in STATUSES:
        frappe.throw("Unsupported commission status.", frappe.ValidationError)
    return status


def _validated_evidence(value: Any) -> str:
    evidence = _text(value)
    if not evidence:
        return ""
    normalized = next((item for item in EVIDENCE_STATES if item.lower() == evidence.lower()), "")
    if not normalized:
        frappe.throw("Unsupported accounting evidence status.", frappe.ValidationError)
    return normalized


def _allowed_actions(status: str, evidence_status: str, values: dict[str, Any]) -> list[str]:
    actions: list[str] = []
    can_approve = bool(values.get("can_approve_commissions"))
    can_pay = bool(values.get("can_mark_commissions_paid"))
    matched = evidence_status == "Matched"

    if can_approve and status in commission_lifecycle.APPROVABLE and matched:
        actions.append("approve")
    if can_approve and status in commission_lifecycle.REJECTABLE:
        actions.append("reject")
    if can_pay and status in commission_lifecycle.PAYABLE_FROM and matched:
        actions.append("mark_payable")
    if can_pay and status in commission_lifecycle.PAID_FROM and matched:
        actions.append("mark_paid")
    return actions


def _request_map(request_names: set[str]) -> dict[str, dict[str, Any]]:
    if not request_names:
        return {}
    rows = frappe.get_all(
        "OMC Service Request",
        filters={"name": ["in", sorted(request_names)]},
        fields=["name", "customer_profile", "customer_name", "service", "service_title"],
        limit_page_length=max(len(request_names), 1),
    )
    return {row.name: dict(row) for row in rows}


def _payload(row, *, request: dict[str, Any] | None, values: dict[str, Any], evidence_status: str | None = None) -> dict[str, Any]:
    request = request or {}
    evidence = _text(
        evidence_status if evidence_status is not None else getattr(row, "accounting_evidence_status", None)
    ) or "Unverified"
    status = _text(getattr(row, "status", None)) or "Calculated"
    beneficiary_user = _text(getattr(row, "beneficiary_user", None))
    beneficiary = _text(getattr(row, "beneficiary", None)) or beneficiary_user
    provenance = _text(getattr(row, "provenance", None)) or "Current OMC"

    return {
        "id": row.name,
        "status": status,
        "provenance": provenance,
        "origin": provenance,
        "accounting_evidence_status": evidence,
        "allowed_actions": _allowed_actions(status, evidence, values),
        "beneficiary": beneficiary,
        "beneficiary_user": beneficiary_user,
        "beneficiary_type": _text(getattr(row, "beneficiary_type", None)),
        "source_persona": _text(getattr(row, "source_persona_snapshot", None)),
        "component": _text(getattr(row, "component", None)),
        "service_request": _text(getattr(row, "service_request", None)),
        "payment_entry": _text(getattr(row, "payment_entry", None)),
        "sales_invoice": _text(getattr(row, "sales_invoice", None)),
        "legacy_journal_entry": _text(getattr(row, "legacy_journal_entry", None)),
        "structure_snapshot": _text(getattr(row, "structure_snapshot", None)),
        "customer_profile": _text(request.get("customer_profile")),
        "customer_name": _text(request.get("customer_name")) or _text(getattr(row, "erp_customer", None)),
        "service": _text(request.get("service")),
        "service_title": _text(request.get("service_title")) or _text(request.get("service")),
        "currency": _text(getattr(row, "currency", None)) or "PKR",
        "basis_amount": getattr(row, "basis_amount", 0) or 0,
        "commission_percent": getattr(row, "commission_percent_snapshot", 0) or 0,
        "commission_amount": getattr(row, "commission_amount", 0) or 0,
        "earned_on": str(getattr(row, "earned_on", None) or ""),
        "approved_by": _text(getattr(row, "approved_by", None)),
        "approved_at": str(getattr(row, "approved_at", None) or ""),
        "payable_marked_by": _text(getattr(row, "payable_marked_by", None)),
        "payable_marked_at": str(getattr(row, "payable_marked_at", None) or ""),
        "rejected_by": _text(getattr(row, "rejected_by", None)),
        "rejected_at": str(getattr(row, "rejected_at", None) or ""),
        "rejection_reason": _text(getattr(row, "rejection_reason", None)),
        "settlement_reference": _text(getattr(row, "settlement_reference", None)),
        "settled_by": _text(getattr(row, "settled_by", None)),
        "settled_on": str(getattr(row, "settled_on", None) or ""),
        "reversal_reason": _text(getattr(row, "reversal_reason", None)),
        "reversed_on": str(getattr(row, "reversed_on", None) or ""),
    }


def _filters(status: str, evidence: str) -> dict[str, Any]:
    result: dict[str, Any] = {}
    if status:
        result["status"] = status
    if evidence:
        result["accounting_evidence_status"] = evidence
    return result


def _or_filters(search: str) -> dict[str, Any] | None:
    query = _text(search)
    if not query:
        return None
    pattern = f"%{query}%"
    return {
        "name": ["like", pattern], "beneficiary": ["like", pattern],
        "beneficiary_user": ["like", pattern], "service_request": ["like", pattern],
        "erp_customer": ["like", pattern], "component": ["like", pattern],
    }


@frappe.whitelist()
def get_commission_allocations(status=None, evidence_status=None, search=None, limit_start=0, limit_page_length=DEFAULT_LIMIT):
    values = _finance_capabilities()
    security.enforce_rate_limit("authenticated_list")
    start = _page(limit_start, default=0, minimum=0, maximum=100000)
    limit = _page(limit_page_length, default=DEFAULT_LIMIT, minimum=1, maximum=MAX_LIMIT)
    clean_status = _validated_status(status)
    clean_evidence = _validated_evidence(evidence_status)

    rows = frappe.get_all(
        DOCTYPE,
        filters=_filters(clean_status, clean_evidence),
        or_filters=_or_filters(search),
        fields=[
            "name", "provenance", "status", "accounting_evidence_status",
            "beneficiary", "beneficiary_user", "beneficiary_type",
            "source_persona_snapshot", "component", "service_request",
            "payment_entry", "sales_invoice", "legacy_journal_entry",
            "structure_snapshot", "erp_customer", "currency", "basis_amount",
            "commission_percent_snapshot", "commission_amount", "earned_on",
            "approved_by", "approved_at", "payable_marked_by", "payable_marked_at",
            "rejected_by", "rejected_at", "rejection_reason", "settlement_reference",
            "settled_by", "settled_on", "reversal_reason", "reversed_on",
        ],
        order_by="earned_on desc, name desc",
        limit_start=start,
        limit_page_length=limit + 1,
    )
    has_more = len(rows) > limit
    page_rows = rows[:limit]
    requests = _request_map({_text(row.service_request) for row in page_rows if _text(row.service_request)})

    return {
        "items": [
            _payload(row, request=requests.get(_text(row.service_request)), values=values)
            for row in page_rows
        ],
        "limit_start": start,
        "limit_page_length": limit,
        "has_more": has_more,
        "next_start": start + limit if has_more else None,
    }


@frappe.whitelist()
def get_commission_allocation(allocation=None, name=None):
    values = _finance_capabilities()
    security.enforce_rate_limit("authenticated_list")
    allocation_name = _text(allocation or name)
    if not allocation_name or not frappe.db.exists(DOCTYPE, allocation_name):
        frappe.throw("Commission allocation was not found.", frappe.DoesNotExistError)

    row = frappe.get_doc(DOCTYPE, allocation_name)
    request_name = _text(row.service_request)
    requests = _request_map({request_name} if request_name else set())
    evidence, _reason_code = commission_lifecycle.evidence_state(row)
    return _payload(
        row,
        request=requests.get(request_name),
        values=values,
        evidence_status=evidence,
    )
