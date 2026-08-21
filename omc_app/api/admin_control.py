"""Capability-guarded mobile administration for routine OMC operations."""

from __future__ import annotations

import json

import frappe
from frappe.utils import cint, flt, validate_email_address

from omc_app.api import access, capabilities, erp_customer_resolver, erp_sync_recovery, identity, pricing_guard, security, service_assignment
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
    return capabilities.require(capability)


def _pagination(limit_start=0, limit_page_length=20):
    try:
        return max(int(limit_start or 0), 0), min(max(int(limit_page_length or 20), 1), 100)
    except (TypeError, ValueError):
        frappe.throw("Invalid pagination values.", frappe.ValidationError)


def _operation_queue_capability(queue):
    return {
        "reassignment": "can_reassign_service_cases",
        "sync": "can_retry_sync",
        "discount": "can_manage_business_settings",
    }.get(_text(queue).lower())


def _operation_filters(queue):
    if queue == "reassignment":
        return {"status": ["not in", ["Completed", "Cancelled"]]}
    if queue == "sync":
        return {
            "erp_sync_status": ["in", sorted(erp_sync_recovery.RETRYABLE_STATUSES)],
            "erp_retry_exhausted_at": ["is", "set"],
        }
    return {"discount_status": "Pending Approval"}


def _requested_staff_role(profile):
    requested = _text(profile.get("register_as") or profile.get("customer_type")).lower()
    return APPLICATION_ROLE_MAP.get(requested)


def _resolution_mode_for_profile(profile):
    """Map reviewed onboarding intent to resolver behavior.

    Imported historical customers and explicit existing-customer claims may
    only link an existing ERP Customer. New and pre-field legacy signups use
    new-customer behavior, which still blocks creation on any historical
    identity collision.
    """
    mode = _text(profile.get("onboarding_mode"))

    if mode in {
        "Existing Customer Claim",
        "Imported Existing",
    }:
        return "claim_existing"

    return "new_customer"


def _set_user_roles(user, roles):
    """Retained callable seam that permanently rejects legacy role mutation."""
    frappe.throw(
        "Direct Has Role mutation is retired; update OMC Staff Access instead.",
        frappe.ValidationError,
    )


def _capability_codes(roles):
    requested = {_text(role) for role in (roles or []) if _text(role)}
    if not requested or not requested.issubset(STAFF_ROLES):
        frappe.throw("Select one or more supported OMC staff roles.", frappe.ValidationError)
    codes = set()
    for role in requested:
        codes.update(access.ROLE_CAPABILITIES.get(role, set()))
    if not codes:
        frappe.throw("The selected staff access profile has no capabilities.", frappe.ValidationError)
    return sorted(requested), sorted(codes)


def _staff_item(row):
    user = frappe.get_doc("User", row.user)
    return {
        "user_id": row.user,
        "full_name": user.full_name or row.user,
        "enabled": row.access_status == "Approved",
        "user_type": user.user_type or "",
        "roles": [row.persona_snapshot] if row.persona_snapshot else [],
        "capabilities": sorted({item.capability for item in row.capabilities or []}),
        "access_status": row.access_status,
        "reconciliation_status": row.reconciliation_status,
    }


def _upsert_staff_access(user_id, roles, *, access_status="Approved"):
    if identity.user_type(user_id) != "System User":
        frappe.throw("Staff Access can only be assigned to an existing System User.", frappe.ValidationError)
    selected_roles, capability_codes = _capability_codes(roles)
    persona = selected_roles[0] if len(selected_roles) == 1 else "Reviewed"
    name = frappe.db.get_value("OMC Staff Access", {"user": user_id}, "name")
    doc = frappe.get_doc("OMC Staff Access", name) if name else frappe.new_doc("OMC Staff Access")
    before = _text(doc.get("access_status"))
    doc.user = user_id
    doc.access_status = access_status
    doc.persona_snapshot = persona
    doc.persona_source = "Reviewed"
    doc.source_version = identity.source_version(user_id, persona, ",".join(capability_codes))
    doc.reconciliation_status = "Current"
    doc.set("capabilities", [{"capability": code} for code in capability_codes])
    if access_status == "Approved":
        doc.approved_by = _current_user()
        doc.approved_at = frappe.utils.now_datetime()
        doc.suspended_by = None
        doc.suspended_at = None
        doc.suspension_reason = ""
    if doc.is_new():
        doc.insert(ignore_permissions=True)
    else:
        doc.save(ignore_permissions=True)
    security.audit_event(
        event_type="staff_access.updated",
        capability="can_manage_staff",
        target_doctype="OMC Staff Access",
        target_name=doc.name,
        old_state=before,
        new_state=access_status,
        source_version=doc.source_version,
    )
    return doc, selected_roles


