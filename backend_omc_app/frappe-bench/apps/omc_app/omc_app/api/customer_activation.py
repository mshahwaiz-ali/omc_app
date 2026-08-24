from __future__ import annotations

import hashlib
import math
import secrets

import frappe
from frappe import _
from frappe.exceptions import ValidationError
from frappe.utils import add_to_date, escape_html, get_datetime, now_datetime

from omc_app.api import access, identity, security
from omc_app.api.auth_links import customer_activation_links


DOCTYPE = "OMC Customer Activation"
TOKEN_TTL_MINUTES = 30
REQUEST_COOLDOWN_SECONDS = 60
IDENTIFIER_MAX_LENGTH = 254

GENERIC_MESSAGE = (
    "If an eligible imported OMC customer account matches this email, "
    "activation instructions will be sent shortly."
)

ELIGIBLE_MANUAL_STATUSES = {
    "",
    "Unregistered",
    "Invited",
    "Signup Pending",
}


def _digest(token: str) -> str:
    return hashlib.sha256(
        str(token or "").encode("utf-8")
    ).hexdigest()


def _generic_payload(*, resend_after=None) -> dict:
    # Public activation requests must not reveal whether an imported
    # customer profile exists or whether a request was actually queued.
    return {
        "message": GENERIC_MESSAGE,
        "cooldown_seconds": REQUEST_COOLDOWN_SECONDS,
    }


def _email_html(
    full_name: str,
    app_url: str,
    web_url: str,
) -> str:
    safe_name = escape_html(full_name or "Customer")
    safe_app_url = escape_html(app_url)
    safe_web_url = escape_html(web_url)

    return f"""
    <div style="background:#f5f7fa;padding:32px 16px;
                font-family:Arial,sans-serif;">
      <div style="max-width:560px;margin:0 auto;background:#ffffff;
                  border:1px solid #e5e7eb;border-radius:18px;
                  padding:32px;">
        <div style="font-size:13px;font-weight:700;letter-spacing:.08em;
                    color:#64748b;text-transform:uppercase;">
          OMC
        </div>

        <h1 style="margin:12px 0 8px;color:#0f172a;
                   font-size:26px;line-height:1.2;">
          Activate your OMC account
        </h1>

        <p style="margin:0 0 18px;color:#475569;
                  font-size:15px;line-height:1.6;">
          Hello {safe_name}, your existing OMC customer record can be
          linked to the OMC app. Use the secure link below to choose
          your password and activate app access.
        </p>

        <a href="{safe_web_url}"
           style="display:inline-block;background:#0f766e;
                  color:#ffffff;text-decoration:none;font-weight:700;
                  padding:13px 20px;border-radius:10px;">
          Activate account
        </a>

        <p style="margin:16px 0 0;color:#64748b;
                  font-size:13px;line-height:1.55;">
          Using the OMC app?
          <a href="{safe_app_url}"
             style="color:#0f766e;font-weight:700;">
            Open in app
          </a>.
        </p>

        <p style="margin:12px 0 0;color:#64748b;
                  font-size:13px;line-height:1.55;">
          This link expires in {TOKEN_TTL_MINUTES} minutes.
          If you did not request activation, ignore this email.
        </p>
      </div>
    </div>
    """


def _send_activation_email(
    email: str,
    full_name: str,
    token: str,
) -> None:
    if frappe.are_emails_muted():
        return

    links = customer_activation_links(token)

    frappe.sendmail(
        recipients=[email],
        subject="Activate your OMC account",
        message=_email_html(
            full_name,
            links["universal_url"],
            links["web_url"],
        ),
        now=True,
    )


def _eligible_profile(email: str):
    profile_name = frappe.db.get_value(
        "OMC Customer Profile",
        {"email": email},
        "name",
    )
    if not profile_name:
        return None

    profile = frappe.get_doc(
        "OMC Customer Profile",
        profile_name,
    )

    if str(profile.get("customer_origin") or "") != "Imported":
        return None

    if str(profile.get("customer_status") or "") != "Active":
        return None

    if str(profile.get("approval_status") or "") != "Approved":
        return None

    if not int(profile.get("is_active") or 0):
        return None

    if profile.get("user") or profile.get("linked_app_user"):
        return None

    manual_status = str(
        profile.get("manual_customer_status") or ""
    ).strip()

    if manual_status not in ELIGIBLE_MANUAL_STATUSES:
        return None

    customer = str(profile.get("linked_erpnext_customer") or "").strip()
    if not customer or not frappe.db.exists("Customer", customer):
        return None
    if frappe.db.count("OMC Customer Profile", {"linked_erpnext_customer": customer}) != 1:
        return None

    return profile


