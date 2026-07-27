from __future__ import annotations

import frappe

from omc_app.api import access, mobile
from omc_app.referral_capabilities import (
    ALL_CUSTOMER_ASSIST_ROLES,
    WALK_IN_CUSTOMER_ROLES,
)

CUSTOMER_MODES = {
    "Self",
    "My Referral",
    "Existing Customer",
    "Walk-in Customer",
}


def _text(value) -> str:
    return str(value or "").strip()


def _current_user() -> str:
    user = mobile._current_user()
    if not user or user == "Guest":
        frappe.throw("Login is required.", frappe.PermissionError)
    return user


def _roles(user: str) -> set[str]:
    return set(frappe.get_roles(user) or [])


def _capabilities(user: str) -> dict:
    return access.get_mobile_capabilities(user=user)


def _require_internal_assist(user: str) -> dict:
    capabilities = _capabilities(user)
    if not capabilities.get("can_access_internal_workspace"):
        frappe.throw(
            "You do not have permission to access internal workspace data.",
            frappe.PermissionError,
        )
    if not capabilities.get("can_create_service_for_customer"):
        frappe.throw(
            "You do not have permission to create service requests for customers.",
            frappe.PermissionError,
        )
    return capabilities


def _service_doc(service_id: str):
    service_id = _text(service_id)
    if not service_id:
        frappe.throw("service_id is required", frappe.ValidationError)

    service_name = (
        frappe.db.get_value("OMC Service", {"service_id": service_id}, "name")
        or service_id
    )
    if not frappe.db.exists("OMC Service", service_name):
        frappe.throw("Service not found", frappe.DoesNotExistError)
    return frappe.get_doc("OMC Service", service_name)


def _profile(customer_profile: str):
    customer_profile = _text(customer_profile)
    if not customer_profile:
        frappe.throw("customer_profile is required", frappe.ValidationError)
    if not frappe.db.exists("OMC Customer Profile", customer_profile):
        frappe.throw("Customer profile not found", frappe.DoesNotExistError)
    return frappe.get_doc("OMC Customer Profile", customer_profile)


def _resolve_my_referral(user: str, customer_profile: str):
    profile = _profile(customer_profile)
    if _text(profile.referred_by) != user:
        frappe.throw(
            "This customer is not linked to your referral account.",
            frappe.PermissionError,
        )
    if not profile.referral_record:
        frappe.throw(
            "This customer does not have an active referral relationship.",
            frappe.PermissionError,
        )
    if not int(profile.referral_assistance_consent or 0):
        frappe.throw(
            "Customer referral assistance consent is required.",
            frappe.PermissionError,
        )
    if not int(profile.is_active or 0):
        frappe.throw("Customer profile is inactive.", frappe.PermissionError)
    return profile


def _resolve_existing_customer(
    user: str,
    customer_profile: str,
    consent_reference: str,
):
    if not _roles(user).intersection(ALL_CUSTOMER_ASSIST_ROLES):
        frappe.throw(
            "You do not have permission to create requests for arbitrary customers.",
            frappe.PermissionError,
        )
    if not _text(consent_reference):
        frappe.throw(
            "customer_consent_reference is required.",
            frappe.ValidationError,
        )
    profile = _profile(customer_profile)
    if not int(profile.is_active or 0):
        frappe.throw("Customer profile is inactive.", frappe.PermissionError)
    return profile


def _create_manual_customer(user: str, kwargs: dict):
    if not _roles(user).intersection(WALK_IN_CUSTOMER_ROLES):
        frappe.throw(
            "You do not have permission to create walk-in customers.",
            frappe.PermissionError,
        )

    full_name = _text(kwargs.get("full_name") or kwargs.get("customer_name"))
    mobile_no = _text(
        kwargs.get("mobile")
        or kwargs.get("phone")
        or kwargs.get("contact_phone")
    )
    email = _text(kwargs.get("email") or kwargs.get("contact_email"))
    cnic = _text(kwargs.get("cnic"))

    if not full_name:
        frappe.throw("Full name is required.", frappe.ValidationError)
    if not mobile_no and not email:
        frappe.throw(
            "Enter customer mobile or email.",
            frappe.ValidationError,
        )

    doc = frappe.new_doc("OMC Manual Customer")
    doc.full_name = full_name
    doc.mobile = mobile_no
    doc.email = email
    doc.cnic = cnic
    doc.address = _text(kwargs.get("address"))
    doc.city = _text(kwargs.get("city"))
    doc.notes = _text(kwargs.get("notes") or kwargs.get("note"))
    doc.created_by_user = user
    doc.referral_owner = user
    doc.verification_status = "Unverified"
    doc.conversion_status = "Unregistered"
    doc.customer_origin = "Walk-in"
    doc.insert(ignore_permissions=True)
    return doc


