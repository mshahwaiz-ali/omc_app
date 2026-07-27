from __future__ import annotations

import frappe
from frappe.utils import now_datetime

from omc_app.api import access
from omc_app.referral_automation import resolve_eligible_referral


CUSTOMER_TYPES = {"customer", "omc customer"}


def _text(value) -> str:
    return str(value or "").strip()


def _is_customer_registration(data: dict) -> bool:
    register_as = _text(data.get("register_as") or "Customer").lower()
    customer_type = _text(data.get("customer_type") or register_as or "Customer").lower()
    return register_as in CUSTOMER_TYPES and customer_type in CUSTOMER_TYPES


def _submitted_referral_code(data: dict) -> str:
    return _text(data.get("referral_code") or data.get("submitted_referral_code"))


def _profile_name_for_email(email: str):
    return (
        frappe.db.get_value("OMC Customer Profile", {"user": email}, "name")
        or frappe.db.get_value("OMC Customer Profile", {"linked_app_user": email}, "name")
        or frappe.db.get_value("OMC Customer Profile", {"email": email}, "name")
    )


def _approve_customer_profile(email: str):
    profile_name = _profile_name_for_email(email)
    if not profile_name:
        frappe.throw("Customer profile was not created.", frappe.ValidationError)

    profile = frappe.get_doc("OMC Customer Profile", profile_name)
    profile.customer_status = "Active"
    profile.approval_status = "Approved"
    profile.is_active = 1
    if profile.meta.has_field("approved_date") and not profile.get("approved_date"):
        profile.approved_date = now_datetime()
    profile.save(ignore_permissions=True)
    return profile


@frappe.whitelist(allow_guest=True)
def sign_up(**kwargs):
    data = dict(kwargs or {})
    email = _text(data.get("email") or data.get("user")).lower()
    referral_code = _submitted_referral_code(data)
    is_customer = _is_customer_registration(data)

    if referral_code and not is_customer:
        frappe.throw(
            "Referral codes can only be used for customer registration.",
            frappe.ValidationError,
        )

    if referral_code and not resolve_eligible_referral(referral_code):
        frappe.throw("Referral code is invalid or inactive.", frappe.ValidationError)

    result = access.sign_up(**data)

    if not is_customer:
        return result

    profile = _approve_customer_profile(email)
    frappe.db.commit()

    result = dict(result or {})
    profile_data = dict(result.get("profile") or {})
    profile_data.update(
        {
            "customer_id": profile.name,
            "customer_status": "Active",
            "approval_status": "Approved",
        }
    )
    result["profile"] = profile_data
    result["access_state"] = "approved"
    result["capabilities"] = access.get_mobile_capabilities(user=email)
    return result
