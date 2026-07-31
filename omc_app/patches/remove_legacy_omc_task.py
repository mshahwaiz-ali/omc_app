from __future__ import annotations

import frappe

LEGACY_DOCTYPE = "OMC Task"


def execute():
    if not frappe.db.exists("DocType", LEGACY_DOCTYPE):
        return

    record_count = frappe.db.count(LEGACY_DOCTYPE)
    open_todo_count = frappe.db.count(
        "ToDo",
        {
            "reference_type": LEGACY_DOCTYPE,
            "status": "Open",
        },
    )

    if record_count or open_todo_count:
        frappe.throw(
            "Cannot retire OMC Task: "
            f"{record_count} record(s) and "
            f"{open_todo_count} open ToDo assignment(s) remain."
        )

    frappe.delete_doc(
        "DocType",
        LEGACY_DOCTYPE,
        force=1,
        ignore_permissions=True,
    )