@frappe.whitelist(methods=["POST"])
def grant_break_glass(user=None, capability=None, expires_at=None, reason=None, scope_doctype=None, scope_name=None):
    _require("can_manage_staff")
    user = _text(user)
    capability = _text(capability)
    reason = _text(reason)
    if not identity.user_is_enabled(user) or identity.user_type(user) != "System User":
        frappe.throw("Break-glass access requires an enabled System User.", frappe.ValidationError)
    if capability not in capabilities.INTERNAL_CAPABILITY_KEYS:
        frappe.throw("Unsupported capability.", frappe.ValidationError)
    if not reason:
        frappe.throw("A break-glass reason is required.", frappe.ValidationError)
    doc = frappe.get_doc({
        "doctype": "OMC Break Glass Grant", "user": user, "capability": capability,
        "scope_doctype": _text(scope_doctype), "scope_name": _text(scope_name),
        "reason": reason[:1000], "expires_at": expires_at,
    })
    doc.insert(ignore_permissions=True)
    security.audit_event(
        event_type="staff_access.break_glass_granted", capability=capability,
        target_doctype="User", target_name=user, new_state="granted",
        override_expires_at=doc.expires_at,
    )
    return {"grant": doc.name, "expires_at": str(doc.expires_at)}


@frappe.whitelist(methods=["POST"])
def revoke_break_glass(grant=None, reason=None):
    _require("can_manage_staff")
    name = _text(grant)
    if not name or not frappe.db.exists("OMC Break Glass Grant", name):
        frappe.throw("Break-glass grant was not found.", frappe.DoesNotExistError)
    doc = frappe.get_doc("OMC Break Glass Grant", name)
    if doc.revoked:
        return {"grant": doc.name, "revoked": True}
    doc.revoked = 1
    doc.revoked_by = _current_user()
    doc.revoked_at = frappe.utils.now_datetime()
    doc.revocation_reason = _text(reason)[:1000]
    doc.save(ignore_permissions=True)
    security.audit_event(
        event_type="staff_access.break_glass_revoked", capability=doc.capability,
        target_doctype="User", target_name=doc.user, old_state="granted", new_state="revoked",
    )
    return {"grant": doc.name, "revoked": True}


@frappe.whitelist()
def get_admin_overview(limit_start=0, limit_page_length=20):
    _require("can_manage_staff")
    start, length = _pagination(limit_start, limit_page_length)
    pending = frappe.get_all(
        "OMC Customer Profile",
        filters={"approval_status": ["in", ["Pending", "Pending Review"]]},
        fields=["name", "full_name", "email", "phone", "register_as", "customer_type", "onboarding_mode", "customer_status", "approval_status", "creation"],
        order_by="creation asc", limit_start=start, limit_page_length=length,
    )
    staff_rows = frappe.get_all(
        "OMC Staff Access",
        fields=["name"],
        order_by="user asc",
        limit_page_length=100,
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
        "staff": [_staff_item(frappe.get_doc("OMC Staff Access", row.name)) for row in staff_rows],
        "available_roles": sorted(STAFF_ROLES),
        "limit_start": start, "limit_page_length": length,
    }


@frappe.whitelist(methods=["POST"])
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

    requested_role = _requested_staff_role(profile)
    selected_roles = roles
    if isinstance(selected_roles, str):
        try:
            selected_roles = json.loads(selected_roles)
        except ValueError:
            selected_roles = [selected_roles]
    if requested_role:
        _, granted = _upsert_staff_access(email, selected_roles or [requested_role])
    else:
        granted = []
        if identity.user_type(email) == "System User":
            frappe.throw("System Users cannot be approved as customer accounts.", frappe.ValidationError)
    profile.approval_status = "Approved"
    profile.customer_status = "Active"
    profile.is_active = 1
    profile.save(ignore_permissions=True)
    if not requested_role:
        resolved = erp_customer_resolver.resolve_profile_customer(
            profile,
            resolution_mode=_resolution_mode_for_profile(profile),
        )
        if _text(resolved.get("status")) not in {"Resolved", "Created"}:
            frappe.throw(
                resolved.get("reason") or "ERP Customer linkage requires reconciliation.",
                frappe.ValidationError,
            )
        account = identity.ensure_customer_account_from_legacy(email)
        if not account:
            account = identity.get_customer_account(email, for_update=True)
        if not account:
            frappe.throw("The customer identity requires reviewed ERP Customer linkage.", frappe.ValidationError)
        account.erp_customer = resolved.get("customer")
        account.identity_proof_status = "Verified"
        account.account_link_status = "Linked"
        account.service_access_status = "Approved"
        account.mapping_provenance = "Reviewed Reconciliation"
        account.mapping_confidence = "Reviewed"
        account.source_version = identity.source_version(profile.modified, resolved.get("customer"), email)
        account.approved_by = _current_user()
        account.approved_at = frappe.utils.now_datetime()
        account.save(ignore_permissions=True)
        security.audit_event(
            event_type="customer_access.approved",
            capability="can_review_registrations",
            target_doctype="OMC Customer Account",
            target_name=account.name,
            old_state="Pending Review",
            new_state="Approved",
        )
    frappe.clear_cache(user=email)
    frappe.db.commit()
    return {"profile_id": profile.name, "user_id": email, "decision": "approved", "roles": granted or [access.CUSTOMER_ROLE]}


