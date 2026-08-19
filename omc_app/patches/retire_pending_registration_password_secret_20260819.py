from __future__ import annotations

import frappe
from frappe.utils.password import remove_encrypted_password


DOCTYPE = "OMC Pending Registration"
FIELDNAME = "password_secret"


def execute():
    """Purge reversible passwords retained by the retired registration flow."""
    if not frappe.db.exists("DocType", DOCTYPE):
        return

    for name in frappe.get_all(DOCTYPE, pluck="name", limit_page_length=0):
        remove_encrypted_password(DOCTYPE, name, FIELDNAME)
