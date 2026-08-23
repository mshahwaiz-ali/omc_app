from __future__ import annotations

import hashlib
import json
import math
import secrets
from dataclasses import dataclass

import frappe
from frappe.utils import add_to_date, get_datetime, now_datetime

from omc_app.api import identity, security
from omc_app.api.auth_links import verification_links


PENDING_REGISTRATION_DOCTYPE = "OMC Pending Registration"
TOKEN_TTL_MINUTES = 30
RESEND_COOLDOWN_SECONDS = 60
ACTIVE_PENDING_STATUSES = ("Pending", "Verified")
TERMINAL_STATUSES = ("Activated", "Expired", "Superseded", "Cancelled")
GENERIC_PUBLIC_MESSAGE = (
    "If the details are eligible, a verification email will be sent shortly."
)
VERIFICATION_METHOD = "omc_app.api.pending_registration.verify_registration"
COMPLETION_METHOD = "omc_app.api.pending_registration.complete_registration"


@dataclass(frozen=True)
class PendingRegistrationSecret:
    registration_name: str
    verification_token: str


def _token_digest(token: str) -> str:
    return hashlib.sha256(str(token or "").encode("utf-8")).hexdigest()


def _verification_email_html(username: str, app_url: str, web_url: str) -> str:
    safe_username = frappe.utils.escape_html(username)
    safe_app_url = frappe.utils.escape_html(app_url)
    safe_web_url = frappe.utils.escape_html(web_url)
    return f"""
    <div style="background:#f5f7fa;padding:32px 16px;font-family:Arial,sans-serif;">
      <div style="max-width:560px;margin:0 auto;background:#ffffff;border:1px solid #e5e7eb;border-radius:18px;padding:32px;">
        <div style="font-size:13px;font-weight:700;letter-spacing:.08em;color:#64748b;text-transform:uppercase;">OMC</div>
        <h1 style="margin:12px 0 8px;color:#0f172a;font-size:26px;line-height:1.2;">Verify your email</h1>
        <p style="margin:0 0 18px;color:#475569;font-size:15px;line-height:1.6;">
          Hello {safe_username}, confirm this email address to continue creating your OMC account.
        </p>
        <a href="{safe_web_url}" style="display:inline-block;background:#0f766e;color:#ffffff;text-decoration:none;font-weight:700;padding:13px 20px;border-radius:10px;">Verify email</a>
        <p style="margin:16px 0 0;color:#64748b;font-size:13px;line-height:1.55;">
          Using the OMC app? <a href="{safe_app_url}" style="color:#0f766e;font-weight:700;">Open in app</a>.
        </p>
        <p style="margin:12px 0 0;color:#64748b;font-size:13px;line-height:1.55;">
          This link expires in {TOKEN_TTL_MINUTES} minutes. Your password is not stored before verification.
        </p>
      </div>
    </div>
    """


def _send_verification_email(email: str, username: str, token: str) -> None:
    if frappe.are_emails_muted():
        return
    links = verification_links(token)
    frappe.sendmail(
        recipients=[email],
        subject="Verify your OMC account",
        message=_verification_email_html(username, links["app_url"], links["web_url"]),
        now=True,
    )


def _rotate_token(doc) -> str:
    token = secrets.token_urlsafe(32)
    now = now_datetime()
    doc.status = "Pending"
    doc.token_digest = _token_digest(token)
    doc.expires_at = add_to_date(now, minutes=TOKEN_TTL_MINUTES)
    doc.resend_after = add_to_date(now, seconds=RESEND_COOLDOWN_SECONDS)
    doc.attempt_count = int(doc.attempt_count or 0) + 1
    doc.last_attempt_at = now
    doc.verified_at = None
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
    """Retire a pending registration without retaining reusable secrets."""
    if status is not None:
        doc.status = status
    if doc.status not in TERMINAL_STATUSES:
        frappe.throw(
            "Pending registration can only be sanitized in a terminal state.",
            frappe.ValidationError,
        )
    doc.payload_json = _sanitized_payload(doc)
    # Replacing the digest makes the emailed token single-use even if the row is
    # retained for audit/reconciliation purposes.
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
    full_name = (validated.get("full_name") or validated.get("name") or email).strip()

    submitted_username = validated.get("username")
    if submitted_username:
        username = access.validate_username(submitted_username)
    else:
        username = access.suggest_username(full_name=full_name, email=email)["username"]

    # Older clients may still submit a password at this stage. Validate basic
    # shape for compatibility, then discard it completely; it is never written
    # to the Pending Registration document or Frappe's password store.
    submitted_password = validated.get("password") or validated.get("new_password")
    if submitted_password and len(submitted_password) < 8:
        frappe.throw("Password must be at least 8 characters long", frappe.ValidationError)

    if frappe.db.exists("User", email) or frappe.db.exists("OMC Customer Profile", {"email": email}):
        frappe.throw("Registration is not available for these details.", frappe.DuplicateEntryError)
    if frappe.db.exists("OMC Customer Profile", {"username": username}):
        frappe.throw("Registration is not available for these details.", frappe.DuplicateEntryError)

    _supersede_existing(email, username)

    token = secrets.token_urlsafe(32)
    now = now_datetime()
    payload = _public_payload(validated)
    payload["username"] = username
    payload["email"] = email

    doc = frappe.new_doc(PENDING_REGISTRATION_DOCTYPE)
    doc.email = email
    doc.username = username
    doc.status = "Pending"
    doc.expires_at = add_to_date(now, minutes=TOKEN_TTL_MINUTES)
    doc.resend_after = add_to_date(now, seconds=RESEND_COOLDOWN_SECONDS)
    doc.token_digest = _token_digest(token)
    doc.payload_json = json.dumps(payload, ensure_ascii=False, sort_keys=True)
    doc.insert(ignore_permissions=True)

    return PendingRegistrationSecret(doc.name, token)


