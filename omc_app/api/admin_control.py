"""Capability-guarded mobile administration for routine OMC operations."""

from __future__ import annotations

import json

import frappe
from frappe.utils import cint, flt, validate_email_address

from omc_app.api import access, erp_sync_recovery, service_assignment
from omc_app.setup.roles import (
    ADMIN_ROLE,
    BUSINESS_PARTNER_ROLE,
    CONSULTANT_ROLE,
    DOCUMENT_REVIEWER_ROLE,
    FINANCE_REVIEWER_ROLE,
    MANAGER_ROLE,
    SUPPORT_AGENT_ROLE,
    TAX_ASSOCIATE_ROLE,
)

STAFF_ROLES = {
    ADMIN_ROLE,
    MANAGER_ROLE,
    SUPPORT_AGENT_ROLE,
    DOCUMENT_REVIEWER_ROLE,
    FINANCE_REVIEWER_ROLE,
    CONSULTANT_ROLE,
    TAX_ASSOCIATE_ROLE,
    BUSINESS_PARTNER_ROLE,
}
APPLICATION_ROLE_MAP = {
    "consultant": CONSULTANT_ROLE,
    "tax associate": TAX_ASSOCIATE_ROLE,
    "business partner": BUSINESS_PARTNER_ROLE,
}
BUSINESS_SETTING_FIELDS = {
    "guest_mode_enabled", "payments_enabled", "support_enabled", "knowledge_enabled",
    "tax_calculator_enabled", "expense_tracker_enabled", "internal_workspace_enabled",
    "maintenance_mode", "minimum_app_version", "force_update",
    "discount_auto_approval_percent", "minimum_service_price",
}


def _text(value):
    return str(value or "").strip()


def _current_user():
    return getattr(getattr(frappe, "session", None), "user", None) or "Guest"


def _require(capability):
    capabilities = access.get_mobile_capabilities()
    if not capabilities.get(capability):
        frappe.throw("You do not have permission to perform this administrative action.", frappe.PermissionError)
    return capabilities


def _pagination(limit_start=0, limit_page_length=20):
    try:
        return max(int(limit_start or 0), 0), min(max(int(limit_page_length or 20), 1), 100)
    except (TypeError, ValueError):
        frappe.throw("Invalid pagination values.", frappe.ValidationError)


def _requested_staff_role(profile):
    requested = _text(profile.get("register_as") or profile.get("customer_type")).lower()
    return APPLICATION_ROLE_MAP.get(requested)


def _set_user_roles(user_doc, roles):
    requested = {_text(role) for role in (roles or []) if _text(role)}
    if not requested or not requested.issubset(STAFF_ROLES):
        frappe.throw("Select one or more supported OMC staff roles.", frappe.ValidationError)
    preserved = [row for row in (user_doc.roles or []) if row.role not in STAFF_ROLES | {access.CUSTOMER_ROLE}]
    user_doc.roles = preserved
    for role in sorted(requested):
        user_doc.append("roles", {"role": role})
    user_doc.user_type = "System User"
    return sorted(requested)


def _staff_item(row):
    roles = sorted(set(frappe.get_roles(row.name) or []).intersection(STAFF_ROLES))
    return {
        "user_id": row.name, "full_name": row.full_name or row.name,
        "enabled": bool(row.enabled), "user_type": row.user_type or "", "roles": roles,
    }


@frappe.whitelist()
def get_admin_overview(limit_start=0, limit_page_length=20):
    _require("can_manage_staff")
    start, length = _pagination(limit_start, limit_page_length)
    pending = frappe.get_all(
        "OMC Customer Profile",
        filters={"approval_status": ["in", ["Pending", "Pending Review"]]},
        fields=["name", "full_name", "email", "phone", "register_as", "customer_type", "customer_status", "approval_status", "creation"],
        order_by="creation asc", limit_start=start, limit_page_length=length,
    )
    staff_users = frappe.get_all(
        "Has Role", filters={"role": ["in", sorted(STAFF_ROLES)], "parenttype": "User"},
        pluck="parent", distinct=True,
    )
    staff_rows = frappe.get_all(
        "User", filters={"name": ["in", sorted(set(staff_users))]} if staff_users else {"name": ""},
        fields=["name", "full_name", "enabled", "user_type"], order_by="full_name asc",
    )
    return {
        "applications": [
            {
                **dict(row), "application_type": "staff" if _requested_staff_role(row) else "customer",
                "requested_role": _requested_staff_role(row) or "",
                "creation": str(row.creation or ""),
            }
            for row in pending
        ],
        "staff": [_staff_item(row) for row in staff_rows if row.name != "Administrator"],
        "available_roles": sorted(STAFF_ROLES),
        "limit_start": start, "limit_page_length": length,
    }


