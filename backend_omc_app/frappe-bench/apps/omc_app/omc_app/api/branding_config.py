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
    from omc_app.api.mobile_release_controls import validate_release_controls

    # Missing settings or malformed control metadata must not look like an
    # authoritative enabled config. No setting is modified by this read.
    mobile_settings = mobile._get_single_settings("OMC Mobile Settings")
    if mobile_settings is None:
        frappe.throw("Mobile configuration is unavailable.", frappe.ValidationError)
    try:
        controls = validate_release_controls(
            mobile_settings.get("minimum_app_version"),
            mobile_settings.get("force_update"),
            mobile_settings.get("maintenance_mode"),
        )
    except ValueError as error:
        frappe.throw(str(error), frappe.ValidationError)
    payload = mobile.get_mobile_app_config()
    payload.setdefault("meta", {}).update(controls)
    settings = mobile._get_single_settings("OMC Branding Settings")

    branding = dict(payload.get("branding") or {})
    branding.pop("primary_color_family", None)
    branding.pop("primaryColorFamily", None)
    branding["accent_color"] = _resolved_accent_color(settings)
    payload["branding"] = branding

    return payload
