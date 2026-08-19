from __future__ import annotations

from collections import defaultdict

import frappe

from omc_app.api import capabilities, referrals


COMPLETED_STATUSES = {"completed", "closed", "done", "delivered", "approved"}
CANCELLED_STATUSES = {"cancelled", "canceled", "rejected"}


def _text(value) -> str:
    return str(value or "").strip()


def _roles(user: str) -> set[str]:
    return set(frappe.get_roles(user) or [])


def _current_user() -> str:
    user = frappe.session.user if getattr(frappe, "session", None) else "Guest"
    if not user or user == "Guest":
        frappe.throw("Login is required.", frappe.PermissionError)
    return user


def _columns():
    return [
        {
            "label": "Customer",
            "fieldname": "customer_id",
            "fieldtype": "Link",
            "options": "OMC Customer Profile",
            "width": 180,
        },
        {
            "label": "Customer Name",
            "fieldname": "full_name",
            "fieldtype": "Data",
            "width": 180,
        },
        {
            "label": "Referral Owner",
            "fieldname": "referred_by",
            "fieldtype": "Link",
            "options": "User",
            "width": 190,
        },
        {
            "label": "Referral Code",
            "fieldname": "referral_code_used",
            "fieldtype": "Data",
            "width": 125,
        },
        {
            "label": "Joined On",
            "fieldname": "joined_on",
            "fieldtype": "Date",
            "width": 105,
        },
        {
            "label": "Account Status",
            "fieldname": "account_status",
            "fieldtype": "Data",
            "width": 115,
        },
        {
            "label": "Total Services",
            "fieldname": "total_services",
            "fieldtype": "Int",
            "width": 105,
        },
        {
            "label": "Customer Requested",
            "fieldname": "customer_requested",
            "fieldtype": "Int",
            "width": 125,
        },
        {
            "label": "Created by Referrer",
            "fieldname": "referrer_created",
            "fieldtype": "Int",
            "width": 125,
        },
        {
            "label": "Completed",
            "fieldname": "completed_services",
            "fieldtype": "Int",
            "width": 90,
        },
        {
            "label": "Active",
            "fieldname": "active_services",
            "fieldtype": "Int",
            "width": 80,
        },
        {
            "label": "Cancelled",
            "fieldname": "cancelled_services",
            "fieldtype": "Int",
            "width": 90,
        },
        {
            "label": "Last Service",
            "fieldname": "last_service",
            "fieldtype": "Data",
            "width": 180,
        },
        {
            "label": "Last Activity",
            "fieldname": "last_activity",
            "fieldtype": "Datetime",
            "width": 155,
        },
        {
            "label": "Email",
            "fieldname": "email",
            "fieldtype": "Data",
            "width": 190,
        },
        {
            "label": "Mobile",
            "fieldname": "phone",
            "fieldtype": "Data",
            "width": 130,
        },
    ]


def _profile_filters(user: str):
    effective = capabilities.effective(user)
    if effective.get("can_view_all_customers"):
        return {"referral_record": ["is", "set"]}
    if referrals.is_referral_owner(user):
        return {
            "referred_by": user,
            "referral_record": ["is", "set"],
        }
    frappe.throw(
        "You do not have permission to view referral customers.",
        frappe.PermissionError,
    )


def _matches_search(profile, search: str) -> bool:
    if not search:
        return True
    haystack = " ".join(
        _text(value).lower()
        for value in (
            profile.name,
            profile.full_name,
            profile.email,
            profile.phone,
            profile.referred_by,
            profile.referral_code_used,
        )
    )
    return search.lower() in haystack


