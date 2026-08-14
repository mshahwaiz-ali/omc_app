from __future__ import annotations

import frappe


TABLE = "tabOMC Service Request"


def _table_exists() -> bool:
    return bool(frappe.db.sql("show tables like %s", TABLE))


def _column_exists(column_name: str) -> bool:
    if not _table_exists():
        return False
    return column_name in [
        row[0] for row in frappe.db.sql(f"desc `{TABLE}`")
    ]


def execute() -> None:
    if not _column_exists("assigned_staff"):
        return
    if not _column_exists("assigned_to"):
        return

    frappe.db.sql(
        f"""
        update `{TABLE}`
        set assigned_staff = assigned_to
        where coalesce(assigned_staff, '') = ''
          and coalesce(assigned_to, '') != ''
        """
    )
