from __future__ import annotations

import frappe

from omc_app.api import referrals


ELIGIBLE_REFERRAL_ROLES = frozenset(
    referrals.REFERRAL_OWNER_ROLES
)


def is_eligible_referral_owner(user: str) -> bool:
    return referrals.is_referral_owner(user)


def _staff_profile_name(user: str) -> str | None:
    if not user or user == "Guest":
        return None

    if not frappe.db.exists("DocType", "OMC Staff Profile"):
        return None

    return frappe.db.get_value(
        "OMC Staff Profile",
        {"user": user},
        "name",
    )


def _sync_staff_profile_referral(user: str, record=None) -> None:
    profile_name = _staff_profile_name(user)
    if not profile_name:
        return

    referral_record = record.name if record else ""
    referral_code = record.referral_code if record else ""

    current = frappe.db.get_value(
        "OMC Staff Profile",
        profile_name,
        ["referral_record", "own_referral_code"],
        as_dict=True,
    )

    if not current:
        return

    values = {}

    if (current.referral_record or "") != referral_record:
        values["referral_record"] = referral_record or None

    if (current.own_referral_code or "") != referral_code:
        values["own_referral_code"] = referral_code

    if values:
        frappe.db.set_value(
            "OMC Staff Profile",
            profile_name,
            values,
            update_modified=False,
        )


def ensure_referral_code_for_user(user: str):
    user = str(user or "").strip()

    if not user or user == "Guest":
        return None

    if not is_eligible_referral_owner(user):
        existing = frappe.db.get_value(
            "OMC Referral",
            {"referrer_user": user},
            ["name", "is_active", "status"],
            as_dict=True,
        )

        if existing and (
            int(existing.is_active or 0)
            or (existing.status or "") != "Inactive"
        ):
            frappe.db.set_value(
                "OMC Referral",
                existing.name,
                {
                    "is_active": 0,
                    "status": "Inactive",
                },
                update_modified=False,
            )

        _sync_staff_profile_referral(user, None)
        return None

    record = referrals.get_or_create_owner_record(user)

    if (
        not int(record.is_active or 0)
        or (record.status or "") != "Approved"
    ):
        frappe.db.set_value(
            "OMC Referral",
            record.name,
            {
                "is_active": 1,
                "status": "Approved",
            },
            update_modified=False,
        )
        record.reload()

    _sync_staff_profile_referral(user, record)
    return record


def sync_user_referral_code(doc, method=None):
    """Compatibility hook for User changes."""
    user = getattr(doc, "name", None) or getattr(doc, "email", None)

    if not user or not frappe.db.exists("User", user):
        return

    ensure_referral_code_for_user(user)


def resolve_eligible_referral(code: str | None):
    record = referrals.resolve_active_referral(code)

    if not record:
        return None

    if not is_eligible_referral_owner(record.referrer_user):
        return None

    return record


@frappe.whitelist(allow_guest=True)
def validate_referral_code(referral_code: str | None = None):
    normalized = referrals.normalize_referral_code(referral_code)
    record = resolve_eligible_referral(normalized)

    return {
        "valid": bool(record),
        "referral_code": normalized if record else "",
        "message": (
            "Referral code verified."
            if record
            else "Referral code is invalid or inactive."
        ),
    }
