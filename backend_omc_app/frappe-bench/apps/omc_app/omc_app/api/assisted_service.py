from __future__ import annotations

import json

import frappe

from omc_app.api import (
    access,
    erp_customer_resolver,
    idempotency,
    identity,
    mobile,
    referral_attribution,
    security,
    service_assignment,
    submission_integrity,
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
    """Compatibility-only role reader; authorization uses capabilities."""
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
    from omc_app.omc_app.doctype.omc_service.omc_service import pricing_version_for

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

    supplied_service_version = frappe.utils.cint(kwargs.get("service_version") or 0)
    supplied_pricing_version = _text(kwargs.get("pricing_version"))
    current_service_version = frappe.utils.cint(getattr(service, "service_version", 1) or 1)
    current_pricing_version = _text(getattr(service, "pricing_version", None)) or pricing_version_for(service)
    if supplied_service_version != current_service_version or supplied_pricing_version != current_pricing_version:
        frappe.throw(
            "Service pricing changed. Refresh the catalogue and confirm again.",
            frappe.ValidationError,
        )

    tax_policy = _text(getattr(service, "tax_policy", None)) or "No Tax"
    tax_rate = frappe.utils.flt(getattr(service, "tax_rate", None) or 0, 6)
    tax_amount = 0.0
    payable_amount = final_price
    if tax_policy == "Tax Exclusive":
        tax_amount = frappe.utils.flt(final_price * tax_rate / 100, 6)
        payable_amount = frappe.utils.flt(final_price + tax_amount, 6)
    elif tax_policy == "Tax Included" and tax_rate:
        tax_amount = frappe.utils.flt(final_price * tax_rate / (100 + tax_rate), 6)
    activation_policy = _text(getattr(service, "activation_policy", None)) or "Full Settlement"
    if activation_policy == "No Charge" and payable_amount:
        frappe.throw("No Charge services must have a zero payable amount.", frappe.ValidationError)

    snapshot = {
        "activation_policy": activation_policy,
        "base_price": original_price,
        "currency": currency,
        "discount_amount": discount_amount,
        "discount_status": discount_status,
        "payable_amount": payable_amount,
        "pricing_version": current_pricing_version,
        "service_version": current_service_version,
        "tax_amount": tax_amount,
        "tax_policy": tax_policy,
        "tax_rate": tax_rate,
    }

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
        "service_version_snapshot": current_service_version,
        "pricing_version_snapshot": current_pricing_version,
        "payment_policy_snapshot": activation_policy,
        "tax_policy_snapshot": tax_policy,
        "tax_rate_snapshot": tax_rate,
        "tax_amount": tax_amount,
        "payable_amount": payable_amount,
        "pricing_snapshot_json": json.dumps(snapshot, sort_keys=True, separators=(",", ":")),
    }


def _active_request(service, *, profile=None, manual_customer=None):
    duplicate_window = max(
        frappe.utils.cint(getattr(service, "duplicate_window_hours", 24) or 24),
        1,
    )
    filters = {
        "service": service.name,
        "status": ["in", ["Open", "In Progress", "Waiting for Customer", "Waiting for Payment"]],
        "creation": [
            ">=",
            frappe.utils.add_to_date(
                frappe.utils.now_datetime(), hours=-duplicate_window
            ),
        ],
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
        "name": active.name,
        "request_id": active.name,
        "service_request": active.name,
        "case_id": active.name,
        "status": active.status,
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
    if not _capabilities(user).get("can_view_all_customers"):
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


def _manual_customer_profile_matches(manual_customer) -> list[str]:
    identities = {
        "email": _text(getattr(manual_customer, "email", None)).lower(),
        "phone": _text(getattr(manual_customer, "mobile", None)),
        "cnic": _text(getattr(manual_customer, "cnic", None)),
    }

    matches: set[str] = set()
    for fieldname, value in identities.items():
        if not value:
            continue

        rows = frappe.get_all(
            "OMC Customer Profile",
            filters={fieldname: value},
            pluck="name",
            limit=3,
        )
        matches.update(_text(name) for name in rows if _text(name))

        if len(matches) > 1:
            break

    return sorted(matches)


def _create_manual_customer(user: str, kwargs: dict):
    if not _capabilities(user).get("can_manage_customers"):
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
        "request_state": doc.request_state or "Draft",
        "created": True,
        "message": "Service request created.",
        "customer_mode": doc.customer_mode or "",
        "submission_mode": doc.submission_mode or "",
        "customer_profile": doc.customer_profile or "",
        "manual_customer": doc.manual_customer or "",
        "account": doc.customer_account or "",
        "pricing_snapshot": json.loads(doc.pricing_snapshot_json or "{}"),
        "receipt_status": "Not Submitted",
        "accounting_status": "Unmatched",
        "settlement": {"status": "Unmatched", "allocated_amount": 0},
        "activation": {
            "state": doc.request_state or "Draft",
            "erp_service": doc.erp_service or "",
            "erp_task": doc.erp_task or "",
        },
    }


