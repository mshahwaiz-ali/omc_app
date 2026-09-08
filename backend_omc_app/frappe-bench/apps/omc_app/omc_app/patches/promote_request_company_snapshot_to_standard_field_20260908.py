from __future__ import annotations

import frappe


DOCTYPE = "OMC Service Request"
FIELDNAME = "company_snapshot"


def execute():
    """Retire legacy Custom Field metadata before model sync.

    company_snapshot is now a standard source-controlled DocField. Older sites
    created the same database column through a Custom Field patch. Delete only
    that metadata row directly so the existing column and its values are
    preserved for the standard field during model synchronization.
    """
    if not frappe.db.table_exists("Custom Field"):
        return

    names = frappe.get_all(
        "Custom Field",
        filters={"dt": DOCTYPE, "fieldname": FIELDNAME},
        pluck="name",
    )
    for name in names:
        frappe.db.delete("Custom Field", {"name": name})

    if names:
        frappe.clear_cache(doctype=DOCTYPE)
