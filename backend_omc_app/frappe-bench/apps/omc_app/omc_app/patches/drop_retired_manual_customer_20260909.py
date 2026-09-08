from __future__ import annotations

import frappe


DOCTYPE = "OMC Manual Customer"
REQUEST_DOCTYPE = "OMC Service Request"
REQUEST_FIELD = "manual_customer"


def _request_reference_count() -> int:
    if not frappe.db.has_column(REQUEST_DOCTYPE, REQUEST_FIELD):
        return 0

    rows = frappe.db.sql(
        """
        select count(*)
        from `tabOMC Service Request`
        where coalesce(`manual_customer`, '') != ''
        """
    )
    return int(rows[0][0] if rows else 0)


def execute():
    """Drop the retired Manual Customer model only when no historical data remains.

    This intentionally fails closed. Any installation that still contains manual
    customers or request references must reconcile those records before the
    DocType can be removed.
    """
    if not frappe.db.exists("DocType", DOCTYPE):
        return

    records = int(frappe.db.count(DOCTYPE) or 0)
    references = _request_reference_count()

    if records or references:
        frappe.throw(
            (
                "Cannot retire OMC Manual Customer yet: "
                f"{records} record(s), {references} service-request reference(s). "
                "Reconcile historical data before running migrate again."
            ),
            frappe.ValidationError,
        )

    frappe.delete_doc(
        "DocType",
        DOCTYPE,
        ignore_permissions=True,
        force=True,
    )
