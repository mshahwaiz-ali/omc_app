from __future__ import annotations

import secrets

import frappe
from frappe.utils import now_datetime

from omc_app.referral_capabilities import REFERRAL_OWNER_ROLES

CODE_PREFIX = "OMC-"
CODE_LENGTH = 6
CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
MAX_GENERATION_ATTEMPTS = 20
ACTIVE_STATUSES = {"Approved", "Registered", "Converted"}


def _current_user() -> str:
    user = frappe.session.user if getattr(frappe, "session", None) else "Guest"
    return user or "Guest"


def _roles(user: str | None = None) -> set[str]:
    user = user or _current_user()
    if not user or user == "Guest":
        return set()
    return set(frappe.get_roles(user) or [])


def _require_login() -> str:
    user = _current_user()
    if user == "Guest":
        frappe.throw("Login is required.", frappe.PermissionError)
    return user


def _require_referral_owner() -> str:
    user = _require_login()
    if not _roles(user).intersection(REFERRAL_OWNER_ROLES):
        frappe.throw(
            "You do not have permission to manage a referral code.",
            frappe.PermissionError,
        )
    return user


def _customer_profile_for_user(user: str):
    for filters in (
        {"linked_app_user": user},
        {"user": user},
        {"email": user},
    ):
        name = frappe.db.get_value("OMC Customer Profile", filters, "name")
        if name:
            return frappe.get_doc("OMC Customer Profile", name)
    return None


def normalize_referral_code(value: str | None) -> str:
    text = str(value or "").strip().upper().replace(" ", "")
    if not text:
        return ""
    if not text.startswith(CODE_PREFIX):
        text = f"{CODE_PREFIX}{text}"
    return text


def _is_valid_code_shape(value: str) -> bool:
    if not value.startswith(CODE_PREFIX):
        return False
    suffix = value[len(CODE_PREFIX):]
    return len(suffix) == CODE_LENGTH and all(ch in CODE_ALPHABET for ch in suffix)


def _generate_candidate() -> str:
    suffix = "".join(secrets.choice(CODE_ALPHABET) for _ in range(CODE_LENGTH))
    return f"{CODE_PREFIX}{suffix}"


def generate_unique_referral_code() -> str:
    for _ in range(MAX_GENERATION_ATTEMPTS):
        candidate = _generate_candidate()
        if not frappe.db.exists("OMC Referral", {"referral_code": candidate}):
            return candidate
    frappe.throw(
        "Unable to generate a unique referral code. Please try again.",
        frappe.ValidationError,
    )


def _get_owner_record(user: str) -> str | None:
    return frappe.db.get_value("OMC Referral", {"referrer_user": user}, "name")


def _owner_record_to_dict(doc) -> dict:
    return {
        "name": doc.name,
        "referral_code": doc.referral_code,
        "status": doc.status or "",
        "is_active": int(doc.is_active or 0),
        "referrer_user": doc.referrer_user,
        "created_at": str(doc.creation or ""),
        "modified_at": str(doc.modified or ""),
    }


def get_or_create_owner_record(user: str | None = None):
    user = user or _require_referral_owner()
    existing = _get_owner_record(user)
    if existing:
        return frappe.get_doc("OMC Referral", existing)

    doc = frappe.new_doc("OMC Referral")
    doc.referral_code = generate_unique_referral_code()
    doc.referrer_user = user
    doc.status = "Approved"
    doc.is_active = 1
    doc.source = "Staff Created"
    doc.approved_date = now_datetime()
    doc.insert(ignore_permissions=True)
    return doc


def resolve_active_referral(code: str | None):
    normalized = normalize_referral_code(code)
    if not normalized or not _is_valid_code_shape(normalized):
        return None

    name = frappe.db.get_value("OMC Referral", {"referral_code": normalized}, "name")
    if not name:
        return None

    doc = frappe.get_doc("OMC Referral", name)
    if not int(doc.is_active or 0):
        return None
    if (doc.status or "").strip() not in ACTIVE_STATUSES:
        return None

    user_enabled = frappe.db.get_value("User", doc.referrer_user, "enabled")
    if not int(user_enabled or 0):
        return None

    if not _roles(doc.referrer_user).intersection(REFERRAL_OWNER_ROLES):
        return None

    return doc


