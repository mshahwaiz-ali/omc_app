from __future__ import annotations

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_fields


DOCTYPE = "OMC Service Request"
FIELDNAME = "company_snapshot"


def execute():
    """Ensure company authority exists without duplicating current source schema.

    Historical deployments introduced company_snapshot as a Custom Field.
    Current source defines it as a normal DocField. If model sync already
    exposes the field, this legacy patch must be a no-op. The Custom Field
    fallback remains only for unusual historical migration orderings where the
    field is genuinely absent.
    """
    if frappe.get_meta(DOCTYPE).has_field(FIELDNAME):
        return

    create_custom_fields(
        {
            DOCTYPE: [
                {
                    "fieldname": FIELDNAME,
                    "label": "Company Snapshot",
                    "fieldtype": "Link",
                    "options": "Company",
                    "insert_after": "pricing_currency",
                    "read_only": 1,
                    "search_index": 1,
                    "description": (
                        "Immutable legal company frozen from the OMC Service "
                        "when the request is created."
                    ),
                }
            ]
        },
        update=True,
    )
    frappe.clear_cache(doctype=DOCTYPE)