@frappe.whitelist(allow_guest=True, methods=["POST"])
def start_registration(**kwargs):
    actor = str(kwargs.get("email") or kwargs.get("user") or "").strip().lower()
    security.enforce_rate_limit("signup", actor=actor)
    try:
        secret = create_pending_registration(dict(kwargs or {}))
    except frappe.DuplicateEntryError:
        return {**_resend_payload(), "verification_required": True, "password_required_after_verification": True}

    doc = frappe.get_doc(PENDING_REGISTRATION_DOCTYPE, secret.registration_name)
    _send_verification_email(doc.email, doc.username, secret.verification_token)
    frappe.db.commit()
    return {
        **_resend_payload(resend_after=doc.resend_after),
        "verification_required": True,
        "password_required_after_verification": True,
    }


@frappe.whitelist(allow_guest=True, methods=["POST"])
def resend_verification(email: str | None = None):
    normalized_email = str(email or "").strip().lower()
    security.enforce_rate_limit("token_resend", actor=normalized_email)
    if not normalized_email:
        return _resend_payload()

    doc = _existing_pending({"email": normalized_email})
    if not doc:
        return _resend_payload()

    if doc.resend_after and get_datetime(doc.resend_after) > now_datetime():
        return _resend_payload(resend_after=doc.resend_after)

    token = _rotate_token(doc)
    _send_verification_email(doc.email, doc.username, token)
    frappe.db.commit()
    return _resend_payload(resend_after=doc.resend_after)


def _lookup_by_token(token: str, *, for_update: bool = False):
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
    if for_update:
        locked = frappe.db.get_value(PENDING_REGISTRATION_DOCTYPE, name, "name", for_update=True)
        if not locked:
            return None
    return frappe.get_doc(PENDING_REGISTRATION_DOCTYPE, name)


def inspect_verification_token(token: str | None = None) -> dict:
    """Read-only token inspection safe for email-link GET requests/link scanners."""
    token = str(token or "").strip()
    if not token:
        return {"ok": False, "status": "invalid_or_expired"}
    doc = _lookup_by_token(token)
    if not doc or doc.status not in ACTIVE_PENDING_STATUSES:
        return {"ok": False, "status": "invalid_or_expired"}
    if get_datetime(doc.expires_at) <= now_datetime():
        return {"ok": False, "status": "invalid_or_expired"}
    return {
        "ok": True,
        "status": "awaiting_password",
        "email": str(doc.email or "").strip().lower(),
        "username": str(doc.username or "").strip(),
    }


@frappe.whitelist(allow_guest=True)
def get_registration_verification_status(token: str | None = None):
    security.enforce_rate_limit("identity", actor=_token_digest(str(token or "")))
    result = inspect_verification_token(token)
    return {
        "ok": bool(result.get("ok")),
        "status": result.get("status", "invalid_or_expired"),
        "message": (
            "Email verified. Set your password to complete account creation."
            if result.get("ok")
            else "This verification link is invalid or has expired."
        ),
    }


def _validated_completion_password(password: str | None) -> str:
    password = str(password or "")
    if len(password) < 8:
        frappe.throw("Password must be at least 8 characters long", frappe.ValidationError)
    if len(password) > 128:
        frappe.throw("Password must be 128 characters or fewer", frappe.ValidationError)
    return password



