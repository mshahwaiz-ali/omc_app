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
    """Apply OMC branding to safe Frappe Website Settings fields."""
    doc = _get_branding_settings()
    if doc and not getattr(doc, "enabled", 1):
        return {"ok": False, "message": "OMC branding is disabled."}

    full_logo = _value(doc, "full_logo", DEFAULT_FULL_LOGO)
    logo_symbol = _value(doc, "logo_symbol", DEFAULT_SYMBOL_LOGO)
    login_logo = _value(doc, "login_logo", full_logo)
    favicon = _value(doc, "favicon", logo_symbol)

    website_settings = frappe.get_single("Website Settings")
    website_settings.app_name = BACKEND_APP_NAME
    website_settings.app_logo = login_logo
    website_settings.banner_image = logo_symbol
    website_settings.splash_image = logo_symbol
    website_settings.footer_logo = full_logo
    website_settings.favicon = favicon
    website_settings.brand_html = (
        f'<img src="{logo_symbol}" alt="{BACKEND_APP_NAME}" '
        'style="height:32px; width:auto; object-fit:contain;" />'
    )
    website_settings.save(ignore_permissions=True)

    if doc:
        doc.last_applied_on = frappe.utils.now_datetime()
        doc.last_apply_status = (
            f"Applied backend brand '{BACKEND_APP_NAME}' with login logo "
            f"{login_logo} and favicon {favicon}."
        )
        doc.save(ignore_permissions=True)

    frappe.clear_cache()
    return {
        "ok": True,
        "brand_name": BACKEND_APP_NAME,
        "full_logo": full_logo,
        "login_logo": login_logo,
        "favicon": favicon,
    }
