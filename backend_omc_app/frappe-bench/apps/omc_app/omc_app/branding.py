from __future__ import annotations

import frappe


DEFAULT_FULL_LOGO = "/assets/omc_app/images/full_logo_transparent.png"
DEFAULT_SYMBOL_LOGO = "/assets/omc_app/images/logo_symbol_transparent.png"
DEFAULT_BRAND_NAME = "OMC House"
BACKEND_APP_NAME = "OMC App Backend"


def _get_branding_settings():
    if not frappe.db.exists("DocType", "OMC Branding Settings"):
        return None
    return frappe.get_single("OMC Branding Settings")


def _value(doc, fieldname: str, default: str) -> str:
    value = getattr(doc, fieldname, None) if doc else None
    return value or default


@frappe.whitelist()
def apply_branding():
    """Apply O