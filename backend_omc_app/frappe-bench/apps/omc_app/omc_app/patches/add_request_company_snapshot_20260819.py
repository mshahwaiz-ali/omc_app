from __future__ import annotations

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_fields


def execute():
    """Add company authority to requests without inventing historical values.

    Existing rows intentionally remain blank. Finance must reconcile those
    requests explicitly rather than deriving a company from ERP defaults or
    an arbitrary first invoice.
    """
    create_custom_fields(
        {
            "OMC Service Request": [
                {
                    "fieldname": "company_snapshot",
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
    frappe.clear_cache(doctype="OMC Service Request")