@frappe.whitelist(methods=["POST"])
def invite_staff(full_name=None, email=None, roles=None):
    _require("can_manage_staff")
    email = _text(email).lower()
    full_name = _text(full_name)
    if not validate_email_address(email, throw=False) or not full_name:
        frappe.throw("A valid email and full name are required.", frappe.ValidationError)
    if not frappe.db.exists("User", email):
        frappe.throw("Create the authoritative System User in Frappe Desk before granting OMC Staff Access.", frappe.ValidationError)
    parsed_roles = json.loads(roles) if isinstance(roles, str) else roles
    access_doc, granted = _upsert_staff_access(email, parsed_roles)
    frappe.clear_cache(user=email)
    frappe.db.commit()
    return {"created": True, "user": _staff_item(access_doc), "roles": granted}


@frappe.whitelist(methods=["POST"])
def update_staff_account(user_id=None, roles=None, enabled=None):
    _require("can_manage_staff")
    user_id = _text(user_id)
    if user_id in {"Administrator", _current_user()}:
        frappe.throw("Use Frappe Desk for the built-in Administrator or your own admin account.", frappe.PermissionError)
    if not user_id or not frappe.db.exists("User", user_id):
        frappe.throw("Staff user was not found.", frappe.DoesNotExistError)
    parsed_roles = json.loads(roles) if isinstance(roles, str) else roles
    status = "Approved" if enabled is None or cint(enabled) else "Suspended"
    access_doc, granted = _upsert_staff_access(user_id, parsed_roles, access_status=status)
    if status == "Suspended":
        access_doc.suspended_by = _current_user()
        access_doc.suspended_at = frappe.utils.now_datetime()
        access_doc.suspension_reason = "administrative_access_change"
        access_doc.save(ignore_permissions=True)
        security.revoke_user_sessions(user_id)
    frappe.clear_cache(user=user_id)
    frappe.db.commit()
    return {"updated": True, "user": _staff_item(access_doc), "roles": granted}


@frappe.whitelist()
def get_admin_operations(
    queue=None,
    search=None,
    limit_start=0,
    limit_page_length=20,
):
    queue = _text(queue).lower()
    capability = _operation_queue_capability(queue)
    if not capability:
        frappe.throw("Select a supported administration queue.", frappe.ValidationError)
    _require(capability)
    start, length = _pagination(limit_start, limit_page_length)
    filters = _operation_filters(queue)
    query = _text(search)
    or_filters = None
    if query:
        pattern = f"%{query}%"
        or_filters = {
            "name": ["like", pattern],
            "title": ["like", pattern],
            "customer_name": ["like", pattern],
            "service_title": ["like", pattern],
        }

    fields = [
        "name", "title", "status", "service", "service_title",
        "customer_profile", "customer_name", "assigned_staff", "erp_task",
        "erp_sync_status", "erp_sync_error", "erp_retry_count",
        "erp_last_attempt_at", "erp_next_attempt_at", "erp_retry_exhausted_at",
        "original_price", "discount_type", "discount_value", "discount_amount",
        "proposed_final_price", "final_price", "discount_reason",
        "discount_status", "discount_requested_by", "modified",
    ]
    rows = frappe.get_all(
        "OMC Service Request",
        filters=filters,
        or_filters=or_filters,
        fields=fields,
        order_by="modified desc, name desc",
        limit_start=start,
        limit_page_length=length,
    )
    if or_filters:
        count_rows = frappe.get_all(
            "OMC Service Request",
            filters=filters,
            or_filters=or_filters,
            fields=["count(name) as total"],
            limit_page_length=1,
        )
        total = int(count_rows[0].total or 0) if count_rows else 0
    else:
        total = frappe.db.count("OMC Service Request", filters=filters)
    return {
        "queue": queue,
        "items": [dict(row) for row in rows],
        "limit_start": start,
        "limit_page_length": length,
        "total": total,
        "has_more": start + len(rows) < total,
    }