@frappe.whitelist()
def review_registration(profile_id=None, decision=None, roles=None, reason=None):
    _require("can_review_registrations")
    profile_id = _text(profile_id)
    decision = _text(decision).lower()
    if decision not in {"approve", "reject"}:
        frappe.throw("decision must be approve or reject.", frappe.ValidationError)
    if not profile_id or not frappe.db.exists("OMC Customer Profile", profile_id):
        frappe.throw("Registration profile was not found.", frappe.DoesNotExistError)
    profile = frappe.get_doc("OMC Customer Profile", profile_id)
    email = _text(profile.get("linked_app_user") or profile.user or profile.email).lower()
    if not email or not frappe.db.exists("User", email):
        frappe.throw("The registration does not have a verified user account.", frappe.ValidationError)

    if decision == "reject":
        profile.approval_status = "Rejected"
        profile.customer_status = "Rejected"
        profile.is_active = 0
        profile.add_comment("Comment", text=_text(reason) or "Registration rejected by OMC administration.")
        profile.save(ignore_permissions=True)
        frappe.db.commit()
        return {"profile_id": profile.name, "decision": "rejected", "roles": []}

    user_doc = frappe.get_doc("User", email)
    requested_role = _requested_staff_role(profile)
    selected_roles = roles
    if isinstance(selected_roles, str):
        try:
            selected_roles = json.loads(selected_roles)
        except ValueError:
            selected_roles = [selected_roles]
    if requested_role:
        granted = _set_user_roles(user_doc, selected_roles or [requested_role])
    else:
        granted = []
        existing = {row.role for row in (user_doc.roles or [])}
        if access.CUSTOMER_ROLE not in existing:
            user_doc.append("roles", {"role": access.CUSTOMER_ROLE})
        user_doc.user_type = "Website User"
    user_doc.enabled = 1
    user_doc.save(ignore_permissions=True)
    profile.approval_status = "Approved"
    profile.customer_status = "Active"
    profile.is_active = 1
    profile.save(ignore_permissions=True)
    frappe.clear_cache(user=email)
    frappe.db.commit()
    return {"profile_id": profile.name, "user_id": email, "decision": "approved", "roles": granted or [access.CUSTOMER_ROLE]}


@frappe.whitelist()
def invite_staff(full_name=None, email=None, roles=None):
    _require("can_manage_staff")
    email = _text(email).lower()
    full_name = _text(full_name)
    if not validate_email_address(email, throw=False) or not full_name:
        frappe.throw("A valid email and full name are required.", frappe.ValidationError)
    if frappe.db.exists("User", email):
        frappe.throw("A user with this email already exists.", frappe.DuplicateEntryError)
    parsed_roles = json.loads(roles) if isinstance(roles, str) else roles
    user_doc = frappe.new_doc("User")
    user_doc.email = email
    user_doc.first_name = full_name
    user_doc.full_name = full_name
    user_doc.enabled = 1
    user_doc.send_welcome_email = 1
    _set_user_roles(user_doc, parsed_roles)
    user_doc.insert(ignore_permissions=True)
    frappe.clear_cache(user=email)
    frappe.db.commit()
    return {"created": True, "user": _staff_item(user_doc)}


@frappe.whitelist()
def update_staff_account(user_id=None, roles=None, enabled=None):
    _require("can_manage_staff")
    user_id = _text(user_id)
    if user_id in {"Administrator", _current_user()}:
        frappe.throw("Use Frappe Desk for the built-in Administrator or your own admin account.", frappe.PermissionError)
    if not user_id or not frappe.db.exists("User", user_id):
        frappe.throw("Staff user was not found.", frappe.DoesNotExistError)
    user_doc = frappe.get_doc("User", user_id)
    parsed_roles = json.loads(roles) if isinstance(roles, str) else roles
    granted = _set_user_roles(user_doc, parsed_roles)
    user_doc.enabled = cint(enabled) if enabled is not None else user_doc.enabled
    user_doc.save(ignore_permissions=True)
    frappe.clear_cache(user=user_id)
    frappe.db.commit()
    return {"updated": True, "user": _staff_item(user_doc), "roles": granted}


