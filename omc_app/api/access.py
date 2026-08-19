import re

import frappe
from frappe.utils import validate_email_address

from omc_app.api import capabilities as capability_policy
from omc_app.api import identity, mobile, security, staff_profile
from omc_app.setup.roles import (
    ACTIVE_PORTAL_ROLES,
    ACTIVE_STAFF_ROLES,
    ADMIN_ROLE,
    BUSINESS_PARTNER_ROLE,
    CONSULTANT_ROLE,
    CUSTOMER_ROLE,
    DOCUMENT_REVIEWER_ROLE,
    FINANCE_REVIEWER_ROLE,
    MANAGER_ROLE,
    SUPPORT_AGENT_ROLE,
    TAX_ASSOCIATE_ROLE,
)

# Frappe System Manager is an infrastructure role, not OMC business authority.
INTERNAL_ROLES = set(ACTIVE_STAFF_ROLES)
ADMIN_ROLES = {ADMIN_ROLE}

INTERNAL_CAPABILITY_KEYS = capability_policy.INTERNAL_CAPABILITY_KEYS

ROLE_CAPABILITIES = {
    ADMIN_ROLE: set(INTERNAL_CAPABILITY_KEYS),
    MANAGER_ROLE: set(INTERNAL_CAPABILITY_KEYS)
    - {
        "can_manage_settings",
        "can_manage_staff",
        "can_review_registrations",
        "can_manage_business_settings",
    },
    SUPPORT_AGENT_ROLE: {
        "can_access_internal_workspace",
        "can_manage_leads",
        "can_view_support_tickets",
        "can_reply_support_tickets",
        "can_update_support_ticket_status",
        "can_assign_support_tickets",
        "can_view_relevant_customers",
        "can_view_relevant_service_cases",
        "can_view_internal_notes",
        "can_manage_assigned_tasks",
        "can_create_service_for_customer",
    },
    DOCUMENT_REVIEWER_ROLE: {
        "can_access_internal_workspace",
        "can_view_document_queue",
        "can_view_document_summaries",
        "can_view_document_attachments",
        "can_review_documents",
        "can_view_relevant_customers",
        "can_view_relevant_service_cases",
        "can_view_internal_notes",
        "can_manage_assigned_tasks",
    },
    FINANCE_REVIEWER_ROLE: {
        "can_access_internal_workspace",
        "can_view_payment_queue",
        "can_view_payment_summaries",
        "can_view_payment_receipts",
        "can_review_payments",
        "can_reconcile_settlement",
        "can_approve_post_paid",
        "can_view_referral_commissions",
        "can_approve_commissions",
        "can_mark_commissions_paid",
        "can_view_relevant_customers",
        "can_view_relevant_service_cases",
        "can_view_internal_notes",
        "can_manage_assigned_tasks",
    },
    CONSULTANT_ROLE: {
        "can_access_internal_workspace",
        "can_create_service_for_customer",
        "can_view_assigned_service_cases",
        "can_update_assigned_service_status",
        "can_manage_assigned_tasks",
        "can_view_relevant_customers",
        "can_view_document_summaries",
        "can_view_document_attachments",
        "can_view_internal_notes",
        "can_view_referral_commissions",
    },
    TAX_ASSOCIATE_ROLE: {
        "can_access_internal_workspace",
        "can_create_service_for_customer",
        "can_view_assigned_service_cases",
        "can_update_assigned_service_status",
        "can_manage_assigned_tasks",
        "can_view_relevant_customers",
        "can_view_document_summaries",
        "can_view_document_attachments",
        "can_view_internal_notes",
        "can_view_referral_commissions",
    },
    BUSINESS_PARTNER_ROLE: {
        "can_access_internal_workspace",
        "can_create_service_for_customer",
        "can_view_assigned_service_cases",
        "can_update_assigned_service_status",
        "can_manage_assigned_tasks",
        "can_view_relevant_customers",
        "can_view_document_summaries",
        "can_view_document_attachments",
        "can_view_internal_notes",
        "can_view_referral_commissions",
    },
}

SIGNUP_TEXT_LIMITS = {
    "full_name": 140,
    "name": 140,
    "phone": 40,
    "mobile": 40,
    "whatsapp_no": 40,
    "whatsapp": 40,
    "company_name": 140,
    "company": 140,
    "cnic": 40,
    "ntn": 40,
    "register_as": 80,
    "customer_type": 80,
    "address": 500,
    "education": 500,
    "experience": 1000,
    "remarks": 2000,
    "notes": 2000,
    "acquisition_source": 80,
    "acquisition_source_detail": 500,
    "referral_code": 40,
    "submitted_referral_code": 40,
    "referral_consent_version": 40,
    "username": 30,
}


_RESERVED_USERNAMES = {
    "admin",
    "administrator",
    "api",
    "app",
    "help",
    "login",
    "logout",
    "omc",
    "omchouse",
    "root",
    "support",
    "system",
    "user",
    "www",
}
_USERNAME_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._]{2,28}[a-z0-9]$")


def normalize_username(value):
    text = str(value or "").strip().lower()
    text = re.sub(r"[^a-z0-9._]+", ".", text)
    return re.sub(r"[._]{2,}", ".", text).strip("._")


def validate_username(value):
    username = normalize_username(value)
    if not username or not _USERNAME_PATTERN.fullmatch(username):
        frappe.throw(
            "Username must be 4 to 30 characters using lowercase letters, numbers, dots or underscores.",
            frappe.ValidationError,
        )
    if username in _RESERVED_USERNAMES:
        frappe.throw("This username is reserved.", frappe.ValidationError)
    return username