def _latest_request(profile_name: str):
    rows = frappe.get_all(
        DOCTYPE,
        filters={"customer_profile": profile_name},
        fields=[
            "name",
            "status",
            "requested_at",
            "expires_at",
        ],
        order_by="requested_at desc",
        limit=1,
    )
    return rows[0] if rows else None


def _cooldown_until(profile_name: str):
    row = _latest_request(profile_name)
    if not row or not row.get("requested_at"):
        return None

    return add_to_date(
        get_datetime(row["requested_at"]),
        seconds=REQUEST_COOLDOWN_SECONDS,
    )


def _supersede_pending(profile_name: str) -> None:
    names = frappe.get_all(
        DOCTYPE,
        filters={
            "customer_profile": profile_name,
            "status": "Pending",
        },
        pluck="name",
    )

    for name in names:
        doc = frappe.get_doc(DOCTYPE, name)
        doc.status = "Superseded"
        doc.token_digest = secrets.token_hex(32)
        doc.save(ignore_permissions=True)


def _create_activation(profile) -> tuple[str, object]:
    _supersede_pending(profile.name)

    token = secrets.token_urlsafe(32)
    now = now_datetime()

    doc = frappe.get_doc(
        {
            "doctype": DOCTYPE,
            "customer_profile": profile.name,
            "email": str(profile.email or "").strip().lower(),
            "status": "Pending",
            "expires_at": add_to_date(
                now,
                minutes=TOKEN_TTL_MINUTES,
            ),
            "token_digest": _digest(token),
            "requested_at": now,
        }
    )
    doc.insert(ignore_permissions=True)

    return token, doc


@frappe.whitelist(allow_guest=True, methods=["POST"])
def request_activation(email: str | None = None):
    normalized_email = str(email or "").strip().lower()
    security.enforce_rate_limit("identity", actor=normalized_email)

    if (
        not normalized_email
        or len(normalized_email) > IDENTIFIER_MAX_LENGTH
        or "@" not in normalized_email
    ):
        return _generic_payload()

    profile = _eligible_profile(normalized_email)
    if not profile:
        return _generic_payload()

    # Never auto-merge an existing Frappe identity into an imported
    # customer profile. This is intentionally deferred to manual review.
    if frappe.db.exists("User", normalized_email):
        return _generic_payload()

    cooldown_until = _cooldown_until(profile.name)
    if (
        cooldown_until
        and get_datetime(cooldown_until) > now_datetime()
    ):
        return _generic_payload(
            resend_after=cooldown_until,
        )

    token, doc = _create_activation(profile)

    _send_activation_email(
        normalized_email,
        profile.full_name,
        token,
    )

    frappe.db.commit()

    return _generic_payload(
        resend_after=add_to_date(
            doc.requested_at,
            seconds=REQUEST_COOLDOWN_SECONDS,
        )
    )


def _load_activation(token: str):
    token = str(token or "").strip()
    if not token:
        return None

    name = frappe.db.get_value(
        DOCTYPE,
        {"token_digest": _digest(token)},
        "name",
    )
    if not name:
        return None

    # Prevent two concurrent requests from consuming the same token.
    frappe.db.sql(
        f"""
        SELECT name
        FROM `tab{DOCTYPE}`
        WHERE name = %s
        FOR UPDATE
        """,
        (name,),
    )

    doc = frappe.get_doc(DOCTYPE, name)

    if doc.status != "Pending":
        return None

    if get_datetime(doc.expires_at) <= now_datetime():
        doc.status = "Expired"
        doc.token_digest = secrets.token_hex(32)
        doc.save(ignore_permissions=True)
        frappe.db.commit()
        return None

    return doc


