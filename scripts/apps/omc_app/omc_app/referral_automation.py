from __future__ import annotations

import frappe

from omc_app.api import referrals
from omc_app.referral_capabilities import REFERRAL_OWNER_ROLES


ELIGIBLE_REFERRAL_ROLES = frozenset(REFERRAL_OWNER_ROLES)


def _roles(user: str) -> set[str]:
    if not user or user == "Guest":
        return set()
    return set(frappe.get_roles(user) or [])


def is_eligible_referral_owner(user: str) -> bool:
    if not user or user in {"Guest", "Administrator"}:
        return False

    enabled, user_type = frappe.db.get_value(
        "User",
        user,
        ["enabled", "user_type"],
    ) or (0, "")
    if not int(enabled or 0) or user_type != "System User":
        return False

    return bool(_roles(user).intersection(ELIGIBLE_REFERRAL_ROLES))


def _customer_profile_name(user: str) -> str | None:
    for filters in (
        {"linked_app_user": user},
        {"user": user},
        {"email": user},
    ):
        name = frappe.db.get_value("OMC Customer Profile", filters, "name")
        if name:
            return name
    return None


def _sync_profile_referral_code(user: str, code: str = "") -> None:
    profile_name = _customer_profile_name(user)
    if not profile_name:
        return
    current = frappe.db.get_value(
        "OMC Customer Profile",
        profile_name,
        "own_referral_code",
    ) or ""
    if current != code:
        frappe.db.set_value(
            "OMC Customer Profile",
            profile_name,
            "own_referral_code",
            code,
            update_modified=False,
        )


def ensure_referral_code_for_user(user: str):
    if not is_eligible_referral_owner(user):
        existing = frappe.db.get_value(
            "OMC Referral",
            {"referrer_user": user},
            ["name", "is_active"],
            as_dict=True,
        )
        if existing and int(existing.is_active or 0):
            frappe.db.set_value(
                "OMC Referral",
                existing.name,
                {
                    "is_active": 0,
                    "status": "Inactive",
                },
                update_modified=False,
            )
        _sync_profile_referral_code(user, "")
        return None

    record = referrals.get_or_create_owner_record(user)
    if not int(record.is_active or 0) or (record.status or "") != "Approved":
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
    _sync_profile_referral_code(user, record.referral_code)
    return record


def sync_user_referral_code(doc, method=None):
    user = getattr(doc, "name", None) or getattr(doc, "email", None)
    if not user or not frappe.db.exists("User", user):
        return
    ensure_referral_code_for_user(user)


def resolve_eligible_referral(code: str | None):
    record = referrals.resolve_active_referral(code)
    if not record or not is_eligible_referral_owner(record.referrer_user):
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
