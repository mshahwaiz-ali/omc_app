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

    return tuple(
        dict.fromkeys(
            (
                f"+92{local}",
                f"92{local}",
                f"0{local}",
                local,
            )
        )
    )


def _profile_email_by_field(fieldname: str, values: tuple[str, ...]) -> str | None:
    if not values:
        return None

    meta = frappe.get_meta(PROFILE_DOCTYPE)
    if not meta.has_field(fieldname):
        return None

    for value in values:
        email = frappe.db.get_value(
            PROFILE_DOCTYPE,
            {fieldname: value},
            "email",
        )
        if email:
            return str(email).strip().lower()

    return None


def _enabled_user_name(identifier: str) -> str | None:
    clean = str(identifier or "").strip()
    if not clean:
        return None

    direct = frappe.db.get_value(
        "User",
        {"name": clean, "enabled": 1},
        "name",
    )
    if direct:
        return str(direct).strip()

    lowered = clean.lower()
    for fieldname in ("email", "username"):
        user = frappe.db.get_value(
            "User",
            {fieldname: lowered, "enabled": 1},
            "name",
        )
        if user:
            return str(user).strip()

    return None


def resolve_login_email(identifier: str) -> str | None:
    clean = str(identifier or "").strip()
    if not clean:
        return None

    user = _enabled_user_name(clean)
    if user:
        return user

    lowered = clean.lower()
    username = re.sub(r"[^a-z0-9._-]", "", lowered)
    if username:
        profile_email = _profile_email_by_field("username", (username,))
        user = _enabled_user_name(profile_email or "")
        if user:
            return user

    digits = _digits(clean)
    if len(digits) == 13:
        profile_email = _profile_email_by_field("cnic", (digits,))
        user = _enabled_user_name(profile_email or "")
        if user:
            return user

    mobile_values = _mobile_candidates(clean)
    for fieldname in ("mobile", "mobile_no", "phone"):
        profile_email = _profile_email_by_field(fieldname, mobile_values)
        user = _enabled_user_name(profile_email or "")
        if user:
            return user

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
