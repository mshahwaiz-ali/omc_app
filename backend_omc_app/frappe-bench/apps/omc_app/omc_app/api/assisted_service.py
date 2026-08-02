from __future__ import annotations

import frappe

from omc_app.api import (
    access,
    erp_service_task_adapter,
    mobile,
    service_assignment,
    submission_integrity,
)
from omc_app.referral_capabilities import (
    ALL_CUSTOMER_ASSIST_ROLES,
    REFERRAL_ADMIN_ROLES,
    REFERRAL_OWNER_ROLES,
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


_active_system_user = service_assignment.active_assignable_user
_users_for_role = service_assignment.users_for_role
_open_assignment_count = service_assignment.open_assignment_count
_least_loaded_user = service_assignment.least_loaded_user
_assignment_role_for_service = service_assignment.assignment_role_for_service


def _resolve_request_assignee(service, *, explicit_user=None, referral_owner=None):
    return service_assignment.resolve_assignee(
        service,
        explicit_user=explicit_user,
        referral_owner=referral_owner,
    ).get("candidate")


def _ensure_assignment_todo(service_request, assignee):
    return service_assignment.ensure_assignment_todo(service_request, assignee).get("name")


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


def _request_pricing_snapshot(service, *, is_internal: bool, user: str, kwargs: dict) -> dict:
    original_price = frappe.utils.flt(getattr(service, "base_price", None) or 0)
    currency = _text(getattr(service, "currency", None)) or "PKR"
    discount_type = _text(kwargs.get("discount_type"))
    discount_value = frappe.utils.flt(kwargs.get("discount_value") or 0)
    discount_reason = _text(kwargs.get("discount_reason"))

    if not is_internal:
        if discount_type or discount_value or discount_reason:
            frappe.throw(
                "Discounts can only be applied by authorized internal staff.",
                frappe.PermissionError,
            )
        discount_type = ""
        discount_value = 0
        discount_reason = ""

    if discount_value < 0:
        frappe.throw("Discount value cannot be negative.", frappe.ValidationError)

    if discount_value and discount_type not in {"Percentage", "Fixed Amount"}:
        frappe.throw(
            "discount_type must be Percentage or Fixed Amount.",
            frappe.ValidationError,
        )

    if discount_type == "Percentage":
        if discount_value > 100:
            frappe.throw(
                "Percentage discount cannot exceed 100.",
                frappe.ValidationError,
            )
        discount_amount = original_price * discount_value / 100
    elif discount_type == "Fixed Amount":
        if discount_value > original_price:
            frappe.throw(
                "Fixed discount cannot exceed the original service price.",
                frappe.ValidationError,
            )
        discount_amount = discount_value
    else:
        discount_value = 0
        discount_amount = 0
        discount_reason = ""

    if discount_amount > 0 and not discount_reason:
        frappe.throw("A discount reason is required.", frappe.ValidationError)

    proposed_final_price = max(original_price - discount_amount, 0)
    auto_approval_percent = 10.0
    minimum_service_price = 0.0
    try:
        settings = frappe.get_single("OMC Mobile Settings")
        if settings.meta.has_field("discount_auto_approval_percent"):
            auto_approval_percent = frappe.utils.flt(settings.discount_auto_approval_percent or 10)
        if settings.meta.has_field("minimum_service_price"):
            minimum_service_price = frappe.utils.flt(settings.minimum_service_price or 0)
    except Exception:
        pass

    effective_percent = (discount_amount / original_price * 100) if original_price else 0
    needs_approval = bool(
        discount_amount > 0
        and (effective_percent > auto_approval_percent or proposed_final_price < minimum_service_price)
    )
    discount_status = "Pending Approval" if needs_approval else ("Approved" if discount_amount > 0 else "None")
    final_price = original_price if needs_approval else proposed_final_price

    return {
        "original_price": original_price,
        "pricing_currency": currency,
        "discount_type": discount_type,
        "discount_value": discount_value,
        "discount_amount": discount_amount,
        "proposed_final_price": proposed_final_price,
        "final_price": final_price,
        "discount_reason": discount_reason,
        "discount_status": discount_status,
        "discount_requested_by": user if is_internal and discount_amount > 0 else "",
        "discount_approved_by": user if discount_status == "Approved" else "",
        "discount_applied_by": user if discount_status == "Approved" else "",
    }


def _active_request(service, *, profile=None, manual_customer=None):
    filters = {
        "service": service.name,
        "status": ["in", ["Open", "In Progress", "Waiting for Customer", "Waiting for Payment"]],
    }
    if profile:
        filters["customer_profile"] = profile.name
    elif manual_customer:
        filters["manual_customer"] = manual_customer.name
    else:
        return None
    rows = frappe.get_all(
        "OMC Service Request", filters=filters,
        fields=["name", "status", "service", "service_title", "modified"],
        order_by="modified desc", limit_page_length=1,
    )
    return rows[0] if rows else None


def _duplicate_response(active, *, allow_parallel):
    return {
        "created": False,
        "duplicate": True,
        "allow_parallel_requests": bool(allow_parallel),
        "active_request": {
            "name": active.name, "case_id": active.name, "status": active.status,
            "service": active.service, "service_title": active.service_title or "",
            "modified": str(active.modified or ""),
        },
        "allowed_actions": ["resume_existing", "start_another"] if allow_parallel else ["resume_existing"],
        "message": "An active request already exists for this service.",
    }


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


def _manual_customer_duplicate_matches(
    *,
    mobile: str,
    email: str,
    cnic: str,
) -> list[str]:
    identity_fields = {
        "mobile": _text(mobile),
        "email": _text(email).lower(),
        "cnic": _text(cnic),
    }
    identity_fields = {
        fieldname: value
        for fieldname, value in identity_fields.items()
        if value
    }
    if not identity_fields:
        return []

    matches: set[str] = set()
    for fieldname, value in identity_fields.items():
        rows = frappe.get_all(
            "OMC Manual Customer",
            filters={
                fieldname: value,
                "conversion_status": ["!=", "Archived"],
            },
            pluck="name",
            limit=3,
        )
        matches.update(_text(name) for name in rows if _text(name))
        if matches:
            break

    return sorted(matches)


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

    duplicate_matches = _manual_customer_duplicate_matches(
        mobile=mobile_no,
        email=email,
        cnic=cnic,
    )
    if duplicate_matches:
        frappe.throw(
            (
                "A matching walk-in customer already exists. "
                "Select the existing customer or review the duplicate record."
            ),
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



def _pagination(limit_start=0, limit_page_length=20):
    try:
        start = max(int(limit_start or 0), 0)
        length = min(max(int(limit_page_length or 20), 1), 100)
    except (TypeError, ValueError):
        frappe.throw("Invalid pagination values.", frappe.ValidationError)
    return start, length


def _customer_item(row, *, mode: str) -> dict:
    return {
        "customer_mode": mode,
        "customer_id": row.name,
        "full_name": row.full_name or "",
        "email": row.email or "",
        "phone": row.phone or "",
        "customer_status": row.customer_status or "",
        "approval_status": row.approval_status or "",
        "consent_granted": int(row.referral_assistance_consent or 0),
        "customer_origin": row.customer_origin or "",
        "linked_app_user": row.linked_app_user or "",
        "modified": str(row.modified or ""),
    }


def _manual_customer_item(row) -> dict:
    return {
        "customer_mode": "Walk-in Customer",
        "manual_customer_id": row.name,
        "full_name": row.full_name or "",
        "email": row.email or "",
        "phone": row.mobile or "",
        "cnic": row.cnic or "",
        "city": row.city or "",
        "verification_status": row.verification_status or "",
        "conversion_status": row.conversion_status or "",
        "customer_origin": row.customer_origin or "",
        "modified": str(row.modified or ""),
    }


def _search_or_filters(term: str, fields: tuple[str, ...]):
    term = _text(term)
    if not term:
        return None
    like = f"%{term}%"
    return {field: ["like", like] for field in fields}


@frappe.whitelist()
def get_customer_selection_options(
    customer_mode=None,
    search=None,
    limit_start=0,
    limit_page_length=20,
):
    user = _current_user()
    roles = _roles(user)
    capabilities = _require_internal_assist(user)
    start, length = _pagination(limit_start, limit_page_length)

    modes = []
    if roles.intersection(REFERRAL_OWNER_ROLES | REFERRAL_ADMIN_ROLES):
        modes.append("My Referral")
    if roles.intersection(ALL_CUSTOMER_ASSIST_ROLES):
        modes.append("Existing Customer")
    if roles.intersection(WALK_IN_CUSTOMER_ROLES):
        modes.append("Walk-in Customer")

    selected_mode = _text(customer_mode)
    if not selected_mode:
        return {
            "modes": modes,
            "items": [],
            "limit_start": start,
            "limit_page_length": length,
            "capabilities": {
                "can_create_service_for_customer": bool(
                    capabilities.get("can_create_service_for_customer")
                ),
                "can_use_my_referrals": "My Referral" in modes,
                "can_search_all_customers": "Existing Customer" in modes,
                "can_use_walk_in_customers": "Walk-in Customer" in modes,
            },
        }

    if selected_mode not in modes:
        frappe.throw(
            "You do not have permission to use this customer mode.",
            frappe.PermissionError,
        )

    if selected_mode == "My Referral":
        filters = {
            "referred_by": user,
            "referral_assistance_consent": 1,
            "is_active": 1,
        }
        rows = frappe.get_all(
            "OMC Customer Profile",
            filters=filters,
            or_filters=_search_or_filters(
                search,
                ("name", "full_name", "email", "phone", "cnic"),
            ),
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
                "modified",
            ],
            order_by="modified desc",
            limit_start=start,
            limit_page_length=length,
        )
        items = [_customer_item(row, mode=selected_mode) for row in rows]
    elif selected_mode == "Existing Customer":
        rows = frappe.get_all(
            "OMC Customer Profile",
            filters={"is_active": 1},
            or_filters=_search_or_filters(
                search,
                ("name", "full_name", "email", "phone", "cnic"),
            ),
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
                "modified",
            ],
            order_by="modified desc",
            limit_start=start,
            limit_page_length=length,
        )
        items = [_customer_item(row, mode=selected_mode) for row in rows]
    else:
        filters = {}
        if not roles.intersection(ALL_CUSTOMER_ASSIST_ROLES):
            filters["created_by_user"] = user
        rows = frappe.get_all(
            "OMC Manual Customer",
            filters=filters,
            or_filters=_search_or_filters(
                search,
                ("name", "full_name", "email", "mobile", "cnic", "city"),
            ),
            fields=[
                "name",
                "full_name",
                "email",
                "mobile",
                "cnic",
                "city",
                "verification_status",
                "conversion_status",
                "customer_origin",
                "modified",
            ],
            order_by="modified desc",
            limit_start=start,
            limit_page_length=length,
        )
        items = [_manual_customer_item(row) for row in rows]

    return {
        "modes": modes,
        "selected_mode": selected_mode,
        "items": items,
        "limit_start": start,
        "limit_page_length": length,
    }