def _service_stats(profile_names: list[str]):
    stats = defaultdict(
        lambda: {
            "total_services": 0,
            "customer_requested": 0,
            "referrer_created": 0,
            "completed_services": 0,
            "active_services": 0,
            "cancelled_services": 0,
            "last_service": "",
            "last_activity": None,
        }
    )
    if not profile_names:
        return stats

    rows = frappe.get_all(
        "OMC Service Request",
        filters={"customer_profile": ["in", profile_names]},
        fields=[
            "name",
            "customer_profile",
            "service_title",
            "title",
            "status",
            "created_on_behalf",
            "submitted_by_internal_user",
            "referral_owner",
            "creation",
            "modified",
        ],
        order_by="creation desc",
    )

    owner_by_profile = {
        row.name: row.referred_by
        for row in frappe.get_all(
            "OMC Customer Profile",
            filters={"name": ["in", profile_names]},
            fields=["name", "referred_by"],
        )
    }

    for row in rows:
        bucket = stats[row.customer_profile]
        bucket["total_services"] += 1

        created_on_behalf = int(row.created_on_behalf or 0)
        if not created_on_behalf:
            bucket["customer_requested"] += 1
        else:
            owner = _text(owner_by_profile.get(row.customer_profile))
            submitted_by = _text(row.submitted_by_internal_user)
            referral_owner = _text(row.referral_owner)
            if owner and (submitted_by == owner or referral_owner == owner):
                bucket["referrer_created"] += 1

        status = _text(row.status).lower()
        if status in COMPLETED_STATUSES:
            bucket["completed_services"] += 1
        elif status in CANCELLED_STATUSES:
            bucket["cancelled_services"] += 1
        else:
            bucket["active_services"] += 1

        activity = row.modified or row.creation
        if not bucket["last_activity"] or activity > bucket["last_activity"]:
            bucket["last_activity"] = activity
            bucket["last_service"] = (
                _text(row.service_title)
                or _text(row.title)
                or _text(row.name)
            )

    return stats


def execute(filters=None):
    filters = frappe._dict(filters or {})
    user = _current_user()
    profile_filters = _profile_filters(user)

    profiles = frappe.get_all(
        "OMC Customer Profile",
        filters=profile_filters,
        fields=[
            "name",
            "full_name",
            "email",
            "phone",
            "customer_status",
            "approval_status",
            "is_active",
            "referred_by",
            "referral_code_used",
            "referral_assistance_consent",
            "creation",
            "modified",
        ],
        order_by="creation desc",
    )

    search = _text(filters.get("search"))
    status_filter = _text(filters.get("account_status")).lower()

    profiles = [
        profile
        for profile in profiles
        if _matches_search(profile, search)
        and (
            not status_filter
            or status_filter
            in {
                _text(profile.customer_status).lower(),
                _text(profile.approval_status).lower(),
            }
        )
    ]

    service_stats = _service_stats([profile.name for profile in profiles])
    data = []

    for profile in profiles:
        stats = service_stats[profile.name]
        account_status = (
            _text(profile.customer_status)
            or _text(profile.approval_status)
            or ("Active" if int(profile.is_active or 0) else "Inactive")
        )
        data.append(
            {
                "customer_id": profile.name,
                "full_name": profile.full_name or "",
                "referred_by": profile.referred_by or "",
                "referral_code_used": profile.referral_code_used or "",
                "joined_on": profile.creation.date() if profile.creation else None,
                "account_status": account_status,
                "email": profile.email or "",
                "phone": profile.phone or "",
                **stats,
            }
        )

    summary = [
        {
            "value": len(data),
            "label": "Referred Customers",
            "datatype": "Int",
        },
        {
            "value": sum(row["total_services"] for row in data),
            "label": "Total Services",
            "datatype": "Int",
        },
        {
            "value": sum(row["customer_requested"] for row in data),
            "label": "Customer Requested",
            "datatype": "Int",
        },
        {
            "value": sum(row["referrer_created"] for row in data),
            "label": "Created by Referrer",
            "datatype": "Int",
        },
        {
            "value": sum(row["completed_services"] for row in data),
            "label": "Completed",
            "datatype": "Int",
        },
        {
            "value": sum(row["active_services"] for row in data),
            "label": "Active",
            "datatype": "Int",
        },
    ]

    return _columns(), data, None, None, summary
