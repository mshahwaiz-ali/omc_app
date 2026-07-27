from __future__ import annotations

import frappe

from omc_app.api import referrals
from omc_app.referral_capabilities import REFERRAL_OWNER_ROLES


ELIGIBLE_REFERRAL_ROLES = frozenset(REFERRAL_OWNER_ROLES | {"OMC Admin", "OMC Manager"})


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


def ensure_referral_code_for_user(user: str):
    if not is_eligible_referral_owner(user):
        return None
    return referrals.get_or_create_owner_record(user)


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
