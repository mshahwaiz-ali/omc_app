from __future__ import annotations

import re

import frappe
from frappe import _
from frappe.auth import LoginManager
from frappe.exceptions import AuthenticationError

from omc_app.api import security


PROFILE_DOCTYPE = "OMC Customer Profile"
GENERIC_LOGIN_ERROR = "Invalid login credentials."


def _digits(value: str) -> str:
    return re.sub(r"\D", "", value or "")


def _mobile_candidates(value: str) -> tuple[str, ...]:
    digits = _digits(value)
    if digits.startswith("92"):
        local = digits[2:]
    elif digits.startswith("0"):
        local = digits[1:]
    else:
        local = digits

    if len(local) != 10 or not local.startswith("3"):
        return ()

    return tuple(dict.fromkeys((f"+92{local}", f"92{local}", f"0{local}", local)))


def _enabled_user_name(identifier: str) -> str | None:
    clean = str(identifier or "").strip()
    if not clean:
        return None

    direct = frappe.db.get_value("User", {"name": clean, "enabled": 1}, "name")
    if direct:
        return str(direct).strip()

    lowered = clean.lower()
    matches = set()
    for fieldname in ("email", "username"):
        for user in frappe.get_all(
            "User",
            filters={fieldname: lowered, "enabled": 1},
            pluck="name",
            limit_page_length=2,
        ):
            matches.add(str(user).strip())
    return next(iter(matches)) if len(matches) == 1 else None


def _profile_users_by_field(fieldname: str, values: tuple[str, ...]) -> set[str]:
    if not values:
        return set()
    meta = frappe.get_meta(PROFILE_DOCTYPE)
    if not meta.has_field(fieldname):
        return set()

    users: set[str] = set()
    rows = frappe.get_all(
        PROFILE_DOCTYPE,
        filters={fieldname: ["in", list(values)]},
        fields=["email"],
        limit_page_length=10,
    )
    for row in rows:
        user = _enabled_user_name(str(row.email or "").strip().lower())
        if user:
            users.add(user)
    return users


def _unique_profile_user(fieldname: str, values: tuple[str, ...]) -> str | None:
    users = _profile_users_by_field(fieldname, values)
    return next(iter(users)) if len(users) == 1 else None


def resolve_login_email(identifier: str) -> str | None:
    """Resolve only an unambiguous enabled identity.

    Ambiguous phone/CNIC/profile aliases intentionally collapse to the same
    generic login failure as an unknown identifier; no candidate account is
    selected by database ordering.
    """
    clean = str(identifier or "").strip()
    if not clean:
        return None

    user = _enabled_user_name(clean)
    if user:
        return user

    lowered = clean.lower()
    username = re.sub(r"[^a-z0-9._-]", "", lowered)
    if username:
        users = _profile_users_by_field("username", (username,))
        if len(users) != 1:
            if users:
                return None
        else:
            return next(iter(users))

    digits = _digits(clean)
    if len(digits) == 13:
        users = _profile_users_by_field("cnic", (digits,))
        if len(users) != 1:
            if users:
                return None
        else:
            return next(iter(users))

    mobile_values = _mobile_candidates(clean)
    if mobile_values:
        users: set[str] = set()
        for fieldname in ("mobile", "mobile_no", "phone"):
            users.update(_profile_users_by_field(fieldname, mobile_values))
        if len(users) == 1:
            return next(iter(users))
        if users:
            return None

    return None


@frappe.whitelist(allow_guest=True, methods=["POST"])
def login(identifier: str | None = None, password: str | None = None):
    security.enforce_rate_limit("login", actor=str(identifier or ""))
    try:
        user = resolve_login_email(str(identifier or ""))
        secret = str(password or "")
        if not user or not secret:
            frappe.throw(_(GENERIC_LOGIN_ERROR), AuthenticationError)

        manager = LoginManager()
        manager.authenticate(user=user, pwd=secret)
        manager.post_login()
        security.clear_actor_rate_limit("login", actor=str(identifier or ""))
    except AuthenticationError:
        frappe.throw(_(GENERIC_LOGIN_ERROR), AuthenticationError)
    except Exception:
        frappe.log_error(frappe.get_traceback(), "OMC login failure")
        frappe.throw(_(GENERIC_LOGIN_ERROR), AuthenticationError)

    email = frappe.db.get_value("User", user, "email") or user
    return {
        "message": "Logged In",
        "user": frappe.session.user,
        "email": str(email).strip().lower(),
    }
