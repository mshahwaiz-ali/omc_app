import re

import frappe

from omc_app.api import mobile

_DEFAULT_ACCENT = "#111827"


def _resolved_accent_color(settings):
    value = (getattr(settings, "accent_color", None) or "").strip().upper()
    return value if re.fullmatch(r"#[0-9A-F]{6}", value) else _DEFAULT_ACCENT


@frappe.whitelist(allow_guest=True)
def get_mobile_app_config():
    """Return the public mobile config with one accent-color source of truth."""
    payload = mobile.get_mobile_app_config()
    settings = mobile._get_single_settings("OMC Branding Settings")

    branding = dict(payload.get("branding") or {})
    branding.pop("primary_color_family", None)
    branding.pop("primaryColorFamily", None)
    branding["accent_color"] = _resolved_accent_color(settings)
    payload["branding"] = branding

    return payload
