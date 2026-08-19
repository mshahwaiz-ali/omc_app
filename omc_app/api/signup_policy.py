from __future__ import annotations

import frappe
from omc_app.api import pending_registration
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


@frappe.whitelist(allow_guest=True, methods=["POST"])
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

    # Both historical public method names are overridden to this function.
    # Preserve compatibility, but never create a User or customer profile until
    # the emailed token is consumed by verify_registration().
    return pending_registration.start_registration(**data)
