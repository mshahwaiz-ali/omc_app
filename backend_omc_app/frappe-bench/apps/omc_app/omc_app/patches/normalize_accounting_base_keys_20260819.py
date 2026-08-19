from __future__ import annotations

import frappe


TABLE = "tabOMC Accounting Link"


def _column_exists(column: str) -> bool:
    if not frappe.db.table_exists("OMC Accounting Link"):
        return False
    return bool(frappe.db.has_column("OMC Accounting Link", column))


def execute():
    """Keep nullable uniqueness keys safe before DocType unique indexes sync."""
    for column in ("base_invoice_key", "base_request_key"):
        if not _column_exists(column):
            continue
        frappe.db.sql(
            f"UPDATE `{TABLE}` SET `{column}` = NULL WHERE `{column}` = ''"
        )
