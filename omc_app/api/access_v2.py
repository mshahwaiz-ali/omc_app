import frappe

from omc_app.api import access as canonical_access
from omc_app.api import mobile


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


def _capabilities(user=None, profile=None):
    """Return capabilities from the canonical access engine.

    ``profile`` is retained for backward compatibility with older callers of
    this module. Capability decisions are intentionally delegated to
    ``omc_app.api.access`` so role and account-state rules have one authority.
    """
    del profile
    return canonical_access.get_mobile_capabilities(user=user)


def _patch_payload(data):
    if not isinstance(data, dict):
        return data

    user = data.get("user") or data.get("user_id") or data.get("email") or _current_user()
    capabilities = _capabilities(user=user)

    data["roles"] = sorted(_roles(user))
    data["access_state"] = capabilities["access_state"]
    data["can_access_internal_workspace"] = capabilities[
        "can_access_internal_workspace"
    ]
    data["capabilities"] = capabilities

    if isinstance(data.get("profile"), dict):
        data["profile"]["capabilities"] = capabilities
        data["profile"]["access_state"] = capabilities["access_state"]
        data["profile"]["can_access_internal_workspace"] = capabilities[
            "can_access_internal_workspace"
        ]

    return data


def _patch_response(response):
    if isinstance(response, dict) and isinstance(response.get("message"), dict):
        response["message"] = _patch_payload(response["message"])
        return response
    return _patch_payload(response)


@frappe.whitelist(allow_guest=True)
def get_session_user():
    return _patch_response(mobile.get_session_user())


@frappe.whitelist()
def get_profile():
    from omc_app.api import profile as profile_api

    return _patch_response(profile_api.get_profile())


@frappe.whitelist(allow_guest=True)
def get_mobile_capabilities():
    return _capabilities()
