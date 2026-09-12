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

    # Installment rows are projected by accounting_reconciliation from their
    # own linked Payment Entry. The request-level state below is only used for
    # activation/completion orchestration.
    if state in {"Partially Settled", "Settled"}:
        bridge_outbox.enqueue_if_eligible(request_name)
    if state == "Settled":
        completion_recheck.recheck_completed_task(request_name)
    return result


def payment_entry_submitted(doc, method=None):
    accounting_reconciliation.payment_entry_submitted(doc, method)
    for request_name in sorted(_request_names(doc)):
        project_request_payment_state(request_name)


def payment_entry_cancelled(doc, method=None):
    request_names = _request_names(doc)
    accounting_reconciliation.payment_entry_cancelled(doc, method)
    for request_name in sorted(request_names):
        project_request_payment_state(request_name)