def _approved_account_for_profile(profile):
    name = frappe.db.get_value(
        "OMC Customer Account", {"legacy_customer_profile": profile.name}, "name"
    )
    if not name:
        frappe.throw("Customer account is not available.", frappe.PermissionError)
    account = frappe.get_doc("OMC Customer Account", name)
    if (
        account.identity_proof_status != "Verified"
        or account.account_link_status != "Linked"
        or account.service_access_status != "Approved"
    ):
        frappe.throw("Customer account is not available.", frappe.PermissionError)
    return account



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
    capabilities = _require_internal_assist(user)
    start, length = _pagination(limit_start, limit_page_length)

    modes = []
    if capabilities.get("can_view_referral_commissions"):
        modes.append("My Referral")
    if capabilities.get("can_view_all_customers"):
        modes.append("Existing Customer")

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
        if not capabilities.get("can_view_all_customers"):
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


@frappe.whitelist(methods=["POST"])
def convert_manual_customer(manual_customer=None, request_name=None):
    user = _current_user()

    if not _capabilities(user).get("can_manage_customers"):
        frappe.throw("You do not have permission to convert walk-in customers.", frappe.PermissionError)

    manual_customer = _text(manual_customer)
    request_name = _text(request_name)

    if not manual_customer:
        frappe.throw(
            "manual_customer is required.",
            frappe.ValidationError,
        )

    if not request_name:
        frappe.throw(
            "request_name is required.",
            frappe.ValidationError,
        )

    if not frappe.db.exists("OMC Manual Customer", manual_customer):
        frappe.throw(
            "Walk-in customer not found.",
            frappe.DoesNotExistError,
        )

    if not frappe.db.exists("OMC Service Request", request_name):
        frappe.throw(
            "Service request not found.",
            frappe.DoesNotExistError,
        )

    manual = frappe.get_doc("OMC Manual Customer", manual_customer)
    request = frappe.get_doc("OMC Service Request", request_name)

    if _text(getattr(request, "manual_customer", None)) != manual.name:
        frappe.throw(
            "The service request does not belong to this walk-in customer.",
            frappe.ValidationError,
        )

    email = _text(getattr(manual, "email", None)).lower()
    if not email:
        frappe.throw(
            "A real customer email is required before conversion.",
            frappe.ValidationError,
        )

    identity = _text(
        getattr(manual, "cnic", None)
        or getattr(manual, "ntn", None)
    )
    if not identity:
        frappe.throw(
            "Customer CNIC or NTN is required before conversion.",
            frappe.ValidationError,
        )

    linked_profile = _text(
        getattr(manual, "linked_customer_profile", None)
    )

    if linked_profile:
        if not frappe.db.exists("OMC Customer Profile", linked_profile):
            frappe.throw(
                "The linked customer profile does not exist.",
                frappe.ValidationError,
            )
        profile = frappe.get_doc("OMC Customer Profile", linked_profile)
        created_profile = False
    else:
        matches = _manual_customer_profile_matches(manual)

        if len(matches) > 1:
            frappe.throw(
                (
                    "Multiple customer profiles match this walk-in customer. "
                    "Resolve the duplicate records before conversion."
                ),
                frappe.ValidationError,
            )

        if len(matches) == 1:
            profile = frappe.get_doc("OMC Customer Profile", matches[0])
            created_profile = False
        else:
            profile = frappe.new_doc("OMC Customer Profile")
            profile.full_name = _text(manual.full_name)
            profile.email = email
            profile.phone = _text(manual.mobile)
            profile.cnic = _text(manual.cnic)
            profile.address = _text(manual.address)
            profile.customer_origin = "Walk-in"
            profile.customer_status = "Active"
            profile.approval_status = "Approved"
            profile.is_active = 1
            profile.manual_customer_status = "Linked"
            profile.insert(ignore_permissions=True)
            created_profile = True

    profile.customer_origin = "Walk-in"
    profile.customer_status = "Active"
    profile.approval_status = "Approved"
    profile.is_active = 1
    profile.manual_customer_status = "Linked"

    if not _text(getattr(profile, "full_name", None)):
        profile.full_name = _text(manual.full_name)
    if not _text(getattr(profile, "phone", None)):
        profile.phone = _text(manual.mobile)
    if not _text(getattr(profile, "cnic", None)):
        profile.cnic = _text(manual.cnic)
    if not _text(getattr(profile, "address", None)):
        profile.address = _text(manual.address)

    profile.save(ignore_permissions=True)

    manual.verification_status = "Verified"
    manual.conversion_status = "Linked"
    manual.linked_customer_profile = profile.name
    manual.save(ignore_permissions=True)

    request.customer_profile = profile.name
    frappe.db.set_value(
        "OMC Service Request",
        request.name,
        "customer_profile",
        profile.name,
        update_modified=False,
    )

    customer_result = erp_customer_resolver.resolve_profile_customer(profile)
    customer_status = _text(customer_result.get("status"))

    if customer_status not in {"Resolved", "Created"}:
        frappe.throw(
            customer_result.get("reason")
            or "ERP Customer could not be resolved.",
            frappe.ValidationError,
        )

    service_name = _text(getattr(request, "service", None))
    if not service_name or not frappe.db.exists("OMC Service", service_name):
        frappe.throw(
            "The linked OMC Service is missing.",
            frappe.ValidationError,
        )

    sync_result = erp_activation.activate_request(
        request,
        service=frappe.get_doc("OMC Service", service_name),
        profile=profile,
        manual_customer=manual,
        repair=True,
    )

    return {
        "manual_customer": manual.name,
        "customer_profile": profile.name,
        "profile_created": created_profile,
        "erp_customer": customer_result.get("customer") or "",
        "erp_customer_created": bool(customer_result.get("created")),
        "erp_sync_status": sync_result.get("status") or "",
        "erp_service": sync_result.get("erp_service") or "",
        "erp_task": sync_result.get("erp_task") or "",
        "task_assignment": sync_result.get("task_assignment"),
        "reason": sync_result.get("reason") or "",
    }



