"""Unified mobile service request APIs.

This module keeps the normal app Services flow usable for approved customers and
OMC internal users. Customers create requests for their own approved profile.
Internal users create the same request object from the same form by entering the
customer/contact information manually.
"""

import frappe

from omc_app.api import mobile


@frappe.whitelist()
def create_service(**kwargs):
    """Create an OMC Service Request from the normal Services request form."""

    user = mobile._current_user()
    if user == "Guest":
        frappe.throw(
            "Please create an account or login to request this service.",
            frappe.PermissionError,
        )

    is_internal = mobile._can_access_internal_workspace(user)
    profile = None

    if is_internal:
        mobile._assert_internal_workspace_access()
    else:
        profile = mobile._assert_approved_customer()

    service_id = (kwargs.get("service_id") or kwargs.get("service") or "").strip()
    if not service_id:
        frappe.throw("service_id is required")

    service_name = frappe.db.get_value("OMC Service", {"service_id": service_id}, "name") or service_id
    if not frappe.db.exists("OMC Service", service_name):
        frappe.throw("Service not found", frappe.DoesNotExistError)

    service_doc = frappe.get_doc("OMC Service", service_name)
    linked_profile = _resolve_linked_profile(kwargs) if is_internal else profile

    full_name = _text(kwargs.get("full_name") or kwargs.get("customer_name"))
    contact_email = _text(kwargs.get("contact_email") or kwargs.get("email"))
    contact_phone = _text(kwargs.get("contact_phone") or kwargs.get("phone"))

    if linked_profile:
        full_name = full_name or (linked_profile.full_name or "")
        contact_email = contact_email or (linked_profile.email or "")
        contact_phone = contact_phone or (linked_profile.phone or "")

    if is_internal:
        if not full_name:
            frappe.throw("Full name is required for internal service requests.")
        if not contact_phone and not contact_email:
            frappe.throw("Enter customer phone or email before submitting.")

    title = _text(kwargs.get("title")) or service_doc.title or "Service Request"

    doc = frappe.new_doc("OMC Service Request")
    doc.service = service_name
    doc.service_title = service_doc.title or ""
    doc.title = title
    doc.description = kwargs.get("description") or ""
    doc.priority = kwargs.get("priority") or "Medium"
    doc.status = "Open"
    doc.customer_profile = linked_profile.name if linked_profile else ""
    doc.customer_name = full_name
    doc.contact_email = contact_email
    doc.contact_phone = contact_phone
    doc.insert(ignore_permissions=True)

    mobile._create_service_timeline_entry(
        service_request=doc.name,
        event_type="Request Created",
        title="Request Created by OMC" if is_internal else "Request Created",
        description=(
            "OMC team created this service request from the app."
            if is_internal
            else "Your service request has been created successfully."
        ),
        visible_to_customer=1,
    )

    frappe.db.commit()

    return {
        "name": doc.name,
        "request_id": doc.name,
        "service_request": doc.name,
        "case_id": doc.name,
        "status": doc.status,
        "created": True,
        "message": "Service request created.",
    }


def _resolve_linked_profile(kwargs):
    customer_profile = _text(
        kwargs.get("customer_profile")
        or kwargs.get("customer_id")
        or kwargs.get("customer")
    )
    if customer_profile and frappe.db.exists("OMC Customer Profile", customer_profile):
        return frappe.get_doc("OMC Customer Profile", customer_profile)
    return None


def _text(value):
    return (value or "").strip()