def _request_response(doc) -> dict:
    return {
        "name": doc.name,
        "request_id": doc.name,
        "service_request": doc.name,
        "case_id": doc.name,
        "status": doc.status,
        "created": True,
        "message": "Service request created.",
        "customer_mode": doc.customer_mode or "",
        "submission_mode": doc.submission_mode or "",
        "customer_profile": doc.customer_profile or "",
        "manual_customer": doc.manual_customer or "",
    }


def create_request(**kwargs):
    user = _current_user()
    is_internal = mobile._can_access_internal_workspace(user)
    service = _service_doc(kwargs.get("service_id") or kwargs.get("service"))

    if not is_internal:
        profile = mobile._assert_approved_customer()
        customer_mode = "Self"
        submission_mode = "Customer Self-Service"
        manual_customer = None
        consent_reference = ""
    else:
        _require_internal_assist(user)
        customer_mode = _text(kwargs.get("customer_mode"))
        if customer_mode not in CUSTOMER_MODES - {"Self"}:
            frappe.throw(
                "A valid assisted customer_mode is required.",
                frappe.ValidationError,
            )

        consent_reference = _text(kwargs.get("customer_consent_reference"))
        manual_customer = None

        if customer_mode == "My Referral":
            profile = _resolve_my_referral(
                user,
                kwargs.get("customer_profile") or kwargs.get("customer_id"),
            )
            submission_mode = "Staff on Behalf"
            consent_reference = (
                consent_reference
                or _text(profile.referral_consent_timestamp)
                or profile.name
            )
        elif customer_mode == "Existing Customer":
            profile = _resolve_existing_customer(
                user,
                kwargs.get("customer_profile") or kwargs.get("customer_id"),
                consent_reference,
            )
            submission_mode = "Admin on Behalf"
        else:
            profile = None
            manual_customer = _create_manual_customer(user, kwargs)
            submission_mode = "Walk-in Assisted"
            consent_reference = consent_reference or manual_customer.name

    full_name = _text(kwargs.get("full_name") or kwargs.get("customer_name"))
    contact_email = _text(kwargs.get("contact_email") or kwargs.get("email"))
    contact_phone = _text(kwargs.get("contact_phone") or kwargs.get("phone"))

    if profile:
        full_name = full_name or _text(profile.full_name)
        contact_email = contact_email or _text(profile.email)
        contact_phone = contact_phone or _text(profile.phone)
    elif manual_customer:
        full_name = full_name or _text(manual_customer.full_name)
        contact_email = contact_email or _text(manual_customer.email)
        contact_phone = contact_phone or _text(manual_customer.mobile)

    doc = frappe.new_doc("OMC Service Request")
    doc.service = service.name
    doc.service_title = service.title or ""
    doc.title = _text(kwargs.get("title")) or service.title or "Service Request"
    doc.description = kwargs.get("description") or ""
    doc.priority = kwargs.get("priority") or "Medium"
    doc.status = "Open"
    doc.customer_profile = profile.name if profile else ""
    doc.requested_for_customer = (
        _text(profile.linked_app_user)
        or _text(profile.user)
        if profile
        else ""
    )
    doc.manual_customer = manual_customer.name if manual_customer else ""
    doc.customer_name = full_name
    doc.contact_email = contact_email
    doc.contact_phone = contact_phone
    doc.customer_mode = customer_mode
    doc.submission_mode = submission_mode
    doc.submitted_by_user = user
    doc.submitted_by_internal_user = user if is_internal else ""
    doc.created_on_behalf = 1 if is_internal else 0
    doc.customer_consent_reference = consent_reference
    doc.source_channel = _text(kwargs.get("source_channel")) or "Mobile App"

    if profile and customer_mode == "My Referral":
        doc.referral_owner = profile.referred_by
        doc.referral_record = profile.referral_record

    doc.assigned_staff = _text(kwargs.get("assigned_staff"))
    doc.insert(ignore_permissions=True)

    mobile._create_service_timeline_entry(
        service_request=doc.name,
        event_type="Request Created",
        title="Request Created by OMC" if is_internal else "Request Created",
        description=(
            _text(kwargs.get("note"))
            or (
                "OMC team created this service request."
                if is_internal
                else "Your service request has been created successfully."
            )
        ),
        visible_to_customer=1,
    )

    frappe.db.commit()
    return _request_response(doc)
