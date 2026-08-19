from __future__ import annotations

import json

import frappe

from omc_app.api import capabilities, reconciliation_queues, security


REVIEW_DOCTYPE = "OMC Reconciliation Review"
ACCOUNTING_DOMAIN = "Accounting"
SUPPORTED_STATUSES = {"Open", "Resolved", "Ignored"}


def _text(value) -> str:
    return str(value or "").strip()


def _pagination(limit_start=0, limit_page_length=20) -> tuple[int, int]:
    try:
        start = max(int(limit_start or 0), 0)
        length = min(max(int(limit_page_length or 20), 1), 50)
    except (TypeError, ValueError):
        frappe.throw("Invalid pagination values.", frappe.ValidationError)
    return start, length


def _evidence(value) -> dict:
    if isinstance(value, dict):
        return dict(value)
    raw = _text(value)
    if not raw:
        return {}
    try:
        parsed = json.loads(raw)
    except (TypeError, ValueError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _reason_label(reason_code: str) -> str:
    clean = _text(reason_code).replace("_", " ").strip()
    return clean[:1].upper() + clean[1:] if clean else "Finance review required"


def _request_context(request_name: str) -> dict:
    request_name = _text(request_name)
    if not request_name or not frappe.db.exists("OMC Service Request", request_name):
        return {}
    values = frappe.db.get_value(
        "OMC Service Request",
        request_name,
        ["title", "customer_name", "service_title", "status", "request_state"],
        as_dict=True,
    )
    return dict(values or {})


def _review_item(row) -> dict:
    source_name = _text(row.get("source_name"))
    source_doctype = _text(row.get("source_doctype"))
    request_name = source_name if source_doctype == "OMC Service Request" else ""
    context = _request_context(request_name)
    status = _text(row.get("status")) or "Open"
    evidence = _evidence(row.get("safe_evidence_json"))

    return {
        "name": _text(row.get("name")),
        "status": status,
        "reason_code": _text(row.get("reason_code")),
        "reason_label": _reason_label(row.get("reason_code")),
        "service_request": request_name,
        "request_title": _text(context.get("title")),
        "customer_name": _text(context.get("customer_name")),
        "service_title": _text(context.get("service_title")),
        "service_status": _text(context.get("status")),
        "request_state": _text(context.get("request_state")),
        "source_doctype": source_doctype,
        "source_name": source_name,
        "evidence": evidence,
        "created_at": str(row.get("creation") or ""),
        "resolved_by": _text(row.get("resolved_by")),
        "resolved_at": str(row.get("resolved_at") or ""),
        "resolution_note": _text(row.get("resolution_note")),
        "allowed_actions": ["resolve", "ignore"] if status == "Open" else [],
    }


@frappe.whitelist()
def get_settlement_reviews(
    search=None,
    status="Open",
    limit_start=0,
    limit_page_length=20,
):
    """Return finance-human accounting exceptions only.

    Technical quarantine, scheduler internals, and raw ERP mutation surfaces are
    deliberately excluded from the mobile contract.
    """
    capabilities.require("can_reconcile_settlement")
    security.enforce_rate_limit("authenticated_list")
    start, length = _pagination(limit_start, limit_page_length)

    requested_status = _text(status) or "Open"
    if requested_status.lower() == "all":
        requested_status = ""
    elif requested_status not in SUPPORTED_STATUSES:
        frappe.throw("Select a supported reconciliation status.", frappe.ValidationError)

    filters = {"domain": ACCOUNTING_DOMAIN}
    if requested_status:
        filters["status"] = requested_status

    query = _text(search)
    or_filters = None
    if query:
        pattern = f"%{query}%"
        or_filters = {
            "source_name": ["like", pattern],
            "reason_code": ["like", pattern],
        }

    rows = frappe.get_all(
        REVIEW_DOCTYPE,
        filters=filters,
        or_filters=or_filters,
        fields=[
            "name",
            "source_doctype",
            "source_name",
            "reason_code",
            "safe_evidence_json",
            "status",
            "creation",
            "resolved_by",
            "resolved_at",
            "resolution_note",
        ],
        order_by="creation desc",
        limit_start=start,
        limit_page_length=length + 1,
    )
    has_more = len(rows) > length
    visible = rows[:length]
    items = [_review_item(row) for row in visible]
    return {
        "items": items,
        "limit_start": start,
        "limit_page_length": length,
        "has_more": has_more,
        "next_start": start + len(items) if has_more else None,
        "scope": ACCOUNTING_DOMAIN,
    }


@frappe.whitelist(methods=["POST"])
def decide_settlement_review(review=None, decision=None, note=None):
    """Classify a human accounting exception without mutating ERP accounting."""
    capabilities.require("can_reconcile_settlement")
    name = _text(review)
    requested_decision = _text(decision).lower()
    resolution_note = _text(note)

    if requested_decision not in {"resolve", "ignore"}:
        frappe.throw("decision must be resolve or ignore.", frappe.ValidationError)
    if not resolution_note:
        frappe.throw("A finance review note is required.", frappe.ValidationError)
    if not name or not frappe.db.exists(REVIEW_DOCTYPE, name):
        frappe.throw("Reconciliation review was not found.", frappe.DoesNotExistError)

    doc = frappe.get_doc(REVIEW_DOCTYPE, name)
    if _text(doc.domain) != ACCOUNTING_DOMAIN:
        frappe.throw(
            "This endpoint only handles accounting reconciliation reviews.",
            frappe.PermissionError,
        )

    result = reconciliation_queues.resolve_review(
        review=name,
        resolution="resolved" if requested_decision == "resolve" else "ignored",
        note=resolution_note,
    )
    return {
        **dict(result or {}),
        "decision": requested_decision,
        "note_recorded": True,
    }
