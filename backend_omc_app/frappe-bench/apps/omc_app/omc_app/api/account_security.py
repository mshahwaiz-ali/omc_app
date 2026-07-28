from __future__ import annotations

import frappe
from frappe import _
from frappe.exceptions import AuthenticationError, PermissionError, ValidationError
from frappe.utils.password import check_password, update_password


MIN_PASSWORD_LENGTH = 8
MAX_PASSWORD_LENGTH = 128


def _current_user() -> str:
    user = str(frappe.session.user or "").strip()
    if not user or user == "Guest":
        frappe.throw(_("Login is required."), PermissionError)
    return user


def _clean_secret(value, *, label: str) -> str:
    if value is None:
        return ""

    if not isinstance(value, str):
        frappe.throw(_("{0} must be text.").format(label), ValidationError)

    if len(value) > MAX_PASSWORD_LENGTH:
        frappe.throw(
            _("{0} must be {1} characters or fewer.").format(
                label,
                MAX_PASSWORD_LENGTH,
            ),
            ValidationError,
        )

    return value


@frappe.whitelist(methods=["POST"])
def change_password(
    current_password: str | None = None,
    new_password: str | None = None,
    confirm_password: str | None = None,
):
    user = _current_user()

    current = _clean_secret(current_password, label="Current password")
    new = _clean_secret(new_password, label="New password")
    confirm = _clean_secret(confirm_password, label="Confirm password")

    if not current:
        frappe.throw(_("Current password is required."), ValidationError)

    if not new:
        frappe.throw(_("New password is required."), ValidationError)

    if len(new) < MIN_PASSWORD_LENGTH:
        frappe.throw(
            _("New password must be at least {0} characters.").format(
                MIN_PASSWORD_LENGTH
            ),
            ValidationError,
        )

    if new != confirm:
        frappe.throw(_("New passwords do not match."), ValidationError)

    if current == new:
        frappe.throw(
            _("New password must be different from your current password."),
            ValidationError,
        )

    if not frappe.db.exists("User", user):
        frappe.throw(_("User account was not found."), ValidationError)

    try:
        check_password(user, current)
    except AuthenticationError:
        frappe.throw(_("Current password is incorrect."), AuthenticationError)

    update_password(
        user,
        new,
        logout_all_sessions=True,
    )
    frappe.db.commit()

    frappe.logger("omc_app.security").info(
        "Password changed through mobile self-service for user=%s",
        user,
    )

    return {
        "changed": True,
        "logout_required": True,
        "message": "Password changed successfully. Sign in again.",
    }
