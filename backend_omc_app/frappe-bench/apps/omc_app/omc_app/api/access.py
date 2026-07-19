import frappe

from omc_app.api import mobile
from omc_app.setup.roles import (
    ACTIVE_PORTAL_ROLES,
    ACTIVE_STAFF_ROLES,
    ADMIN_ROLE,
    BUSINESS_PARTNER_ROLE,
    CONSULTANT_ROLE,
    CUSTOMER_ROLE,
    DOCUMENT_REVIEWER_ROLE,
    FINANCE_REVIEWER_ROLE,
    LEGACY_CLIENT_ROLES,
    LEGACY_ROLES,
    MANAGER_ROLE,
    SUPPORT_AGENT_ROLE,
    SYSTEM_ROLE,
    TAX_ASSOCIATE_ROLE,
)

INTERNAL_ROLES = {SYSTEM_ROLE} | ACTIVE_STAFF_ROLES
ADMIN_ROLES = {SYSTEM_ROLE, ADMIN_ROLE}

INTERNAL_CAPABILITY_KEYS = (
    "can_access_internal_workspace",
    "can_manage_customers",
    "can_view_all_customers",
    "can_view_relevant_customers",
    "can_manage_leads",
    "can_manage_tasks",
    "can_manage_assigned_tasks",
    "can_view_all_service_cases",
    "can_view_relevant_service_cases",
    "can_view_assigned_service_cases",
    "can_create_service_for_customer",
    "can_update_service_status",
    "can_update_assigned_service_status",
    "can_view_document_queue",
    "can_view_document_summaries",
    "can_view_document_attachments",
    "can_review_documents",
    "can_view_payment_queue",
    "can_view_payment_summaries",
    "can_view_payment_receipts",
    "can_review_payments",
    "can_view_support_tickets",
    "can_reply_support_tickets",
    "can_update_support_ticket_status",
    "can_assign_support_tickets",
    "can_view_internal_notes",
    "can_manage_settings",
)

ROLE_CAPABILITIES = {
    ADMIN_ROLE: set(INTERNAL_CAPABILITY_KEYS),
    MANAGER_ROLE: set(INTERNAL_CAPABILITY_KEYS) - {"can_manage_settings"},
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
        "can_view_relevant_customers",
        "can_view_relevant_service_cases",
        "can_view_internal_notes",
        "can_manage_assigned_tasks",
    },
    CONSULTANT_ROLE: {
        "can_access_internal_workspace",
        "can_view_assigned_service_cases",
        "can_update_assigned_service_status",
        "can_manage_assigned_tasks",
        "can_view_relevant_customers",
        "can_view_document_summaries",
        "can_view_document_attachments",
        "can_view_internal_notes",
    },
    TAX_ASSOCIATE_ROLE: {
        "can_access_internal_workspace",
        "can_view_assigned_service_cases",
        "can_update_assigned_service_status",
        "can_manage_assigned_tasks",
        "can_view_relevant_customers",
        "can_view_document_summaries",
        "can_view_document_attachments",
        "can_view_internal_notes",
    },
    BUSINESS_PARTNER_ROLE: {
        "can_access_internal_workspace",
        "can_view_assigned_service_cases",
        "can_update_assigned_service_status",
        "can_manage_assigned_tasks",
        "can_view_relevant_customers",
        "can_view_document_summaries",
        "can_view_document_attachments",
        "can_view_internal_notes",
    },
}


def _current_user():
    user = frappe.session.user if getattr(frappe, "session", None) else "Guest"
    return user or "Guest"


def _roles(user=None):
    user = user or _current_user()
    if not user or user == "Guest":
        return set()
    return set(frappe.get_roles(user) or [])


def is_internal_user(user=None):
    return bool(_roles(user).intersection(INTERNAL_ROLES))


def _normalize_user_roles(user_id):
    if not user_id or user_id in {"Guest", "Administrator"}:
        return
    if not frappe.db.exists("User", user_id):
        return

    roles = _roles(user_id)
    user_doc = frappe.get_doc("User", user_id)
    existing = {row.role for row in (user_doc.roles or [])}

    if roles.intersection(LEGACY_CLIENT_ROLES) and CUSTOMER_ROLE not in existing:
        user_doc.append("roles", {"role": CUSTOMER_ROLE})

    user_doc.roles = [row for row in user_doc.roles if row.role not in LEGACY_ROLES]
    final_roles = {row.role for row in user_doc.roles}

    if final_roles.intersection(INTERNAL_ROLES):
        user_doc.user_type = "System User"
    elif final_roles.intersection(ACTIVE_PORTAL_ROLES):
        user_doc.user_type = "Website User"

    user_doc.save(ignore_permissions=True)
    frappe.clear_cache(user=user_id)


def _canonical_capabilities(user=None):
    user = user or _current_user()
    roles = _roles(user)
    if not roles.intersection(INTERNAL_ROLES):
        return None

    enabled = {"can_access_internal_workspace"}
    if SYSTEM_ROLE in roles:
        enabled.update(INTERNAL_CAPABILITY_KEYS)
    for role in roles:
        enabled.update(ROLE_CAPABILITIES.get(role, set()))

    capabilities = {
        "access_state": "internal",
        "is_guest": False,
        "is_pending": False,
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
    capabilities.update({key: key in enabled for key in INTERNAL_CAPABILITY_KEYS})
    return capabilities


@frappe.whitelist(allow_guest=True)
def sign_up(**kwargs):
    result = mobile.sign_up(**kwargs)
    email = (
        (result.get("user") or {}).get("email")
        or kwargs.get("email")
        or kwargs.get("user")
        or ""
    ).strip().lower()

    if email and frappe.db.exists("User", email):
        user_doc = frappe.get_doc("User", email)
        existing = {row.role for row in (user_doc.roles or [])}
        is_internal_account = bool(existing.intersection(INTERNAL_ROLES))

        if (
            not is_internal_account
            and frappe.db.exists("Role", CUSTOMER_ROLE)
            and CUSTOMER_ROLE not in existing
        ):
            user_doc.append("roles", {"role": CUSTOMER_ROLE})

        user_doc.roles = [row for row in user_doc.roles if row.role not in LEGACY_ROLES]
        final_roles = {row.role for row in user_doc.roles}
        user_doc.user_type = (
            "System User" if final_roles.intersection(INTERNAL_ROLES) else "Website User"
        )
        user_doc.save(ignore_permissions=True)
        frappe.clear_cache(user=email)
        frappe.db.commit()

    if isinstance(result, dict):
        result["access_state"] = (
            "pending" if result.get("access_state") != "approved" else "approved"
        )
        result["capabilities"] = (
            get_mobile_capabilities(user=email)
            if email
            else result.get("capabilities")
        )

    return result


@frappe.whitelist()
def get_mobile_capabilities(user=None):
    user = user or _current_user()
    _normalize_user_roles(user)

    canonical = _canonical_capabilities(user)
    if canonical is not None:
        return canonical

    return mobile._get_mobile_capabilities(user=user)


@frappe.whitelist()
def get_session_user():
    user = _current_user()
    _normalize_user_roles(user)
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
