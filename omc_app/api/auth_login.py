from __future__ import annotations

import re

import frappe
from frappe import _
from frappe.auth import LoginManager
from frappe.exceptions import AuthenticationError


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


def resolve_login_email(identifier: str) -> str | None:
    clean = str(identifier or "").strip()
    if not clean:
        return None

    lowered = clean.lower()

    if "@" in lowered:
        user = frappe.db.get_value(
            "User",
            {"name": lowered, "enabled": 1},
            "name",
        )
        return str(user).strip().lower() if user else None

    username = re.sub(r"[^a-z0-9._-]", "", lowered)
    if username:
        email = _profile_email_by_field("username", (username,))
        if email:
            return email

    digits = _digits(clean)
    if len(digits) == 13:
        email = _profile_email_by_field("cnic", (digits,))
        if email:
            return email

    mobile_values = _mobile_candidates(clean)
    for fieldname in ("mobile", "mobile_no", "phone"):
        email = _profile_email_by_field(fieldname, mobile_values)
        if email:
            return email

    return None


@frappe.whitelist(allow_guest=True)
def login(identifier: str | None = None, password: str | None = None):
    email = resolve_login_email(str(identifier or ""))
    secret = str(password or "")

    if not email or not secret:
        frappe.throw(_(GENERIC_LOGIN_ERROR), AuthenticationError)

    try:
        manager = LoginManager()
        manager.authenticate(user=email, pwd=secret)
        manager.post_login()
    except AuthenticationError:
        frappe.throw(_(GENERIC_LOGIN_ERROR), AuthenticationError)

    return {
        "message": "Logged In",
        "user": frappe.session.user,
        "email": email,
    }