def create_request(**kwargs):
    user = _current_user()
    is_internal = mobile._can_access_internal_workspace(user)
    service = _service_doc(kwargs.get("service_id") or kwargs.get("service"))
    submission = submission_integrity.validate_submission(service.name, kwargs)
    pricing = _request_pricing_snapshot(
        service,
        is_internal=is_internal,
        user=user,
        kwargs=kwargs,
    )

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

    active_request = _active_request(service, profile=profile, manual_customer=manual_customer)
    allow_parallel = bool(getattr(service, "allow_parallel_requests", 0))
    if active_request and (not allow_parallel or not frappe.utils.cint(kwargs.get("confirm_parallel"))):
        return _duplicate_response(active_request, allow_parallel=allow_parallel)

    doc = frappe.new_doc("OMC Service Request")
    doc.service = service.name
    doc.service_title = service.title or ""
    doc.title = _text(kwargs.get("title")) or service.title or "Service Request"
    doc.description = submission_integrity.sanitize_description(kwargs.get("description") or "")
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
    if doc.meta.get_field("submission_data_json"):
        doc.submission_data_json = submission["json"]
    if doc.meta.get_field("submission_documents_due_at"):
        doc.submission_documents_due_at = frappe.utils.add_to_date(
            frappe.utils.now_datetime(),
            hours=submission_integrity.DOCUMENT_GRACE_HOURS,
        )
    for fieldname, value in pricing.items():
        if doc.meta.get_field(fieldname):
            doc.set(fieldname, value)

    if profile and customer_mode == "My Referral":
        doc.referral_owner = profile.referred_by
        doc.referral_record = profile.referral_record

    explicit_assignee = _text(kwargs.get("assigned_staff"))
    referral_assignee = (
        doc.referral_owner
        if profile and customer_mode == "My Referral"
        else ""
    )
    assignment_decision = service_assignment.assign_new_request(
        doc,
        service,
        explicit_user=explicit_assignee,
        referral_owner=referral_assignee,
    )
    doc.insert(ignore_permissions=True)

    erp_bridge = erp_service_task_adapter.sync_request(
        doc,
        service=service,
        profile=profile,
        manual_customer=manual_customer,
    )

    if doc.meta.get_field("submission_integrity_status"):
        submission_integrity.evaluate_request(doc)
    assignment_result = service_assignment.apply_assignment(
        doc,
        assignment_decision,
        set_assignee=False,
    )
    assignment_todo = assignment_result.get("todo")

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
    response = _request_response(doc)
    response["assigned_staff"] = doc.assigned_staff or ""
    response["assignment_todo"] = assignment_todo
    response["erp_sync_status"] = erp_bridge.get("status") or ""
    response["erp_customer"] = erp_bridge.get("erp_customer") or ""
    response["erp_service"] = erp_bridge.get("erp_service") or ""
    response["erp_task"] = erp_bridge.get("erp_task") or ""
    response["erp_task_assignment"] = erp_bridge.get("task_assignment")
    response.update(pricing)
    return response
