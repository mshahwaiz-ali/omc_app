from __future__ import annotations

import hashlib

import frappe
from frappe.utils import cint

from omc_app.api import overlay_reconciliation
from omc_app.omc_app.doctype.omc_service.omc_service import pricing_version_for


def _text(value) -> str:
    return str(value or "").strip()


def _hash(value) -> str:
    return hashlib.sha256(_text(value).encode()).hexdigest()


def reconcile_overlay(domain="customer", mode="preview", run_id=None, cursor=0, limit=100):
    return overlay_reconciliation.run(
        domain=domain, mode=mode, run_id=run_id, cursor=cursor, limit=limit
    )


def commercial_policy(mode="preview", run_id=None, cursor=0, limit=100):
    mode = _text(mode).lower()
    if mode not in {"preview", "apply", "resume"}:
        frappe.throw("mode must be preview, apply, or resume.", frappe.ValidationError)
    effective_mode = "apply" if mode == "resume" else mode
    if mode == "resume" and not _text(run_id):
        frappe.throw("run_id is required when resuming.", frappe.ValidationError)
    run_id = _text(run_id) or frappe.generate_hash(length=20)
    start = max(cint(cursor), 0)
    page_length = min(max(cint(limit or 100), 1), 500)
    total = frappe.db.count("OMC Service")
    selected = frappe.get_all(
        "OMC Service",
        pluck="name",
        order_by="name asc",
        limit_start=start,
        limit_page_length=page_length,
    )
    items = []
    for name in selected:
        service = frappe.get_doc("OMC Service", name)
        values = {
            "service_version": max(cint(service.service_version or 1), 1),
            "tax_policy": service.tax_policy or "No Tax",
            "tax_rate": service.tax_rate or 0,
            "activation_policy": service.activation_policy or "Full Settlement",
            "pending_payment_expiry_hours": max(cint(service.pending_payment_expiry_hours or 72), 1),
            "duplicate_window_hours": max(cint(service.duplicate_window_hours or 24), 1),
        }
        service.update(values)
        values["pricing_version"] = pricing_version_for(service)
        checksum = _hash(frappe.as_json(values))
        if effective_mode == "apply":
            frappe.db.set_value("OMC Service", name, values, update_modified=False)
        items.append({"source_hash": _hash(name), "checksum": checksum, "action": "update"})
    return {
        "read_only": effective_mode == "preview",
        "mode": mode,
        "run_id": run_id,
        "cursor": start,
        "next_cursor": start + len(selected),
        "has_more": start + len(selected) < total,
        "total": total,
        "batch_checksum": _hash("|".join(item["checksum"] for item in items)),
        "items": items,
    }