def _create_profile_acquisition_attribution(
    profile,
    account,
):
    """Create the correct acquisition attribution for one profile.

    Historical ERP provenance is never converted into customer-granted
    referral consent. Explicit application referrals retain the existing
    consent-based attribution path.
    """

    if not profile or not account:
        return None

    referral_record = str(
        getattr(profile, "referral_record", "") or ""
    ).strip()

    if not referral_record:
        return None

    onboarding_mode = str(
        getattr(profile, "onboarding_mode", "") or ""
    ).strip()

    erp_customer = str(
        getattr(profile, "linked_erpnext_customer", "") or ""
    ).strip()

    consent_granted = bool(
        int(
            getattr(
                profile,
                "referral_assistance_consent",
                0,
            )
            or 0
        )
    )

    from omc_app.api import referral_attribution

    if (
        onboarding_mode == "Existing Customer Claim"
        and erp_customer
        and not consent_granted
    ):
        from omc_app.api import erp_customer_resolver

        historical = (
            erp_customer_resolver
            ._reconcile_claim_historical_referral(
                profile,
                erp_customer,
            )
        )

        historical_persona = str(
            historical.get("historical_persona") or ""
        ).strip()

        historical_referral = str(
            historical.get("referral_record") or ""
        ).strip()

        if (
            historical.get("action")
            in {"linked", "already_linked"}
            and historical_referral == referral_record
            and historical_persona
        ):
            return (
                referral_attribution
                .create_historical_acquisition_snapshot(
                    referral_registry=referral_record,
                    erp_customer=erp_customer,
                    historical_persona=historical_persona,
                )
            )

        # Never fall through to the consent-based path when this is an
        # unconsented historical ERP relationship that cannot currently
        # be proven.
        return None

    return referral_attribution.create_snapshot(
        referral_registry=referral_record,
        customer_account=account.name,
        attribution_type="Acquisition",
    )


def _complete_locked_registration(doc, password: str) -> dict:
    from omc_app.api import mobile

    if doc.status not in ACTIVE_PENDING_STATUSES:
        return {"ok": False, "status": "invalid_or_expired"}
    if get_datetime(doc.expires_at) <= now_datetime():
        sanitize_registration(doc, status="Expired")
        doc.save(ignore_permissions=True)
        frappe.db.commit()
        return {"ok": False, "status": "invalid_or_expired"}

    payload = read_pending_payload(doc)
    payload["password"] = password
    payload["username"] = doc.username
    payload["email"] = doc.email

    user_exists = bool(frappe.db.exists("User", doc.email))
    profile_name = frappe.db.get_value("OMC Customer Profile", {"email": doc.email}, "name")
    profile_exists = bool(profile_name)
    if user_exists != profile_exists:
        security.audit_event(
            event_type="registration.partial_identity_detected",
            target_doctype=PENDING_REGISTRATION_DOCTYPE,
            target_name=doc.name,
            safe_reason="partial_identity",
        )
        frappe.throw(
            "Registration cannot be completed automatically. Contact OMC support.",
            frappe.ValidationError,
        )

    doc.status = "Verified"
    doc.verified_at = doc.verified_at or now_datetime()
    doc.save(ignore_permissions=True)

    if not user_exists:
        previous_defer = getattr(frappe.flags, "omc_defer_signup_commit", False)
        frappe.flags.omc_defer_signup_commit = True
        try:
            mobile.sign_up(**payload)
        finally:
            frappe.flags.omc_defer_signup_commit = previous_defer

    account = identity.ensure_customer_account_from_legacy(doc.email)
    if not account:
        profile_name = frappe.db.get_value("OMC Customer Profile", {"email": doc.email}, "name")
        account = frappe.get_doc({
            "doctype": "OMC Customer Account",
            "user": doc.email,
            "legacy_customer_profile": profile_name,
            "identity_proof_status": "Verified",
            "account_link_status": "Unlinked",
            "service_access_status": "Pending Review",
            "mapping_provenance": "Activation",
            "mapping_confidence": "",
            "source_version": identity.source_version(doc.name, doc.verified_at, doc.email),
            "last_reconciled_at": now_datetime(),
        })
        account.insert(ignore_permissions=True)
    else:
        account.mapping_provenance = "Activation"
        account.save(ignore_permissions=True)

    profile_name = frappe.db.get_value(
        "OMC Customer Profile",
        {"email": doc.email},
        "name",
    )

    if profile_name:
        profile = frappe.get_doc(
            "OMC Customer Profile",
            profile_name,
        )
        _create_profile_acquisition_attribution(
            profile,
            account,
        )

    doc.reload()
    doc.activated_user = doc.email if frappe.db.exists("User", doc.email) else None
    sanitize_registration(doc, status="Activated")
    doc.save(ignore_permissions=True)
    security.audit_event(
        event_type="registration.activated",
        target_doctype=PENDING_REGISTRATION_DOCTYPE,
        target_name=doc.name,
        new_state="activated",
    )
    frappe.db.commit()
    return {
        "ok": True,
        "status": "activated",
        "message": "Your account is ready. You can sign in now.",
    }


