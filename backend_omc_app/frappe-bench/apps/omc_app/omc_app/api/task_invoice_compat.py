"""Compatibility guard for the client's legacy Task invoice actions.

ERPNext accounting remains authoritative for OMC requests.  OMC-originated
Tasks therefore reuse the canonical Sales Invoice linked to the request and
must never originate a second invoice from Task.rate.  Non-OMC Tasks delegate
to the client's existing ERPNext implementation unchanged.
"""
from __future__ import annotations

import json

import frappe


REQUEST_DOCTYPE = "OMC Service Request"
LINK_DOCTYPE = "OMC Accounting Link"


def _text(value) -> str:
    return str(value or "").strip()


def _request_for_task(task_name: str) -> str:
    """Return the unique OMC request that owns an ERP Task, if any."""
    name = _text(task_name)
    if not name:
        return ""
    rows = frappe.get_all(
        REQUEST_DOCTYPE,
        filters={"erp_task": name},
        pluck="name",
        order_by="creation asc, name asc",
        limit_page_length=2,
    )
    if len(rows) > 1:
        frappe.throw(
            f"ERP Task {name} is linked to multiple OMC service requests. "
            "Repair the OMC task linkage before invoicing.",
            frappe.ValidationError,
        )
    return _text(rows[0]) if rows else ""


def _base_invoice(request_name: str):
    return frappe.db.get_value(
        LINK_DOCTYPE,
        {"base_request_key": request_name},
        ["name", "sales_invoice", "accounting_status"],
        as_dict=True,
    )


def project_task_invoice_flag(*, request_name: str = "", task_name: str = "") -> dict:
    """Project canonical OMC invoicing into legacy ``Task.invoiced``.

    The flag is compatibility/UI state only.  Once an OMC accounting link owns
    a canonical invoice, the legacy Task must remain marked invoiced even if
    that invoice is later cancelled; finance reconciliation, not Task, owns
    repair of the accounting source.
    """
    request_name = _text(request_name)
    task_name = _text(task_name)
    if not request_name and task_name:
        request_name = _request_for_task(task_name)
    if request_name and not task_name:
        task_name = _text(
            frappe.db.get_value(REQUEST_DOCTYPE, request_name, "erp_task")
        )
    if not request_name or not task_name or not frappe.db.exists("Task", task_name):
        return {
            "updated": False,
            "request": request_name,
            "task": task_name,
            "invoice": "",
        }

    link = _base_invoice(request_name)
    invoice_name = _text(getattr(link, "sales_invoice", None)) if link else ""
    if not invoice_name:
        return {
            "updated": False,
            "request": request_name,
            "task": task_name,
            "invoice": "",
        }

    meta = frappe.get_meta("Task")
    if not meta.get_field("invoiced"):
        return {
            "updated": False,
            "request": request_name,
            "task": task_name,
            "invoice": invoice_name,
        }

    current = int(frappe.db.get_value("Task", task_name, "invoiced") or 0)
    if current != 1:
        frappe.db.set_value(
            "Task",
            task_name,
            "invoiced",
            1,
            update_modified=False,
        )
    return {
        "updated": current != 1,
        "request": request_name,
        "task": task_name,
        "invoice": invoice_name,
    }


def _canonical_invoice_or_throw(task_name: str, request_name: str) -> str:
    projection = project_task_invoice_flag(
        request_name=request_name,
        task_name=task_name,
    )
    invoice_name = _text(projection.get("invoice"))
    if not invoice_name:
        frappe.throw(
            "This OMC Task is payment-first and cannot generate an invoice. "
            "No canonical OMC Sales Invoice is linked; finance reconciliation "
            "must repair the request first.",
            frappe.ValidationError,
        )
    if not frappe.db.exists("Sales Invoice", invoice_name):
        frappe.throw(
            f"Canonical OMC Sales Invoice {invoice_name} is missing. "
            "Finance reconciliation must repair the accounting source before "
            "this Task can continue.",
            frappe.ValidationError,
        )
    docstatus = int(
        frappe.db.get_value("Sales Invoice", invoice_name, "docstatus") or 0
    )
    if docstatus != 1:
        frappe.throw(
            f"Canonical OMC Sales Invoice {invoice_name} is not submitted. "
            "A second invoice cannot be generated from the Task; finance must "
            "repair the canonical accounting source.",
            frappe.ValidationError,
        )
    return invoice_name


@frappe.whitelist()
def mk_inv(doc):
    """Guard OMC Tasks while preserving the legacy behavior for all others."""
    task_name = _text(doc)
    request_name = _request_for_task(task_name)
    if not request_name:
        from erpnext.projects.doctype.task.task import mk_inv as legacy_mk_inv

        return legacy_mk_inv(task_name)
    return _canonical_invoice_or_throw(task_name, request_name)


@frappe.whitelist()
def bulk_generate_invoices(tasks):
    """Reuse canonical OMC invoices and delegate non-OMC Tasks unchanged."""
    names = frappe.parse_json(tasks)
    if not isinstance(names, list):
        frappe.throw("tasks must be a list of Task names.", frappe.ValidationError)

    generated = []
    legacy_names = []
    for raw_name in names:
        task_name = _text(raw_name)
        if not task_name:
            continue
        request_name = _request_for_task(task_name)
        if not request_name:
            legacy_names.append(task_name)
            continue

        invoice_name = _canonical_invoice_or_throw(task_name, request_name)
        if _text(frappe.db.get_value("Task", task_name, "status")) == "Completed":
            generated.append(invoice_name)

    if legacy_names:
        from erpnext.projects.doctype.task.task import (
            bulk_generate_invoices as legacy_bulk_generate_invoices,
        )

        generated.extend(
            legacy_bulk_generate_invoices(json.dumps(legacy_names)) or []
        )
    return generated
