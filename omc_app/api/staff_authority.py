"""Canonical staff identity/persona authority for OMC application flows.

Frappe User and ERP Employee remain the identity/employment masters. OMC Staff
Access is the application authorization and reviewed-persona authority. OMC
Staff Profile is retained as a professional/referral extension and legacy
compatibility source only when no Staff Access record exists yet.
"""
from __future__ import annotations

from typing import Any

import frappe

from omc_app.setup.roles import ACTIVE_STAFF_ROLES, ERP_STAFF_PERSONAS


STAFF_ACCESS_DOCTYPE = "OMC Staff Access"
STAFF_PROFILE_DOCTYPE = "OMC Staff Profile"


def _text(value: Any) -> str:
    return str(value or "").strip()


def employee_for_user(user: str) -> str:
    user = _text(user)
    if not user or not frappe.db.exists("DocType", "Employee"):
        return ""
    return _text(
        frappe.db.get_value(
            "Employee",
            {"user_id": user},
            "name",
        )
    )


def profile_for_user(user: str) -> str:
    user = _text(user)
    if not user or not frappe.db.exists("DocType", STAFF_PROFILE_DOCTYPE):
        return ""
    return _text(
        frappe.db.get_value(
            STAFF_PROFILE_DOCTYPE,
            {"user": user},
            "name",
        )
    )


def access_record(user: str):
    user = _text(user)
    if not user or not frappe.db.exists("DocType", STAFF_ACCESS_DOCTYPE):
        return None
    name = frappe.db.get_value(
        STAFF_ACCESS_DOCTYPE,
        {"user": user},
        "name",
    )
    return frappe.get_doc(STAFF_ACCESS_DOCTYPE, name) if name else None


def access_persona(user: str) -> tuple[bool, str]:
    """Return ``(has_access_record, effective_persona)``.

    Once Staff Access exists it is authoritative even when pending/conflicted;
    the function deliberately does not fall back to Staff Profile in that
    state, preventing a legacy profile from restoring authority that canonical
    access has withheld.
    """

    access = access_record(user)
    if not access:
        return False, ""

    if (
        _text(getattr(access, "access_status", None)) != "Approved"
        or _text(getattr(access, "reconciliation_status", None)) != "Current"
    ):
        return True, ""

    persona = _text(getattr(access, "persona_snapshot", None))
    return True, persona if persona in ACTIVE_STAFF_ROLES else ""


def reviewed_persona_for_roles(roles) -> str:
    """Choose one durable persona independently from capability bundles.

    ERP personas describe the person's business persona; operational OMC roles
    describe application duties. A staff member may therefore combine one ERP
    persona with several operational capability roles without losing their
    persona snapshot. Multiple ERP personas are ambiguous and must be reviewed.
    """

    selected = {_text(role) for role in (roles or []) if _text(role)}
    personas = sorted(selected.intersection(ERP_STAFF_PERSONAS))
    if len(personas) > 1:
        frappe.throw(
            "Select at most one ERP staff persona for a Staff Access record.",
            frappe.ValidationError,
        )
    if personas:
        return personas[0]
    if len(selected) == 1:
        only = next(iter(selected))
        return only if only in ACTIVE_STAFF_ROLES else ""
    return "Reviewed"


def canonical_links(user: str) -> dict[str, str]:
    """Return canonical ERP identity links for Staff Access reconciliation."""

    return {
        "employee": employee_for_user(user),
        "legacy_staff_profile": profile_for_user(user),
    }
