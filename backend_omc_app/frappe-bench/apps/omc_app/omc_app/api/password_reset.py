from __future__ import annotations

import hashlib
import secrets

import frappe
from frappe import _
from frappe.exceptions import ValidationError
from frappe.utils import add_to_date, escape_html, get_datetime, get_url, now_datetime
from frappe.utils.password import update_password

from omc_app.api.auth_login import resolve_login_email


DOCTYPE = "OMC Password Reset"
TOKEN_TTL_MINUTES = 30
GENERIC_MESSAGE = (
    "If the account is eligible, password reset instructions will be sent shortly."
)


def _digest(token: str) -> str:
    return hashlib.sha256(str(token or "").encode("utf-8")).hexdigest()


def _reset_url(token: str) -> str:
    return get_url("/reset-password?token=" + token)


def _email_html(reset_url: str) -> str:
    safe_url = escape_html(reset_url)
    return f"""
    <div style="background:#f5f7fa;padding:32px 16px;font-family:Arial,sans-serif;">
      <div style="max-width:560px;margin:0 auto;background:#ffffff;border:1px solid #e5e7eb;border-radius:18px;padding:32px;">
        <div style="font-size:13px;font-weight:700;letter-spacing:.08em;color:#64748b;text-transform:uppercase;">
          OMC
        </div>
        <h1 style="margin:12px 0 8px;color:#0f172a;font-size:26px;line-height:1.2;">
          Reset your password
        </h1>
        <p style="margin:0 0 18px;color:#475569;font-size:15px;line-height:1.6;">
          Use the secure link below to choose a new password.
        </p>
        <a href="{safe_url}" style="display:inline-block;background:#0f766e;color:#ffffff;text-decoration:none;font-weight:700;padding:13px 20px;border-radius:10px;">
          Reset password
        </a>
        <p style="margin:20px 0 0;color:#64748b;font-size:13px;line-height:1.55;">
          This link expires in {TOKEN_TTL_MINUTES} minutes. If you did not request this change, ignore this email.
        </p>
      </div>
    </div>
    """


def _supersede_existing(user: str) -> None:
    names = frappe.get_all(
        DOCTYPE,
        filters={"user": user, "status": "Pending"},
        pluck="name",
    )
    for name in names:
        frappe.db.set_value(DOCTYPE, name, "status", "Superseded")


def _create_reset(user: str) -> tuple[str, object]:
    _supersede_existing(user)
    token = secrets.token_urlsafe(32)
    now = now_datetime()
    doc = frappe.get_doc(
        {
            "doctype": DOCTYPE,
            "user": user,
            "status": "Pending",
            "expires_at": add_to_date(now, minutes=TOKEN_TTL_MINUTES),
            "token_digest": _digest(token),
            "requested_at": now,
        }
    )
    doc.insert(ignore_permissions=True)
    return token, doc


@frappe.whitelist(allow_guest=True)
def request_reset(identifier: str | None = None):
    user = resolve_login_email(str(identifier or ""))
    if not user:
        return {"message": GENERIC_MESSAGE}

    token, _doc = _create_reset(user)
    frappe.sendmail(
        recipients=[user],
        subject="Reset your OMC password",
        message=_email_html(_reset_url(token)),
        now=False,
    )
    frappe.db.commit()
    return {"message": GENERIC_MESSAGE}


def _load_valid_reset(token: str):
    digest = _digest(token)
    name = frappe.db.get_value(DOCTYPE, {"token_digest": digest}, "name")
    if not name:
        return None

    doc = frappe.get_doc(DOCTYPE, name)
    if doc.status != "Pending":
        return None

    if get_datetime(doc.expires_at) <= now_datetime():
        doc.status = "Expired"
        doc.save(ignore_permissions=True)
        frappe.db.commit()
        return None

    return doc


@frappe.whitelist(allow_guest=True)
def reset_password(
    token: str | None = None,
    new_password: str | None = None,
    confirm_password: str | None = None,
):
    secret = str(new_password or "")
    confirmation = str(confirm_password or "")

    if len(secret) < 8:
        frappe.throw(_("Password must be at least 8 characters."), ValidationError)
    if secret != confirmation:
        frappe.throw(_("Passwords do not match."), ValidationError)

    doc = _load_valid_reset(str(token or ""))
    if not doc:
        return {
            "ok": False,
            "status": "invalid_or_expired",
            "message": "This password reset link is invalid or has expired.",
        }

    update_password(doc.user, secret)
    doc.status = "Used"
    doc.used_at = now_datetime()
    doc.token_digest = secrets.token_hex(32)
    doc.save(ignore_permissions=True)
    frappe.db.commit()

    return {
        "ok": True,
        "status": "password_reset",
        "message": "Your password has been updated. You can sign in now.",
    }
