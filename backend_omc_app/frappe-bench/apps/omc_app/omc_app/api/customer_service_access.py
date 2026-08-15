import frappe

from omc_app.api import access, mobile


def _current_user():
    user = frappe.session.user if getattr(frappe, "session", None) else "Guest"
    return user or "Guest"


def _text(value):
    return str(value or "").strip()


def _is_internal(user=None):
    return mobile._can_access_internal_workspace(user or _current_user())


def _customer_profile_for_current_user():
    return mobile._assert_approved_customer()


def _assert_internal_capability(capability, *, user=None):
    user = user or _current_user()
    capabilities = access.get_mobile_capabilities(user=user)

    if not capabilities.get("can_manage_customer_service_flow"):
        frappe.throw(
            "Your role cannot manage customer service requests.",
            frappe.PermissionError,
        )

    if capability and not capabilities.get(capability):
        frappe.throw(
            "Your role cannot perform this customer service action.",
            frappe.PermissionError,
        )

    return capabilities


def _internal_scope_type(service_case, *, user, capabilities, profile=None):
    # Admin/manager-style users with global case visibility may assist any case,
    # but the action-specific capability is still required separately.
    if capabilities.get("can_view_all_service_cases"):
        return "all_cases"

    mode = _text(getattr(service_case, "customer_mode", None))

    if (
        mode == "My Referral"
        and _text(getattr(service_case, "referral_owner", None)) == user
    ):
        return "my_referral"

    if (
        profile
        and _text(getattr(profile, "referred_by", None)) == user
        and int(getattr(profile, "referral_assistance_consent", 0) or 0)
    ):
        return "my_referral"

    if (
        mode == "Walk-in Customer"
        and bool(getattr(service_case, "created_on_behalf", 0))
        and _text(getattr(service_case, "submitted_by_internal_user", None)) == user
    ):
        return "walk_in_assisted"

    frappe.throw(
        "You do not have permission to manage this customer's service request.",
        frappe.PermissionError,
    )


def assert_service_request_action(
    service_request,
    *,
    internal_capability,
):
    """Authorize a customer-self or customer-on-behalf service action.

    Returns:
        {
            "service_case": OMC Service Request doc,
            "profile": customer profile doc or None,
            "is_internal": bool,
            "scope_type": str,
            "capabilities": dict,
        }
    """

    case_id = _text(service_request)
    if not case_id or not frappe.db.exists("OMC Service Request", case_id):
        frappe.throw("Service request not found", frappe.DoesNotExistError)

    service_case = frappe.get_doc("OMC Service Request", case_id)
    user = _current_user()

    if not _is_internal(user):
        profile = _customer_profile_for_current_user()

        if (
            service_case.customer_profile
            and service_case.customer_profile != profile.name
        ):
            frappe.throw(
                "You do not have permission to manage this service request.",
                frappe.PermissionError,
            )

        return {
            "service_case": service_case,
            "profile": profile,
            "is_internal": False,
            "scope_type": "self",
            "capabilities": access.get_mobile_capabilities(user=user),
        }

    capabilities = _assert_internal_capability(
        internal_capability,
        user=user,
    )

    profile = None
    if service_case.customer_profile and frappe.db.exists(
        "OMC Customer Profile",
        service_case.customer_profile,
    ):
        profile = frappe.get_doc(
            "OMC Customer Profile",
            service_case.customer_profile,
        )

    scope_type = _internal_scope_type(
        service_case,
        user=user,
        capabilities=capabilities,
        profile=profile,
    )

    return {
        "service_case": service_case,
        "profile": profile,
        "is_internal": True,
        "scope_type": scope_type,
        "capabilities": capabilities,
    }


def accessible_assisted_service_request_names(*, internal_capability):
    """Return only service requests this internal actor may manage on behalf."""

    user = _current_user()
    if not _is_internal(user):
        return set()

    capabilities = _assert_internal_capability(
        internal_capability,
        user=user,
    )

    if capabilities.get("can_view_all_service_cases"):
        return set(
            frappe.get_all(
                "OMC Service Request",
                pluck="name",
            )
        )

    names = set()

    names.update(
        frappe.get_all(
            "OMC Service Request",
            filters={
                "customer_mode": "My Referral",
                "referral_owner": user,
            },
            pluck="name",
        )
    )

    names.update(
        frappe.get_all(
            "OMC Service Request",
            filters={
                "customer_mode": "Walk-in Customer",
                "created_on_behalf": 1,
                "submitted_by_internal_user": user,
            },
            pluck="name",
        )
    )

    return names
