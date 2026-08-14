from __future__ import annotations

import hashlib
import json
import math
import secrets
from dataclasses import dataclass
from datetime import timedelta

import frappe
from frappe.utils import add_to_date, get_datetime, now_datetime

from omc_app.api.auth_links import verification_links


PENDING_REGISTRATION_DOCTYPE = "OMC Pending Registration"
TOKEN_TTL_MINUTES = 30
RESEND_COOLDOWN_SECONDS = 60
ACTIVE_PENDING_STATUSES = ("Pending",)
TERMINAL_STATUSES = ("Activated", "Expired", "Superseded", "Cancelled")
TERMINAL_STATUSES = ("Activated", "Expired", "Superseded", "Cancelled")
GENERIC_PUBLIC_MESSAGE = (
    "If the details are eligible, a verification email will be sent shortly."
)
VERIFICATION_METHOD = "omc_app.api.pending_registration.verify_registration"


@dataclass(frozen=True)
class PendingRegistrationSecret:
    registration_name: str
    verification_token: str


def _token_digest(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _verification_email_html(
    username: str,
    app_url: str,
    web_url: str,
) -> str:
    safe_username = frappe.utils.escape_html(username)
    safe_app_url = frappe.utils.escape_html(app_url)
    safe_web_url = frappe.utils.escape_html(web_url)
    return f"""
    <div style="background:#f5f7fa;padding:32px 16px;font-family:Arial,sans-serif;">
      <div style="max-width:560px;margin:0 auto;background:#ffffff;border:1px solid #e5e7eb;border-radius:18px;padding:32px;">
        <div style="font-size:13px;font-weight:700;letter-spacing:.08em;color:#64748b;text-transform:uppercase;">
          OMC
        </div>
        <h1 style="margin:12px 0 8px;color:#0f172a;font-size:26px;line-height:1.2;">
          Verify your email
        </h1>
        <p style="margin:0 0 18px;color:#475569;font-size:15px;line-height:1.6;">
          Hello {safe_username}, confirm this email address to continue creating your OMC account.
        </p>
        <a href="{safe_web_url}" style="display:inline-block;background:#0f766e;color:#ffffff;text-decoration:none;font-weight:700;padding:13px 20px;border-radius:10px;">
          Verify email
        </a>
        <p style="margin:16px 0 0;color:#64748b;font-size:13px;line-height:1.55;">
          Using the OMC app? <a href="{safe_app_url}" style="color:#0f766e;font-weight:700;">Open in app</a>.
        </p>
        <p style="margin:12px 0 0;color:#64748b;font-size:13px;line-height:1.55;">
          This link expires in {TOKEN_TTL_MINUTES} minutes. If you did not request this account, you can ignore this email.
        </p>
      </div>
    </div>
    """


def _send_verification_email(email: str, username: str, token: str) -> None:
    # Frappe's v14 dummy Email Account is incomplete on sites without any
    # outgoing account. In an explicitly muted development/test environment,
    # avoid constructing that queue; production delivery remains mandatory.
    if frappe.are_emails_muted():
        return
    links = verification_links(token)
    frappe.sendmail(
        recipients=[email],
        subject="Verify your OMC account",
        message=_verification_email_html(
            username,
            links["universal_url"],
            links["web_url"],
        ),
        now=True,
    )


def _rotate_token(doc) -> str:
    token = secrets.token_urlsafe(32)
    now = now_datetime()
    doc.token_digest = _token_digest(token)
    doc.expires_at = add_to_date(now, minutes=TOKEN_TTL_MINUTES)
    doc.resend_after = add_to_date(now, seconds=RESEND_COOLDOWN_SECONDS)
    doc.attempt_count = int(doc.attempt_count or 0) + 1
    doc.last_attempt_at = now
    doc.save(ignore_permissions=True)
    return token


def _cooldown_seconds(resend_after=None) -> int:
    if not resend_after:
        return RESEND_COOLDOWN_SECONDS

    remaining = (get_datetime(resend_after) - now_datetime()).total_seconds()
    return max(0, math.ceil(remaining))


def _resend_payload(*, resend_after=None) -> dict:
    return {
        "message": GENERIC_PUBLIC_MESSAGE,
        "resend_after": resend_after,
        "cooldown_seconds": _cooldown_seconds(resend_after),
    }


def _public_payload(data: dict) -> dict:
    blocked = {
        "password",
        "new_password",
        "confirm_password",
        "verification_token",
        "token",
    }
    return {key: value for key, value in data.items() if key not in blocked}


def _sanitized_payload(doc) -> str:
    return json.dumps(
        {
            "email": str(doc.email or "").strip().lower(),
            "username": str(doc.username or "").strip().lower(),
        },
        ensure_ascii=False,
        sort_keys=True,
    )


def sanitize_registration(doc, *, status: str | None = None) -> None:
    """Remove recoverable secrets once a registration reaches a terminal state."""
    if status is not None:
        doc.status = status
    if doc.status not in TERMINAL_STATUSES:
        frappe.throw(
            "Pending registration secrets can only be cleared for terminal states.",
            frappe.ValidationError,
        )
    doc.password_secret = ""
    doc.payload_json = _sanitized_payload(doc)
    doc.token_digest = secrets.token_hex(32)


def _sanitized_payload(doc) -> str:
    return json.dumps(
        {
            "email": str(doc.email or "").strip().lower(),
            "username": str(doc.username or "").strip().lower(),
        },
        ensure_ascii=False,
        sort_keys=True,
    )


def sanitize_registration(doc, *, status: str | None = None) -> None:
    """Remove recoverable secrets once a registration reaches a terminal state."""
    if status is not None:
        doc.status = status
    if doc.status not in TERMINAL_STATUSES:
        frappe.throw(
            "Pending registration secrets can only be cleared for terminal states.",
            frappe.ValidationError,
        )
    doc.password_secret = ""
    doc.payload_json = _sanitized_payload(doc)
    doc.token_digest = secrets.token_hex(32)


def _existing_pending(filters: dict):
    names = frappe.get_all(
        PENDING_REGISTRATION_DOCTYPE,
        filters={**filters, "status": ["in", list(ACTIVE_PENDING_STATUSES)]},
        pluck="name",
        order_by="modified desc",
        limit=1,
    )
    return frappe.get_doc(PENDING_REGISTRATION_DOCTYPE, names[0]) if names else None


def _supersede_existing(email: str, username: str) -> None:
    names = frappe.get_all(
        PENDING_REGISTRATION_DOCTYPE,
        filters={
            "status": ["in", list(ACTIVE_PENDING_STATUSES)],
            "email": email,
        },
        pluck="name",
    )
    username_names = frappe.get_all(
        PENDING_REGISTRATION_DOCTYPE,
        filters={
            "status": ["in", list(ACTIVE_PENDING_STATUSES)],
            "username": username,
        },
        pluck="name",
    )
    for name in set(names + username_names):
        doc = frappe.get_doc(PENDING_REGISTRATION_DOCTYPE, name)
        sanitize_registration(doc, status="Superseded")
        doc.save(ignore_permissions=True)


def create_pending_registration(data: dict) -> PendingRegistrationSecret:
    from omc_app.api import access

    validated = access._validated_signup_kwargs(data)
    email = validated["email"]
    full_name = (
        validated.get("full_name")
        or validated.get("name")
        or email
    ).strip()

    submitted_username = validated.get("username")
    if submitted_username:
        username = access.validate_username(submitted_username)
    else:
        username = access.suggest_username(
            full_name=full_name,
            email=email,
        )["username"]

    password = validated.get("password") or validated.get("new_password")
    if not password:
        frappe.throw("A password is required", frappe.ValidationError)
    if len(password) < 8:
        frappe.throw(
            "Password must be at least 8 characters long",
            frappe.ValidationError,
        )

    if frappe.db.exists("User", email):
        frappe.throw(
            "An account with this email already exists. Please sign in.",
            frappe.DuplicateEntryError,
        )
    if frappe.db.exists("OMC Customer Profile", {"email": email}):
        frappe.throw(
            "An account with this email already exists. Please sign in.",
            frappe.DuplicateEntryError,
        )
    if frappe.db.exists("OMC Customer Profile", {"username": username}):
        frappe.throw("Username is already taken.", frappe.DuplicateEntryError)

    _supersede_existing(email, username)

    token = secrets.token_urlsafe(32)
    now = now_datetime()
    expires_at = add_to_date(now, minutes=TOKEN_TTL_MINUTES)
    resend_after = add_to_date(now, seconds=RESEND_COOLDOWN_SECONDS)

    payload = _public_payload(validated)
    payload["username"] = username
    payload["email"] = email

    doc = frappe.new_doc(PENDING_REGISTRATION_DOCTYPE)
    doc.email = email
    doc.username = username
    doc.status = "Pending"
    doc.expires_at = expires_at
    doc.resend_after = resend_after
    doc.token_digest = _token_digest(token)
    doc.payload_json = json.dumps(payload, ensure_ascii=False, sort_keys=True)
    doc.password_secret = password
    doc.insert(ignore_permissions=True)

    return PendingRegistrationSecret(
        registration_name=doc.name,
        verification_token=token,
    )


@frappe.whitelist(allow_guest=True)
def start_registration(**kwargs):
    secret = create_pending_registration(dict(kwargs or {}))
    doc = frappe.get_doc(PENDING_REGISTRATION_DOCTYPE, secret.registration_name)
    _send_verification_email(
        doc.email,
        doc.username,
        secret.verification_token,
    )
    frappe.db.commit()

    return {
        **_resend_payload(resend_after=doc.resend_after),
        "verification_required": True,
    }


@frappe.whitelist(allow_guest=True)
def resend_verification(email: str | None = None):
    normalized_email = str(email or "").strip().lower()
    if not normalized_email:
        return _resend_payload()

    doc = _existing_pending({"email": normalized_email})
    if not doc:
        return _resend_payload()

    now = now_datetime()
    if doc.resend_after and get_datetime(doc.resend_after) > now:
        return _resend_payload(resend_after=doc.resend_after)

    token = _rotate_token(doc)
    _send_verification_email(doc.email, doc.username, token)
    frappe.db.commit()

    return _resend_payload(resend_after=doc.resend_after)


@frappe.whitelist(allow_guest=True)
def verify_registration(token: str | None = None):
    token = str(token or "").strip()
    if not token:
        return {
            "ok": False,
            "status": "invalid_or_expired",
            "message": "This verification link is invalid or has expired.",
        }

    name = frappe.db.get_value(
        PENDING_REGISTRATION_DOCTYPE,
        {"token_digest": _token_digest(token)},
        "name",
    )
    if not name:
        return {
            "ok": False,
            "status": "invalid_or_expired",
            "message": "This verification link is invalid or has expired.",
        }

    doc = frappe.get_doc(PENDING_REGISTRATION_DOCTYPE, name)

    if doc.status == "Activated":
        return {
            "ok": True,
            "status": "activated",
            "message": "Your email is verified. You can sign in now.",
        }

    if doc.status not in ("Pending", "Verified"):
        return {
            "ok": False,
            "status": "invalid_or_expired",
            "message": "This verification link is invalid or has expired.",
        }

    if get_datetime(doc.expires_at) <= now_datetime():
        sanitize_registration(doc, status="Expired")
        doc.save(ignore_permissions=True)
        frappe.db.commit()
        return {
            "ok": False,
            "status": "invalid_or_expired",
            "message": "This verification link is invalid or has expired.",
        }

    # Mark the token as consumed before account creation. The canonical signup
    # method commits the transaction, so this state also protects against
    # double activation if a request is retried during or after that commit.
    if doc.status == "Pending":
        doc.status = "Verified"
        doc.verified_at = now_datetime()
        doc.save(ignore_permissions=True)

    from omc_app.api import mobile

    payload = read_pending_payload(doc)
    payload["password"] = read_pending_password(doc)
    payload["username"] = doc.username
    payload["email"] = doc.email

    user_exists = frappe.db.exists("User", doc.email)
    profile_exists = frappe.db.exists(
        "OMC Customer Profile",
        {"email": doc.email},
    )

    if not user_exists or not profile_exists:
        mobile.sign_up(**payload)

    doc.reload()
    doc.activated_user = (
        doc.email if frappe.db.exists("User", doc.email) else None
    )
    sanitize_registration(doc, status="Activated")
    doc.save(ignore_permissions=True)
    frappe.db.commit()

    return {
        "ok": True,
        "status": "activated",
        "message": "Your email is verified. You can sign in now.",
    }


def _verification_result_page(result: dict) -> tuple[str, str, str]:
    status = str((result or {}).get("status") or "")
    activated = bool((result or {}).get("ok")) and status == "activated"

    if activated:
        title = "Your OMC account is activated"
        message = (
            "Your email has been verified successfully. "
            "You can now sign in to the OMC House app."
        )
        app_url = "omchouse://auth/login?verified=1"
        accent = "#0f766e"
        icon = "&#10003;"
        action_label = "Open OMC App"
    else:
        title = "Verification link unavailable"
        message = str(
            (result or {}).get("message")
            or "This verification link is invalid or has expired."
        )
        app_url = "omchouse://auth/login?verification=invalid"
        accent = "#b45309"
        icon = "!"
        action_label = "Open OMC App"

    safe_title = frappe.utils.escape_html(title)
    safe_message = frappe.utils.escape_html(message)
    safe_app_url = frappe.utils.escape_html(app_url)
    safe_action_label = frappe.utils.escape_html(action_label)

    html = f"""
    <div style="min-height:100vh;background:#f4f7fb;padding:32px 16px;
                font-family:Arial,sans-serif;box-sizing:border-box;">
      <div style="max-width:560px;margin:48px auto;background:#ffffff;
                  border:1px solid #e5e7eb;border-radius:24px;
                  box-shadow:0 18px 50px rgba(15,23,42,.08);
                  padding:40px 32px;text-align:center;">
        <div style="width:72px;height:72px;border-radius:50%;
                    margin:0 auto 22px;background:{accent}18;color:{accent};
                    display:flex;align-items:center;justify-content:center;
                    font-size:36px;font-weight:800;">
          {icon}
        </div>
        <div style="font-size:12px;font-weight:800;letter-spacing:.12em;
                    text-transform:uppercase;color:#64748b;">
          OMC House
        </div>
        <h1 style="margin:12px 0 12px;color:#0f172a;font-size:30px;
                   line-height:1.2;">
          {safe_title}
        </h1>
        <p style="margin:0 auto;color:#475569;font-size:16px;line-height:1.65;
                  max-width:430px;">
          {safe_message}
        </p>
        <a href="{safe_app_url}"
           style="display:inline-block;margin-top:28px;background:{accent};
                  color:#ffffff;text-decoration:none;font-weight:800;
                  padding:14px 24px;border-radius:12px;">
          {safe_action_label}
        </a>
        <p style="margin:20px 0 0;color:#94a3b8;font-size:13px;line-height:1.55;">
          If the app is not installed, this page will remain open. You may
          install the app later and sign in with your verified account.
        </p>
      </div>
    </div>
    """
    return title, html, "green" if activated else "orange"


@frappe.whitelist(allow_guest=True)
def verify_registration_web(token: str | None = None):
    result = verify_registration(token=token)
    title, html, indicator = _verification_result_page(result)
    frappe.respond_as_web_page(
        title=title,
        html=html,
        indicator_color=indicator,
        http_status_code=200,
    )


def load_pending_registration_by_token(token: str):
    token = str(token or "").strip()
    if not token:
        return None

    name = frappe.db.get_value(
        PENDING_REGISTRATION_DOCTYPE,
        {"token_digest": _token_digest(token)},
        "name",
    )
    if not name:
        return None

    doc = frappe.get_doc(PENDING_REGISTRATION_DOCTYPE, name)
    if doc.status != "Pending":
        return None

    if get_datetime(doc.expires_at) <= now_datetime():
        sanitize_registration(doc, status="Expired")
        doc.save(ignore_permissions=True)
        frappe.db.commit()
        return None

    return doc


def read_pending_payload(doc) -> dict:
    return json.loads(doc.payload_json or "{}")


def read_pending_password(doc) -> str:
    return doc.get_password("password_secret")