def _mark_review_required(doc, reason: str) -> dict:
    doc.status = "Review Required"
    doc.review_reason = reason
    doc.token_digest = secrets.token_hex(32)
    doc.save(ignore_permissions=True)

    profile = frappe.get_doc(
        "OMC Customer Profile",
        doc.customer_profile,
    )

    if (
        reason == "existing_user_identity"
        and profile.meta.has_field("manual_customer_status")
    ):
        profile.manual_customer_status = "Duplicate Review"
        profile.save(ignore_permissions=True)

    frappe.db.commit()

    return {
        "ok": False,
        "status": "review_required",
        "message": (
            "This account requires OMC review before app access "
            "can be activated."
        ),
    }


def _invalid_result() -> dict:
    return {
        "ok": False,
        "status": "invalid_or_expired",
        "message": (
            "This activation link is invalid or has expired."
        ),
    }


@frappe.whitelist(allow_guest=True, methods=["POST"])
def complete_activation(
    token: str | None = None,
    password: str | None = None,
    confirm_password: str | None = None,
):
    security.enforce_rate_limit("identity", actor=_digest(str(token or "")))
    secret = str(password or "")
    confirmation = str(confirm_password or "")

    if len(secret) < 8:
        frappe.throw(
            _("Password must be at least 8 characters."),
            ValidationError,
        )

    if secret != confirmation:
        frappe.throw(
            _("Passwords do not match."),
            ValidationError,
        )

    savepoint = "omc_customer_activation"
    frappe.db.savepoint(savepoint)

    try:
        doc = _load_activation(str(token or ""))
        if not doc:
            return _invalid_result()

        profile = frappe.get_doc(
            "OMC Customer Profile",
            doc.customer_profile,
        )

        # Re-check the full eligibility contract at consumption time.
        eligible = _eligible_profile(
            str(doc.email or "").strip().lower()
        )
        if not eligible or eligible.name != profile.name:
            return _mark_review_required(
                doc,
                "profile_no_longer_activation_eligible",
            )

        email = str(profile.email or "").strip().lower()

        # Never guess or merge identities.
        if frappe.db.exists("User", email):
            return _mark_review_required(
                doc,
                "existing_user_identity",
            )

        erp_customer = str(profile.get("linked_erpnext_customer") or "").strip()
        if frappe.db.exists("OMC Customer Account", {"user": email}) or frappe.db.exists(
            "OMC Customer Account", {"erp_customer": erp_customer}
        ):
            return _mark_review_required(doc, "customer_account_already_linked")

        from omc_app.api import mobile

        full_name = (
            str(profile.full_name or "").strip()
            or email
        )

        user = frappe.new_doc("User")
        user.email = email
        user.first_name = full_name
        user.full_name = full_name
        user.enabled = 1
        user.send_welcome_email = 0
        user.user_type = "Website User"
        user.insert(ignore_permissions=True)

        user.new_password = secret
        user.save(ignore_permissions=True)

        # Verify the new Website User without mutating Has Role.
        mobile._normalize_signup_user(user)

        if profile.meta.has_field("username"):
            current_username = str(
                profile.get("username") or ""
            ).strip()

            if not current_username:
                profile.username = access.suggest_username(
                    full_name=full_name,
                    email=email,
                )["username"]

        profile.user = email
        profile.email = email

        if profile.meta.has_field("linked_app_user"):
            profile.linked_app_user = email

        if profile.meta.has_field("manual_customer_status"):
            profile.manual_customer_status = "Linked"

        # Business approval is not recreated by activation.
        # Existing imported customer lifecycle remains authoritative.
        profile.save(ignore_permissions=True)

        account = identity.ensure_customer_account_from_legacy(email)
        if not account:
            return _mark_review_required(doc, "customer_account_link_ambiguous")
        account.mapping_provenance = "Activation"
        account.save(ignore_permissions=True)

        doc.status = "Used"
        doc.used_at = now_datetime()
        doc.activated_user = email
        doc.review_reason = ""
        doc.token_digest = secrets.token_hex(32)
        doc.save(ignore_permissions=True)

        frappe.clear_cache(user=email)
        frappe.db.commit()

        return {
            "ok": True,
            "status": "activated",
            "user": email,
            "customer_profile": profile.name,
            "message": (
                "Your OMC account is activated. "
                "You can sign in now."
            ),
        }

    except Exception:
        frappe.db.rollback(save_point=savepoint)
        raise