def username_exists(username):
    username = normalize_username(username)
    return bool(
        username
        and (
            frappe.db.exists("OMC Customer Profile", {"username": username})
            or frappe.db.exists("OMC Staff Profile", {"username": username})
            or frappe.db.exists("User", username)
        )
    )


@frappe.whitelist(allow_guest=True)
def suggest_username(full_name=None, email=None):
    security.enforce_rate_limit("identity", actor=str(email or "guest"))
    source = str(full_name or "").strip() or str(email or "").split("@", 1)[0]
    base = normalize_username(source) or "omc.user"
    if len(base) < 4:
        base = f"{base}.user"
    base = base[:30].strip("._")
    candidate = base
    suffix = 1
    while username_exists(candidate) or candidate in _RESERVED_USERNAMES:
        suffix += 1
        tail = f".{suffix}"
        candidate = f"{base[:30-len(tail)]}{tail}"
    return {"username": candidate, "available": True}


@frappe.whitelist(allow_guest=True)
def check_username_availability(username=None):
    security.enforce_rate_limit("identity", actor=str(username or "guest"))
    normalized = validate_username(username)
    return {"username": normalized, "available": not username_exists(normalized)}


def _current_user():
    user = frappe.session.user if getattr(frappe, "session", None) else "Guest"
    return user or "Guest"


def _roles(user=None):
    user = user or _current_user()
    if not user or user == "Guest":
        return set()
    return set(frappe.get_roles(user) or [])


def is_internal_user(user=None):
    """Classify internal identity without implying authorization."""
    user = user or _current_user()

    if not user or user == "Guest":
        return False

    return bool(
        user == "Administrator"
        or identity.user_type(user) == "System User"
        or identity.get_staff_access(user)
    )


def get_effective_omc_staff_roles(user=None):
    user = user or _current_user()
    return staff_profile.get_effective_staff_roles(user)


def is_approved_staff(user=None):
    user = user or _current_user()

    if not user or user == "Guest":
        return False

    if user == "Administrator":
        return True
    staff = identity.get_staff_access(user)
    return bool(
        staff
        and identity.user_is_enabled(user)
        and staff.access_status == "Approved"
        and staff.reconciliation_status == "Current"
    )


def can_access_internal_workspace(user=None):
    return bool(is_internal_user(user) and is_approved_staff(user))


def _pending_internal_capabilities():
    capabilities = {
        "access_state": "pending",
        "is_guest": False,
        "is_pending": True,
        "is_approved_customer": False,
        "can_view_public_catalogue": True,
        "can_view_public_content": True,
        "can_use_tax_calculator": True,
        "can_create_service_request": False,
        "can_upload_documents": False,
        "can_track_requests": False,
        "can_view_documents": False,
        "can_view_payments": False,
        "can_upload_payment_receipt": False,
        "can_upload_payment_receipts": False,
        "can_create_support_ticket": False,
        "can_view_customer_dashboard": False,
        "can_access_customer_dashboard": False,
        "can_view_customer_notifications": False,
    }
    capabilities.update({key: False for key in INTERNAL_CAPABILITY_KEYS})
    return capabilities


def _canonical_capabilities(user=None):
    user = user or _current_user()

    if not is_internal_user(user):
        return None
    return capability_policy.effective(user)


def _bounded_signup_text(value, fieldname, max_length):
    text = str(value or "").strip()
    if len(text) > max_length:
        frappe.throw(
            f"{fieldname} must be {max_length} characters or fewer",
            frappe.ValidationError,
        )
    return text


def _validated_signup_kwargs(kwargs):
    data = dict(kwargs or {})
    email = _bounded_signup_text(
        data.get("email") or data.get("user"),
        "email",
        254,
    ).lower()
    if not email or not validate_email_address(email, throw=False):
        frappe.throw("A valid email address is required", frappe.ValidationError)

    password = data.get("password") or data.get("new_password")
    if password is not None and not isinstance(password, str):
        frappe.throw("Password must be text", frappe.ValidationError)
    if password and len(password) > 128:
        frappe.throw(
            "Password must be 128 characters or fewer",
            frappe.ValidationError,
        )

    data["email"] = email
    if "username" in data:
        data["username"] = validate_username(data.get("username"))
    for fieldname, max_length in SIGNUP_TEXT_LIMITS.items():
        if fieldname in data:
            data[fieldname] = _bounded_signup_text(
                data.get(fieldname),
                fieldname,
                max_length,
            )
    return data


@frappe.whitelist(allow_guest=True, methods=["POST"])
def sign_up(**kwargs):
    """Validate public input before delegating to the mobile signup workflow."""
    data = _validated_signup_kwargs(kwargs)
    security.enforce_rate_limit("signup", actor=data.get("email"))
    return mobile.sign_up(**data)


@frappe.whitelist()
def get_mobile_capabilities(user=None):
    user = user or _current_user()
    return capability_policy.effective(user)


@frappe.whitelist()
def get_session_user():
    user = _current_user()
    roles = sorted(_roles(user))
    capabilities = get_mobile_capabilities(user=user)

    return {
        "user": user,
        "is_guest": user == "Guest",
        "roles": roles,
        "access_state": capabilities.get("access_state"),
        "capabilities": capabilities,
        **capabilities,
    }
