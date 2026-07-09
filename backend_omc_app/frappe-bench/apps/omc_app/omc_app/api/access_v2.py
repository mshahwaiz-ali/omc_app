import frappe

from omc_app.api import mobile


PORTAL_ROLES = {"OMC Customer", "OMC Business Partner", "OMC Tax Associate"}
STAFF_ROLES = {"OMC Admin", "OMC Manager"}
SYSTEM_ROLES = {"System Manager"}
INTERNAL_ROLES = STAFF_ROLES | SYSTEM_ROLES


def _current_user():
    user = frappe.session.user if getattr(frappe, "session", None) else "Guest"
    return user or "Guest"


def _roles(user=None):
    user = user or _current_user()
    if not user or user == "Guest":
        return set()
    return set(frappe.get_roles(user) or [])


def _profile_for_user(user=None):
    try:
        return mobile._get_customer_profile_for_user(user)
    except Exception:
        return None


def _profile_status(profile):
    if not profile:
        return "", ""
    return (profile.customer_status or "").strip().lower(), (profile.approval_status or "").strip().lower()


def _is_approved(profile):
    customer_status, approval_status = _profile_status(profile)
    return customer_status == "active" and approval_status == "approved"


def _access_state(user, user_roles, profile):
    if not user or user == "Guest":
        return "guest"
    if user_roles.intersection(INTERNAL_ROLES):
        return "internal"
    if _is_approved(profile):
        return "approved"
    customer_status, approval_status = _profile_status(profile)
    if customer_status == "rejected" or approval_status == "rejected":
        return "rejected"
    return "pending"


def _capabilities(user=None, profile=None):
    user = user or _current_user()
    user_roles = _roles(user)
    profile = profile if profile is not None else _profile_for_user(user)

    is_guest = not user or user == "Guest"
    is_internal = bool(user_roles.intersection(INTERNAL_ROLES))
    is_admin = bool(user_roles.intersection(SYSTEM_ROLES | {"OMC Admin"}))
    is_manager = bool(user_roles.intersection({"OMC Manager"}))
    is_staff = is_admin or is_manager
    approved = _is_approved(profile)
    access_state = _access_state(user, user_roles, profile)

    payments_enabled = True
    try:
        payments_enabled = mobile._settings_bool(
            mobile._get_single_settings("OMC Mobile Settings"),
            "payments_enabled",
            True,
        )
    except Exception:
        payments_enabled = True

    return {
        "access_state": access_state,
        "is_guest": is_guest,
        "is_pending": access_state == "pending",
        "is_approved_customer": approved,
        "can_view_public_catalogue": True,
        "can_view_public_content": True,
        "can_use_tax_calculator": True,
        "can_create_service_request": approved,
        "can_upload_documents": approved,
        "can_track_requests": approved,
        "can_view_documents": approved,
        "can_view_payments": approved,
        "can_upload_payment_receipt": approved and payments_enabled,
        "can_upload_payment_receipts": approved and payments_enabled,
        "can_create_support_ticket": approved,
        "can_view_support_tickets": approved,
        "can_view_customer_dashboard": approved,
        "can_access_customer_dashboard": approved,
        "can_view_customer_notifications": approved,
        "can_access_internal_workspace": is_internal,
        "can_update_service_status": is_staff,
        "can_review_documents": is_staff,
        "can_review_payments": is_staff,
        "can_update_support_ticket_status": is_staff,
        "can_manage_customers": is_admin or is_manager,
        "can_manage_leads": is_admin or is_manager,
        "can_manage_tasks": is_admin or is_manager,
        "can_view_internal_notes": is_internal,
    }


def _patch_payload(data):
    if not isinstance(data, dict):
        return data

    user = data.get("user") or data.get("user_id") or data.get("email") or _current_user()
    profile = _profile_for_user(user)
    capabilities = _capabilities(user=user, profile=profile)

    data["roles"] = sorted(_roles(user))
    data["access_state"] = capabilities["access_state"]
    data["can_access_internal_workspace"] = capabilities["can_access_internal_workspace"]
    data["capabilities"] = capabilities

    if isinstance(data.get("profile"), dict):
        data["profile"]["capabilities"] = capabilities
        data["profile"]["access_state"] = capabilities["access_state"]

    return data


@frappe.whitelist(allow_guest=True)
def get_session_user():
    response = mobile.get_session_user()
    if isinstance(response, dict) and isinstance(response.get("message"), dict):
        response["message"] = _patch_payload(response["message"])
        return response
    return _patch_payload(response)


@frappe.whitelist(allow_guest=True)
def get_mobile_capabilities():
    return _capabilities()
