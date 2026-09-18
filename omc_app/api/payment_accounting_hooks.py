from __future__ import annotations

import frappe

from omc_app.api import (
    accounting_reconciliation,
    bridge_outbox,
    completion_recheck,
)


def _request_names(payment_entry) -> set[str]:
    names: set[str] = set()
    for row in payment_entry.references or []:
        if row.reference_doctype != "Sales Invoice" or not row.reference_name:
            continue
        names.update(
            frappe.get_all(
                "OMC Accounting Link",
                filters={"sales_invoice": row.reference_name},
                pluck="service_request",
                limit_page_length=100,
            )
        )
    return {name for name in names if name}


def project_request_payment_state(request_name: str) -> dict:
    """Refresh aggregate request accounting without overwriting installments."""
    result = accounting_reconciliation.reconcile_request(request_name)
    state = str(result.get("accounting_status") or "").strip()

    # accounting_reconciliation.reconcile_request is the canonical owner of
    # activation enqueueing. Keeping that ownership there ensures Payment
    # Entry hooks, explicit reconciliation, and scheduled recovery all use the
    # same durable path without submitting duplicate bridge jobs.
    if state == "Settled":
        completion_recheck.recheck_completed_task(request_name)
    return result


def _post_reconciliation_orchestration(request_name: str) -> None:
    """Run orchestration that must happen after accounting is already refreshed."""
    state = str(
        bridge_outbox._accounting_status(request_name) or ""
    ).strip()
    if state == "Settled":
        completion_recheck.recheck_completed_task(request_name)


def payment_entry_submitted(doc, method=None):
    request_names = _request_names(doc)
    accounting_reconciliation.payment_entry_submitted(doc, method)
    for request_name in sorted(request_names):
        _post_reconciliation_orchestration(request_name)


def payment_entry_cancelled(doc, method=None):
    request_names = _request_names(doc)
    accounting_reconciliation.payment_entry_cancelled(doc, method)
    for request_name in sorted(request_names):
        _post_reconciliation_orchestration(request_name)
