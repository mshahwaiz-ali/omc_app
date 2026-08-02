"""Drop only the empty orphan table left by Frappe DocType retirement."""

import frappe

from omc_app.patches import remove_omc_hs_code_substitute as retirement


def execute():
    if frappe.db.exists("DocType", retirement.DOCTYPE):
        frappe.throw(
            "Refusing to drop tabHS Code while an HS Code DocType exists.",
            frappe.ValidationError,
        )
    if not frappe.db.table_exists(retirement.DOCTYPE):
        return

    record_count = frappe.db.sql("SELECT COUNT(*) FROM `tabHS Code`")[0][0]
    references = retirement._nonempty_references()
    if record_count or references:
        frappe.throw(
            "Refusing to drop tabHS Code because data exists. "
            f"Rows: {record_count}; non-empty references: {references}.",
            frappe.ValidationError,
        )

    frappe.db.sql_ddl("DROP TABLE `tabHS Code`")
