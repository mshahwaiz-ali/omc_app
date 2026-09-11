from __future__ import annotations

import frappe

from omc_app.api import accounting_reconciliation, bridge_outbox


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
    result = accounting_reconciliation.reconcile_request(request_name)
    state = str(result.get("accounting_status") or "").strip()
    payment_names = frappe.get_all(
        "OMC Service Payment",
        filters={"service_request": request_name, "status": ["!=", "Cancelled"]},
        pluck="name",
        order_by="creation desc",
        limit_page_length=10,
    )
    for name in payment_names:
        current = str(frappe.db.get_value("OMC Service Payment", name, "status") or "").strip()
        values = {"accounting_status": state}
        if state == "Partially Settled":
            values.update({"status": "Partially Paid", "paid_on": None, "settled_at": None})
        elif state == "Settled":
            # reconcile_request already projects Paid; keep this explicit so
            # manual and automated ERP Payment Entries share one result.
            values.update({"status": "Paid"})
        elif current in {"Paid", "Partially Paid"}:
            values.update({"status": "Under Review", "paid_on": None, "settled_at": None})
        frappe.db.set_value(
            "OMC Service Payment",
            name,
            values,
            update_modified=False,
        )

    if state in {"Partially Settled", "Settled"}:
        bridge_outbox.enqueue_if_eligible(request_name)
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
