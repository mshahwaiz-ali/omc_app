import re

import frappe


DEFAULT_ACCENT = "#111827"


def _valid_color(value):
    text = str(value or "").strip().upper()
    return text if re.fullmatch(r"#[0-9A-F]{6}", text) else ""


def _single_value(doctype, fieldname):
    rows = frappe.db.sql(
        """
        select value
        from `tabSingles`
        where doctype = %s and field = %s
        limit 1
        """,
        (doctype, fieldname),
    )
    return rows[0][0] if rows else None


def execute():
    # Preserve any explicitly saved accent before removing its old field.
    if not frappe.db.exists("DocType", "OMC Branding Settings"):
        return

    branding_accent = _valid_color(
        _single_value("OMC Branding Settings", "accent_color")
    )
    mobile_accent = _valid_color(
        _single_value("OMC Mobile Settings", "accent_color")
    )

    frappe.db.set_single_value(
        "OMC Branding Settings",
        "accent_color",
        branding_accent or mobile_accent or DEFAULT_ACCENT,
    )

    # Remove stale values for fields no longer present in either Single DocType.
    frappe.db.sql(
        """
        delete from `tabSingles`
        where doctype = %s and field = %s
        """,
        ("OMC Branding Settings", "primary_color"),
    )
    frappe.db.sql(
        """
        delete from `tabSingles`
        where doctype = %s and field = %s
        """,
        ("OMC Mobile Settings", "accent_color"),
    )
