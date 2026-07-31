from __future__ import annotations

import frappe


FIELDNAME = "custom_gst_category"
DOCTYPES = ("Customer", "Supplier")


def execute() -> None:
    for doctype in DOCTYPES:
        frappe.db.delete(
            "Custom Field",
            {"dt": doctype, "fieldname": FIELDNAME},
        )

    frappe.clear_cache(doctype="Customer")
    frappe.clear_cache(doctype="Supplier")