@frappe.whitelist(methods=["POST"])
def reassign_service_request(service_request=None, assigned_staff=None, reason=None):
    _require("can_reassign_service_cases")
    if not service_request or not frappe.db.exists("OMC Service Request", service_request):
        frappe.throw("Service request was not found.", frappe.DoesNotExistError)
    request = frappe.get_doc("OMC Service Request", service_request)
    service = frappe.get_doc("OMC Service", request.service)
    previous_assignee = request.get("assigned_staff") or ""
    decision = service_assignment.resolve_assignee(service, explicit_user=assigned_staff)
    result = service_assignment.apply_assignment(request, decision)
    reason = _text(reason)
    audit_message = (
        f"Service request reassigned from {previous_assignee or 'Unassigned'} "
        f"to {decision.get('candidate') or 'Unassigned'} by {_current_user()}."
    )
    if reason:
        audit_message += f" Reason: {reason}"
    request.add_comment("Comment", text=audit_message)
    frappe.db.commit()
    return {
        "service_request": request.name,
        "previous_assignee": previous_assignee,
        "assigned_staff": decision.get("candidate"),
        "assignment": result,
        "audit_message": audit_message,
    }


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
        "title": request.get("title") or request.get("service_title") or request.name,
        "service": request.get("service") or "",
        "service_title": request.get("service_title") or "",
        "customer_profile": request.get("customer_profile") or "",
        "customer_name": request.get("customer_name") or "",
        "assigned_staff": request.get("assigned_staff") or "",
        "assignment_candidates": [
            {"user_id": user, "full_name": frappe.db.get_value("User", user, "full_name") or user}
            for user in candidates
        ],
        "erp_sync_status": request.get("erp_sync_status") or "",
        "erp_retry_count": request.get("erp_retry_count") or 0,
        "erp_sync_error": request.get("erp_sync_error") or "",
        "erp_task": request.get("erp_task") or "",
        "erp_last_attempt_at": str(request.get("erp_last_attempt_at") or ""),
        "erp_next_attempt_at": str(request.get("erp_next_attempt_at") or ""),
        "erp_retry_exhausted_at": str(request.get("erp_retry_exhausted_at") or ""),
        "discount_status": request.get("discount_status") or "",
        "discount_type": request.get("discount_type") or "",
        "discount_value": flt(request.get("discount_value")),
        "discount_amount": flt(request.get("discount_amount")),
        "discount_reason": request.get("discount_reason") or "",
        "discount_requested_by": request.get("discount_requested_by") or "",
        "original_price": flt(request.get("original_price")),
        "proposed_final_price": flt(request.get("proposed_final_price")),
        "final_price": flt(request.get("final_price")),
        "discount_auto_approval_percent": flt(
            frappe.db.get_single_value("OMC Mobile Settings", "discount_auto_approval_percent")
        ),
        "minimum_service_price": flt(
            frappe.db.get_single_value("OMC Mobile Settings", "minimum_service_price")
        ),
        "capabilities": {
            "can_reassign": bool(capabilities.get("can_reassign_service_cases")),
            "can_retry_sync": bool(capabilities.get("can_retry_sync")),
            "can_review_discount": bool(capabilities.get("can_manage_business_settings")),
        },
    }


@frappe.whitelist(methods=["POST"])
def retry_service_sync(service_request=None):
    _require("can_retry_sync")
    return erp_sync_recovery.retry_erp_sync(service_request, reset_exhaustion=1)


@frappe.whitelist(methods=["POST"])
def review_discount(service_request=None, decision=None, reason=None):
    _require("can_manage_business_settings")
    return pricing_guard.finalize_discount_review(
        service_request,
        decision=decision,
        reason=reason,
        reviewer=_current_user(),
    )


@frappe.whitelist()
def get_business_settings():
    _require("can_manage_business_settings")
    settings = frappe.get_single("OMC Mobile Settings")
    return {field: settings.get(field) for field in sorted(BUSINESS_SETTING_FIELDS) if settings.meta.has_field(field)}


@frappe.whitelist(methods=["POST"])
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