@frappe.whitelist(methods=["POST"])
def create_request(**kwargs):
    actor = _current_user()
    security.enforce_rate_limit("service_request", actor=actor)
    if not idempotency.request_key(kwargs):
        frappe.throw("An idempotency key is required.", frappe.ValidationError)
    claim = idempotency.begin(
        operation="service_request.create",
        actor=actor,
        payload=kwargs,
    )
    if claim and claim.replay is not None:
        return claim.replay
    try:
        response = _create_request(**kwargs)
        reference_name = _text(
            response.get("request_id")
            or response.get("name")
            or (response.get("active_request") or {}).get("name")
        )
        return idempotency.complete(
            claim,
            response,
            reference_doctype="OMC Service Request",
            reference_name=reference_name,
        )
    except Exception:
        idempotency.fail(claim)
        raise


def _create_request(**kwargs):
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

    if not frappe.utils.cint(kwargs.get("final_confirmation")):
        frappe.throw("Final confirmation is required.", frappe.ValidationError)

    if not is_internal:
        customer_context = identity.require_customer_context()
        profile = frappe.get_doc("OMC Customer Profile", customer_context.legacy_profile)
        account = frappe.get_doc("OMC Customer Account", customer_context.account_name)
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
            frappe.throw(
                "Walk-in customers must be reconciled to an approved Customer Account before request creation.",
                frappe.ValidationError,
            )
        account = _approved_account_for_profile(profile)

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
    doc.request_state = (
        "Payment Not Required"
        if pricing["payment_policy_snapshot"] == "No Charge" and not pricing["payable_amount"]
        else "Pending Payment"
    )
    doc.final_confirmation = 1
    doc.submitted_at = frappe.utils.now_datetime()
    doc.expires_at = frappe.utils.add_to_date(
        doc.submitted_at,
        hours=max(frappe.utils.cint(getattr(service, "pending_payment_expiry_hours", 72) or 72), 1),
    )
    doc.customer_profile = profile.name if profile else ""
    doc.customer_account = account.name
    doc.erp_customer = account.erp_customer
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

    doc.insert(ignore_permissions=True)

    if doc.referral_record:
        attribution = referral_attribution.request_snapshot(
            request=doc,
            account=account,
            referral_registry=doc.referral_record,
        )
        frappe.db.set_value(
            doc.doctype, doc.name, "referral_attribution", attribution.name, update_modified=False
        )
        doc.referral_attribution = attribution.name

    # Request creation is payment-first. ERP Service/Task activation is owned by
    # bridge_outbox after payment/No-Charge eligibility has been satisfied; the
    # create transaction must never call the legacy activation adapter directly.
    if doc.meta.get_field("submission_integrity_status"):
        submission_integrity.evaluate_request(doc)

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

    response = _request_response(doc)
    response["assigned_staff"] = doc.assigned_staff or ""
    response["assignment_todo"] = None
    response["erp_sync_status"] = "Not Started"
    response["erp_customer"] = doc.erp_customer or ""
    response["erp_service"] = doc.erp_service or ""
    response["erp_task"] = doc.erp_task or ""
    response["erp_task_assignment"] = None
    response.update(pricing)
    return response