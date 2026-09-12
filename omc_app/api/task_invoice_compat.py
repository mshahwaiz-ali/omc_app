"""Compatibility guard for the client's legacy Task invoice actions.

ERPNext accounting remains authoritative for OMC requests. OMC-originated
Tasks therefore reuse the canonical Sales Invoice linked to the request and
must never originate a second invoice from Task.rate. Non-OMC Tasks delegate
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

    The flag is compatibility/UI state only. Once an OMC accounting link owns
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


def backfill_task_invoice_flags(limit: int = 500, dry_run: bool = True) -> dict:
    """Backfill legacy ``Task.invoiced`` from canonical OMC accounting links.

    Safe to run repeatedly. This function never creates, submits, repairs, or
    relinks accounting documents; it only projects an existing canonical OMC
    Sales Invoice into the legacy Task compatibility flag.
    """
    limit = min(max(int(limit or 500), 1), 5000)
    dry_run = bool(int(dry_run)) if isinstance(dry_run, (str, int)) else bool(dry_run)
    rows = frappe.get_all(
        REQUEST_DOCTYPE,
        filters={"erp_task": ["is", "set"]},
        fields=["name", "erp_task"],
        order_by="creation asc, name asc",
        limit_page_length=limit,
    )

    summary = {
        "dry_run": dry_run,
        "scanned": 0,
        "would_update": 0,
        "updated": 0,
        "already_projected": 0,
        "missing_task": 0,
        "missing_canonical_invoice": 0,
        "task_field_missing": 0,
        "samples": {
            "would_update": [],
            "updated": [],
            "missing_task": [],
            "missing_canonical_invoice": [],
        },
    }
    task_meta = frappe.get_meta("Task")
    has_invoiced = bool(task_meta.get_field("invoiced"))

    for row in rows:
        summary["scanned"] += 1
        request_name = _text(row.name)
        task_name = _text(row.erp_task)
        if not task_name or not frappe.db.exists("Task", task_name):
            summary["missing_task"] += 1
            if len(summary["samples"]["missing_task"]) < 25:
                summary["samples"]["missing_task"].append(
                    {"request": request_name, "task": task_name}
                )
            continue

        link = _base_invoice(request_name)
        invoice_name = _text(getattr(link, "sales_invoice", None)) if link else ""
        if not invoice_name:
            summary["missing_canonical_invoice"] += 1
            if len(summary["samples"]["missing_canonical_invoice"]) < 25:
                summary["samples"]["missing_canonical_invoice"].append(
                    {"request": request_name, "task": task_name}
                )
            continue

        if not has_invoiced:
            summary["task_field_missing"] += 1
            continue

        current = int(frappe.db.get_value("Task", task_name, "invoiced") or 0)
        if current == 1:
            summary["already_projected"] += 1
            continue

        if dry_run:
            summary["would_update"] += 1
            if len(summary["samples"]["would_update"]) < 25:
                summary["samples"]["would_update"].append(
                    {
                        "request": request_name,
                        "task": task_name,
                        "invoice": invoice_name,
                    }
                )
            continue

        result = project_task_invoice_flag(
            request_name=request_name,
            task_name=task_name,
        )
        if result.get("updated"):
            summary["updated"] += 1
            if len(summary["samples"]["updated"]) < 25:
                summary["samples"]["updated"].append(
                    {
                        "request": request_name,
                        "task": task_name,
                        "invoice": invoice_name,
                    }
                )
        else:
            summary["already_projected"] += 1

    return summary


def sync_task_status(doc, method=None):
    """Project invoice compatibility, then preserve the existing status sync."""
    task_name = _text(getattr(doc, "name", None))
    request_name = _request_for_task(task_name) if task_name else ""
    if request_name:
        project_task_invoice_flag(
            request_name=request_name,
            task_name=task_name,
        )

    from omc_app.api.erp_task_status_sync import sync_task_status as legacy_sync

    return legacy_sync(doc, method)


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