@frappe.whitelist(allow_guest=True, methods=["POST"])
def complete_registration(token: str | None = None, password: str | None = None, new_password: str | None = None):
    token = str(token or "").strip()
    security.enforce_rate_limit("identity", actor=_token_digest(token))
    if not token:
        return {"ok": False, "status": "invalid_or_expired", "message": "This verification link is invalid or has expired."}

    password = _validated_completion_password(password or new_password)
    doc = _lookup_by_token(token, for_update=True)
    if not doc:
        return {"ok": False, "status": "invalid_or_expired", "message": "This verification link is invalid or has expired."}
    result = _complete_locked_registration(doc, password)
    if not result.get("ok"):
        result["message"] = "This verification link is invalid or has expired."
    return result


@frappe.whitelist(allow_guest=True, methods=["POST"])
def verify_registration(token: str | None = None, password: str | None = None, new_password: str | None = None):
    """Backward-compatible route; account creation is POST-only and needs password."""
    return complete_registration(token=token, password=password, new_password=new_password)


def _verification_result_page(result: dict, token: str = "") -> tuple[str, str, str]:
    valid = bool((result or {}).get("ok")) and result.get("status") == "awaiting_password"
    if valid:
        title = "Email verified"
        message = "Open the OMC House app and set your password to complete account creation."
        app_url = verification_links(token)["app_url"]
        accent = "#0f766e"
        icon = "&#10003;"
    else:
        title = "Verification link unavailable"
        message = "This verification link is invalid or has expired."
        app_url = "omchouse://auth/login?verification=invalid"
        accent = "#b45309"
        icon = "!"

    safe_title = frappe.utils.escape_html(title)
    safe_message = frappe.utils.escape_html(message)
    safe_app_url = frappe.utils.escape_html(app_url)
    html = f"""
    <div style="min-height:100vh;background:#f4f7fb;padding:32px 16px;font-family:Arial,sans-serif;box-sizing:border-box;">
      <div style="max-width:560px;margin:48px auto;background:#ffffff;border:1px solid #e5e7eb;border-radius:24px;box-shadow:0 18px 50px rgba(15,23,42,.08);padding:40px 32px;text-align:center;">
        <div style="width:72px;height:72px;border-radius:50%;margin:0 auto 22px;background:{accent}18;color:{accent};display:flex;align-items:center;justify-content:center;font-size:36px;font-weight:800;">{icon}</div>
        <div style="font-size:12px;font-weight:800;letter-spacing:.12em;text-transform:uppercase;color:#64748b;">OMC House</div>
        <h1 style="margin:12px 0;color:#0f172a;font-size:30px;line-height:1.2;">{safe_title}</h1>
        <p style="margin:0 auto;color:#475569;font-size:16px;line-height:1.65;max-width:430px;">{safe_message}</p>
        <a href="{safe_app_url}" style="display:inline-block;margin-top:28px;background:{accent};color:#ffffff;text-decoration:none;font-weight:800;padding:14px 24px;border-radius:12px;">Open OMC App</a>
      </div>
    </div>
    """
    return title, html, "green" if valid else "orange"


@frappe.whitelist(allow_guest=True)
def verify_registration_web(token: str | None = None):
    # Deliberately read-only. Email scanners and GET requests must never create
    # accounts, consume a token, or persist verification state.
    token = str(token or "").strip()
    security.enforce_rate_limit("identity", actor=_token_digest(token))
    result = inspect_verification_token(token)
    title, html, indicator = _verification_result_page(result, token)
    frappe.respond_as_web_page(
        title=title,
        html=html,
        indicator_color=indicator,
        http_status_code=200,
    )


def load_pending_registration_by_token(token: str):
    """Compatibility helper; token lookup is read-only."""
    doc = _lookup_by_token(token)
    if not doc or doc.status not in ACTIVE_PENDING_STATUSES:
        return None
    if get_datetime(doc.expires_at) <= now_datetime():
        return None
    return doc


def read_pending_payload(doc) -> dict:
    return json.loads(doc.payload_json or "{}")


def read_pending_password(doc) -> str:
    frappe.throw(
        "Pending registration passwords are no longer stored. Supply the password to complete_registration().",
        frappe.ValidationError,
    )
