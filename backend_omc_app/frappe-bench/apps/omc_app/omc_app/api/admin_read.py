"""Capability-scoped administration reads for the mobile control center."""

from __future__ import annotations

import frappe

from omc_app.api import admin_control, capabilities, security


@frappe.whitelist()
def get_admin_overview(limit_start=0, limit_page_length=20):
    """Return only administration sections the current staff member may use.

    Mutations remain in ``admin_control`` and keep their existing granular
    capability checks. This reader intentionally does not let one admin
    capability reveal another administration domain.
    """

    values = capabilities.effective()
    can_manage_staff = bool(values.get("can_manage_staff"))
    can_review_registrations = bool(values.get("can_review_registrations"))
    can_manage_business_settings = bool(
        values.get("can_manage_business_settings")
    )

    if not (
        can_manage_staff
        or can_review_registrations
        or can_manage_business_settings
    ):
        frappe.throw(
            "You do not have permission to access OMC administration.",
            frappe.PermissionError,
        )

    security.enforce_rate_limit("authenticated_list")
    start, length = admin_control._pagination(
        limit_start,
        limit_page_length,
    )

    applications = []
    if can_review_registrations:
        pending = frappe.get_all(
            "OMC Customer Profile",
            filters={
                "approval_status": ["in", ["Pending", "Pending Review"]]
            },
            fields=[
                "name",
                "full_name",
                "email",
                "phone",
                "register_as",
                "customer_type",
                "customer_status",
                "approval_status",
                "creation",
            ],
            order_by="creation asc",
            limit_start=start,
            limit_page_length=length,
        )
        applications = [
            {
                **dict(row),
                "application_type": (
                    "staff"
                    if admin_control._requested_staff_role(row)
                    else "customer"
                ),
                "requested_role": (
                    admin_control._requested_staff_role(row) or ""
                ),
                "creation": str(row.creation or ""),
            }
            for row in pending
        ]

    staff = []
    available_roles = []
    if can_manage_staff:
        staff_rows = frappe.get_all(
            "OMC Staff Access",
            fields=["name"],
            order_by="user asc",
            limit_page_length=100,
        )
        staff = [
            admin_control._staff_item(
                frappe.get_doc("OMC Staff Access", row.name)
            )
            for row in staff_rows
        ]
        available_roles = sorted(admin_control.STAFF_ROLES)

    return {
        "applications": applications,
        "staff": staff,
        "available_roles": available_roles,
        "allowed_sections": {
            "registrations": can_review_registrations,
            "staff": can_manage_staff,
            "business_settings": can_manage_business_settings,
        },
        "limit_start": start,
        "limit_page_length": length,
    }
