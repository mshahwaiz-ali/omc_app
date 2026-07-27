from __future__ import annotations

from collections import Counter, defaultdict

import frappe

from omc_app.api import referrals


SERVICE_REQUEST_FIELDS = [
    "name",
    "service",
    "service_title",
    "title",
    "status",
    "customer_profile",
    "customer_mode",
    "submission_mode",
    "submitted_by_user",
    "submitted_by_internal_user",
    "referral_owner",
    "created_on_behalf",
    "creation",
    "modified",
    "closed_on",
]


def _text(value) -> str:
    return str(value or "").strip()


def _current_user() -> str:
    user = frappe.session.user if getattr(frappe, "session", None) else "Guest"
    if not user or user == "Guest":
        frappe.throw("Login is required.", frappe.PermissionError)
    return user


def _owner_record(user: str):
    record = referrals.get_or_create_owner_record(user)
    if not record:
        frappe.throw("Referral account not found.", frappe.DoesNotExistError)
    return record


def _owned_customer_profile(user: str, customer_profile: str):
    customer_profile = _text(customer_profile)
    if not customer_profile:
        frappe.throw("customer_profile is required.", frappe.ValidationError)

    name = frappe.db.get_value(
        "OMC Customer Profile",
        {
            "name": customer_profile,
            "referred_by": user,
        },
        "name",
    )
    if not name:
        frappe.throw(
            "This customer is not linked to your referral account.",
            frappe.PermissionError,
        )
    return frappe.get_doc("OMC Customer Profile", name)


def _request_kind(row, owner: str) -> str:
    if not int(row.created_on_behalf or 0):
        return "self"
    if _text(row.referral_owner) == owner and _text(row.submitted_by_internal_user) == owner:
        return "referrer"
    return "other"


def _request_item(row, owner: str) -> dict:
    kind = _request_kind(row, owner)
    return {
        "request_id": row.name,
        "service": row.service or "",
        "service_title": row.service_title or row.title or "",
        "title": row.title or row.service_title or "",
        "status": row.status or "",
        "customer_mode": row.customer_mode or "",
        "submission_mode": row.submission_mode or "",
        "created_on_behalf": int(row.created_on_behalf or 0),
        "created_by_customer": kind == "self",
        "created_by_referrer": kind == "referrer",
        "creation": str(row.creation or ""),
        "modified": str(row.modified or ""),
        "closed_on": str(row.closed_on or ""),
    }


def _aggregate_requests(rows, owner: str) -> dict:
    status_counts = Counter()
    kind_counts = Counter()
    service_buckets = defaultdict(
        lambda: {
            "service": "",
            "service_title": "",
            "total": 0,
            "self_created": 0,
            "referrer_created": 0,
            "status_counts": Counter(),
        }
    )

    items = []
    for row in rows:
        item = _request_item(row, owner)
        items.append(item)

        status = item["status"] or "Unknown"
        kind = "self" if item["created_by_customer"] else "referrer" if item["created_by_referrer"] else "other"
        status_counts[status] += 1
        kind_counts[kind] += 1

        service_key = row.service or row.service_title or row.title or row.name
        bucket = service_buckets[service_key]
        bucket["service"] = row.service or ""
        bucket["service_title"] = row.service_title or row.title or ""
        bucket["total"] += 1
        bucket["status_counts"][status] += 1
        if kind == "self":
            bucket["self_created"] += 1
        elif kind == "referrer":
            bucket["referrer_created"] += 1

    services = []
    for bucket in service_buckets.values():
        services.append(
            {
                "service": bucket["service"],
                "service_title": bucket["service_title"],
                "total": bucket["total"],
                "self_created": bucket["self_created"],
                "referrer_created": bucket["referrer_created"],
                "status_counts": dict(bucket["status_counts"]),
            }
        )
    services.sort(key=lambda item: (-item["total"], item["service_title"]))

    return {
        "counts": {
            "total_services": len(rows),
            "self_created_services": kind_counts["self"],
            "referrer_created_services": kind_counts["referrer"],
            "other_created_services": kind_counts["other"],
        },
        "status_counts": dict(status_counts),
        "services": services,
        "requests": items,
    }