@frappe.whitelist(allow_guest=True)
def validate_referral_code(referral_code: str | None = None):
    normalized = normalize_referral_code(referral_code)
    record = resolve_active_referral(normalized)
    return {
        "valid": bool(record),
        "referral_code": normalized if record else "",
        "message": "Referral code verified." if record else "Referral code is invalid or inactive.",
    }


@frappe.whitelist()
def get_my_referral_summary():
    user = _require_referral_owner()
    record = get_or_create_owner_record(user)
    filters = {"referred_by": user, "referral_record": record.name}
    total = frappe.db.count("OMC Customer Profile", filters=filters)
    consented = frappe.db.count(
        "OMC Customer Profile",
        filters={**filters, "referral_assistance_consent": 1},
    )
    active = frappe.db.count(
        "OMC Customer Profile",
        filters={**filters, "is_active": 1},
    )
    return {
        "referral": _owner_record_to_dict(record),
        "counts": {
            "total_referrals": total,
            "consented_referrals": consented,
            "active_referrals": active,
        },
    }


@frappe.whitelist()
def get_my_referrals(search: str | None = None, limit_start: int = 0, limit_page_length: int = 20):
    user = _require_referral_owner()
    record = get_or_create_owner_record(user)

    try:
        limit_start = max(int(limit_start or 0), 0)
        limit_page_length = min(max(int(limit_page_length or 20), 1), 100)
    except (TypeError, ValueError):
        frappe.throw("Invalid pagination values.", frappe.ValidationError)

    filters = {"referred_by": user, "referral_record": record.name}
    or_filters = None
    term = str(search or "").strip()
    if term:
        like = f"%{term}%"
        or_filters = {
            "name": ["like", like],
            "full_name": ["like", like],
            "email": ["like", like],
            "phone": ["like", like],
            "cnic": ["like", like],
        }

    rows = frappe.get_all(
        "OMC Customer Profile",
        filters=filters,
        or_filters=or_filters,
        fields=[
            "name",
            "full_name",
            "email",
            "phone",
            "customer_status",
            "approval_status",
            "referral_assistance_consent",
            "customer_origin",
            "linked_app_user",
            "modified",
        ],
        order_by="modified desc",
        limit_start=limit_start,
        limit_page_length=limit_page_length,
    )

    return {
        "items": [
            {
                "customer_id": row.name,
                "full_name": row.full_name or "",
                "email": row.email or "",
                "phone": row.phone or "",
                "customer_status": row.customer_status or "",
                "approval_status": row.approval_status or "",
                "consent_granted": int(row.referral_assistance_consent or 0),
                "customer_origin": row.customer_origin or "",
                "linked_app_user": row.linked_app_user or "",
                "modified": str(row.modified or ""),
            }
            for row in rows
        ],
        "limit_start": limit_start,
        "limit_page_length": limit_page_length,
    }


@frappe.whitelist()
def revoke_my_referral_assistance_consent():
    user = _require_login()
    profile = _customer_profile_for_user(user)
    if not profile:
        frappe.throw("Customer profile not found.", frappe.DoesNotExistError)

    had_consent = int(profile.referral_assistance_consent or 0)
    profile.referral_assistance_consent = 0
    profile.save(ignore_permissions=True)

    return {
        "success": True,
        "customer_id": profile.name,
        "consent_granted": 0,
        "consent_was_active": had_consent,
        "referral_relationship_preserved": bool(
            profile.referral_record or profile.referred_by
        ),
        "message": (
            "Referral assistance access has been revoked."
            if had_consent
            else "Referral assistance access was already revoked."
        ),
    }


def apply_referral_to_customer(
    customer_profile,
    referral_code: str,
    *,
    consent_granted: bool,
    consent_timestamp=None,
):
    record = resolve_active_referral(referral_code)
    if not record:
        frappe.throw("Referral code is invalid or inactive.", frappe.ValidationError)
    if not consent_granted:
        frappe.throw("Referral assistance consent is required.", frappe.ValidationError)

    customer_profile.acquisition_source = "Referral"
    customer_profile.referral_record = record.name
    customer_profile.referred_by = record.referrer_user
    customer_profile.referral_code_used = record.referral_code
    customer_profile.referral_assistance_consent = 1
    customer_profile.referral_consent_timestamp = consent_timestamp or now_datetime()
    return record
