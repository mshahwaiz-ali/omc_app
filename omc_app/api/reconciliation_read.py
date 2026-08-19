from __future__ import annotations

import frappe

from omc_app.api import capabilities, reconciliation_queues


QUEUE_TYPES = {
    "review": (
        "OMC Reconciliation Review",
        [
            "name",
            "domain",
            "source_doctype",
            "source_name",
            "source_version",
            "reason_code",
            "safe_evidence_json",
            "status",
            "run_id",
            "resolved_by",
            "resolved_at",
            "resolution_note",
            "creation",
        ],
    ),
    "quarantine": (
        "OMC Technical Quarantine",
        [
            "name",
            "domain",
            "source_doctype",
            "source_name",
            "source_version",
            "failure_code",
            "safe_evidence_json",
            "status",
            "attempt_count",
            "run_id",
            "first_seen_at",
            "last_seen_at",
            "resolved_by",
            "resolved_at",
            "resolution_note",
        ],
    ),
}


def _text(value) -> str:
    return str(value or "").strip()


def _pagination(limit_start=0, limit_page_length=20) -> tuple[int, int]:
    try:
        start = max(int(limit_start or 0), 0)
        length = min(max(int(limit_page_length or 20), 1), 100)
    except (TypeError, ValueError):
        frappe.throw("Invalid pagination values.", frappe.ValidationError)
    return start, length


def _require_domain(domain: str) -> str:
    domain = _text(domain)
    capability = reconciliation_queues.DOMAIN_CAPABILITY.get(domain)
    if not capability:
        frappe.throw("Unsupported reconciliation domain.", frappe.ValidationError)
    capabilities.require(capability)
    return domain


def _page(items: list, *, start: int, length: int) -> dict:
    has_more = len(items) > length
    visible = items[:length]
    return {
        "items": [dict(row) for row in visible],
        "limit_start": start,
        "limit_page_length": length,
        "next_start": start + len(visible) if has_more else None,
        "has_more": has_more,
    }


@frappe.whitelist()
def get_reconciliation_queue(
    domain=None,
    queue_type="review",
    status="Open",
    limit_start=0,
    limit_page_length=20,
):
    """Pure paginated read of one human-review or quarantine domain queue."""
    domain = _require_domain(domain)
    queue_type = _text(queue_type).lower()
    if queue_type not in QUEUE_TYPES:
        frappe.throw("queue_type must be review or quarantine.", frappe.ValidationError)
    start, length = _pagination(limit_start, limit_page_length)
    doctype, fields = QUEUE_TYPES[queue_type]
    filters = {"domain": domain}
    if _text(status):
        filters["status"] = _text(status)
    rows = frappe.get_all(
        doctype,
        filters=filters,
        fields=fields,
        order_by="modified desc, name desc",
        limit_start=start,
        limit_page_length=length + 1,
    )
    return {"queue_type": queue_type, "domain": domain, **_page(rows, start=start, length=length)}


@frappe.whitelist()
def get_reconciliation_runs(
    domain=None,
    status=None,
    limit_start=0,
    limit_page_length=20,
):
    """Pure paginated read of durable reconciliation execution history."""
    domain = _require_domain(domain)
    start, length = _pagination(limit_start, limit_page_length)
    filters = {"domain": domain}
    if _text(status):
        filters["status"] = _text(status)
    rows = frappe.get_all(
        "OMC Reconciliation Run",
        filters=filters,
        fields=[
            "run_id",
            "job_key",
            "domain",
            "status",
            "started_at",
            "completed_at",
            "cursor_start",
            "cursor_end",
            "batch_size",
            "scanned_count",
            "changed_count",
            "review_count",
            "quarantine_count",
            "failed_count",
            "cycle_completed",
            "safe_error_code",
        ],
        order_by="started_at desc, name desc",
        limit_start=start,
        limit_page_length=length + 1,
    )
    return {"domain": domain, **_page(rows, start=start, length=length)}