@frappe.whitelist()
def get_my_referral_summary():
    user = _current_user()
    record = _owner_record(user)
    profiles = frappe.get_all(
        "OMC Customer Profile",
        filters={"referred_by": user, "referral_record": record.name},
        fields=[
            "name",
            "full_name",
            "email",
            "phone",
            "customer_status",
            "approval_status",
            "referral_assistance_consent",
            "is_active",
            "creation",
            "modified",
        ],
        order_by="modified desc",
    )

    profile_names = [row.name for row in profiles]
    requests = []
    if profile_names:
        requests = frappe.get_all(
            "OMC Service Request",
            filters={"customer_profile": ["in", profile_names]},
            fields=SERVICE_REQUEST_FIELDS,
            order_by="creation desc",
        )

    analytics = _aggregate_requests(requests, user)
    return {
        "referral": {
            "name": record.name,
            "referral_code": record.referral_code or "",
            "status": record.status or "",
            "is_active": int(record.is_active or 0),
        },
        "counts": {
            "total_referrals": len(profiles),
            "active_referrals": sum(int(row.is_active or 0) for row in profiles),
            "consented_referrals": sum(
                int(row.referral_assistance_consent or 0) for row in profiles
            ),
            **analytics["counts"],
        },
        "status_counts": analytics["status_counts"],
        "services": analytics["services"],
    }


@frappe.whitelist()
def get_my_referrals(search=None, limit_start=0, limit_page_length=20):
    user = _current_user()
    record = _owner_record(user)

    try:
        start = max(int(limit_start or 0), 0)
        length = min(max(int(limit_page_length or 20), 1), 100)
    except (TypeError, ValueError):
        frappe.throw("Invalid pagination values.", frappe.ValidationError)

    filters = {"referred_by": user, "referral_record": record.name}
    or_filters = None
    term = _text(search)
    if term:
        like = f"%{term}%"
        or_filters = {
            "name": ["like", like],
            "full_name": ["like", like],
            "email": ["like", like],
            "phone": ["like", like],
            "cnic": ["like", like],
        }

    profiles = frappe.get_all(
        "OMC Customer Profile",
        filters=filters,
        or_filters=or_filters,
        fields=[
            "name",
            "full_name",
            "email",
            "phone",
            "customer_status",
            "approval_status",
            "referral_assistance_consent",
            "customer_origin",
            "linked_app_user",
            "is_active",
            "creation",
            "modified",
        ],
        order_by="modified desc",
        limit_start=start,
        limit_page_length=length,
    )

    items = []
    for profile in profiles:
        rows = frappe.get_all(
            "OMC Service Request",
            filters={"customer_profile": profile.name},
            fields=SERVICE_REQUEST_FIELDS,
            order_by="creation desc",
        )
        analytics = _aggregate_requests(rows, user)
        items.append(
            {
                "customer_id": profile.name,
                "full_name": profile.full_name or "",
                "email": profile.email or "",
                "phone": profile.phone or "",
                "customer_status": profile.customer_status or "",
                "approval_status": profile.approval_status or "",
                "consent_granted": int(profile.referral_assistance_consent or 0),
                "is_active": int(profile.is_active or 0),
                "customer_origin": profile.customer_origin or "",
                "linked_app_user": profile.linked_app_user or "",
                "created_at": str(profile.creation or ""),
                "modified": str(profile.modified or ""),
                "service_counts": analytics["counts"],
                "service_status_counts": analytics["status_counts"],
            }
        )

    return {
        "items": items,
        "limit_start": start,
        "limit_page_length": length,
    }


@frappe.whitelist()
def get_my_referral_detail(customer_profile=None):
    user = _current_user()
    record = _owner_record(user)
    profile = _owned_customer_profile(user, customer_profile)

    if _text(profile.referral_record) != record.name:
        frappe.throw(
            "This customer is not linked to your referral record.",
            frappe.PermissionError,
        )

    rows = frappe.get_all(
        "OMC Service Request",
        filters={"customer_profile": profile.name},
        fields=SERVICE_REQUEST_FIELDS,
        order_by="creation desc",
    )
    analytics = _aggregate_requests(rows, user)

    return {
        "customer": {
            "customer_id": profile.name,
            "full_name": profile.full_name or "",
            "email": profile.email or "",
            "phone": profile.phone or "",
            "customer_status": profile.customer_status or "",
            "approval_status": profile.approval_status or "",
            "consent_granted": int(profile.referral_assistance_consent or 0),
            "is_active": int(profile.is_active or 0),
            "customer_origin": profile.customer_origin or "",
            "linked_app_user": profile.linked_app_user or "",
            "referral_code_used": profile.referral_code_used or "",
            "created_at": str(profile.creation or ""),
            "modified": str(profile.modified or ""),
        },
        **analytics,
    }
