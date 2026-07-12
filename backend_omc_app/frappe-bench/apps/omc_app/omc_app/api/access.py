import frappe

from omc_app.api import mobile
from omc_app.setup.roles import (
    ACTIVE_PORTAL_ROLES,
    ADMIN_ROLE,
    CUSTOMER_ROLE,
    LEGACY_CLIENT_ROLES,
    LEGACY_ROLES,
    MANAGER_ROLE,
    SYSTEM_ROLE,
)

INTERNAL_ROLES = {SYSTEM_ROLE, ADMIN_ROLE, MANAGER_ROLE}
ADMIN_ROLES = {SYSTEM_ROLE, ADMIN_ROLE}
MANAGER_ROLES = ADMIN_ROLES | {MANAGER_ROLE}


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
    is_guest = not user or user == "Guest"
    is_internal = bool(roles.intersection(INTERNAL_ROLES))
    is_admin = bool(roles.intersection(ADMIN_ROLES))
    is_manager = bool(roles.intersection(MANAGER_ROLES))

    if not is_internal:
        return None

    return {
        "access_state": "internal",
        "is_guest": is_guest,
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
        "can_view_support_tickets": False,
        "can_view_customer_dashboard": False,
        "can_access_customer_dashboard": False,
        "can_view_customer_notifications": False,
        "can_access_internal_workspace": True,
        "can_update_service_status": is_manager,
        "can_review_documents": is_manager,
        "can_review_payments": is_manager,
        "can_update_support_ticket_status": is_manager,
        "can_manage_customers": is_manager,
        "can_manage_leads": is_manager,
        "can_manage_tasks": is_manager,
        "can_view_internal_notes": True,
        "can_manage_settings": is_admin or MANAGER_ROLE in roles,
    }


@frappe.whitelist(allow_guest=True)
def sign_up(**kwargs):
    """Public signup creates/keeps a customer profile only.

    Register-as/customer-type values stay as profile metadata. They never become
    permission roles. The only role assigned by public signup is OMC Customer,
    and existing internal users keep their internal roles.
    """
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
            "System User"
            if final_roles.intersection(INTERNAL_ROLES)
            else "Website User"
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