@frappe.whitelist()
def reassign_service_request(service_request=None, assigned_staff=None):
    _require("can_reassign_service_cases")
    if not service_request or not frappe.db.exists("OMC Service Request", service_request):
        frappe.throw("Service request was not found.", frappe.DoesNotExistError)
    request = frappe.get_doc("OMC Service Request", service_request)
    service = frappe.get_doc("OMC Service", request.service)
    decision = service_assignment.resolve_assignee(service, explicit_user=assigned_staff)
    result = service_assignment.apply_assignment(request, decision)
    frappe.db.commit()
    return {"service_request": request.name, "assigned_staff": decision.get("candidate"), "assignment": result}


@frappe.whitelist()
def get_case_admin_options(service_request=None):
    capabilities = access.get_mobile_capabilities()
    if not any(
        capabilities.get(key)
        for key in ("can_reassign_service_cases", "can_retry_sync", "can_manage_business_settings")
    ):
        frappe.throw("You do not have permission to administer this request.", frappe.PermissionError)
    if not service_request or not frappe.db.exists("OMC Service Request", service_request):
        frappe.throw("Service request was not found.", frappe.DoesNotExistError)
    request = frappe.get_doc("OMC Service Request", service_request)
    candidates = sorted(
        {
            user
            for role in service_assignment.ASSIGNABLE_SERVICE_ROLES
            for user in service_assignment.users_for_role(role)
        }
    )
    return {
        "service_request": request.name,
        "assigned_staff": request.get("assigned_staff") or "",
        "assignment_candidates": [
            {"user_id": user, "full_name": frappe.db.get_value("User", user, "full_name") or user}
            for user in candidates
        ],
        "erp_sync_status": request.get("erp_sync_status") or "",
        "erp_retry_count": request.get("erp_retry_count") or 0,
        "erp_retry_exhausted_at": str(request.get("erp_retry_exhausted_at") or ""),
        "discount_status": request.get("discount_status") or "",
        "original_price": flt(request.get("original_price")),
        "proposed_final_price": flt(request.get("proposed_final_price")),
        "final_price": flt(request.get("final_price")),
    }


@frappe.whitelist()
def retry_service_sync(service_request=None):
    _require("can_retry_sync")
    return erp_sync_recovery.retry_erp_sync(service_request, reset_exhaustion=1)


@frappe.whitelist()
def review_discount(service_request=None, decision=None, reason=None):
    _require("can_manage_business_settings")
    decision = _text(decision).lower()
    if decision not in {"approve", "reject"}:
        frappe.throw("decision must be approve or reject.", frappe.ValidationError)
    if not service_request or not frappe.db.exists("OMC Service Request", service_request):
        frappe.throw("Service request was not found.", frappe.DoesNotExistError)
    request = frappe.get_doc("OMC Service Request", service_request)
    if _text(request.get("discount_status")) != "Pending Approval":
        frappe.throw("This request does not have a pending discount.", frappe.ValidationError)
    request.discount_approved_by = _current_user()
    if decision == "approve":
        request.final_price = request.get("proposed_final_price") or request.original_price
        request.discount_status = "Approved"
    else:
        request.final_price = request.original_price
        request.discount_status = "Rejected"
        request.add_comment("Comment", text=_text(reason) or "Discount request rejected by OMC administration.")
    request.save(ignore_permissions=True)
    frappe.db.commit()
    return {"service_request": request.name, "discount_status": request.discount_status, "final_price": flt(request.final_price)}


@frappe.whitelist()
def get_business_settings():
    _require("can_manage_business_settings")
    settings = frappe.get_single("OMC Mobile Settings")
    return {field: settings.get(field) for field in sorted(BUSINESS_SETTING_FIELDS) if settings.meta.has_field(field)}


@frappe.whitelist()
def update_business_settings(settings=None, **kwargs):
    _require("can_manage_business_settings")
    values = json.loads(settings) if isinstance(settings, str) else dict(settings or kwargs or {})
    unknown = set(values) - BUSINESS_SETTING_FIELDS
    if unknown:
        frappe.throw(f"Unsupported business settings: {', '.join(sorted(unknown))}", frappe.ValidationError)
    doc = frappe.get_single("OMC Mobile Settings")
    for field, value in values.items():
        if not doc.meta.has_field(field):
            continue
        if field == "discount_auto_approval_percent":
            value = min(max(flt(value), 0), 100)
        elif field == "minimum_service_price":
            value = max(flt(value), 0)
        doc.set(field, value)
    doc.save(ignore_permissions=True)
    frappe.clear_cache()
    frappe.db.commit()
    return {"updated": True, "settings": get_business_settings()}
