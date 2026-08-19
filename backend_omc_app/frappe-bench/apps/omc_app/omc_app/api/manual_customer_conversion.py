from __future__ import annotations

import frappe

from omc_app.api import (
    access,
    bridge_outbox,
    erp_customer_resolver,
    identity,
    payment_opening,
    security,
)


def _text(value) -> str:
    return str(value or "").strip()


def _profile_matches(manual_customer) -> list[str]:
    identities = {
        "email": _text(getattr(manual_customer, "email", None)).lower(),
        "phone": _text(getattr(manual_customer, "mobile", None)),
        "cnic": _text(getattr(manual_customer, "cnic", None)),
    }
    matches: set[str] = set()
    for fieldname, value in identities.items():
        if not value:
            continue
        matches.update(
            frappe.get_all(
                "OMC Customer Profile",
                filters={fieldname: value},
                pluck="name",
                limit_page_length=3,
            )
        )
        if len(matches) > 1:
            break
    return sorted(_text(name) for name in matches if _text(name))


def _resolve_profile(manual):
    linked = _text(getattr(manual, "linked_customer_profile", None))
    if linked:
        if not frappe.db.exists("OMC Customer Profile", linked):
            frappe.throw(
                "The linked customer profile does not exist.",
                frappe.ValidationError,
            )
        return frappe.get_doc("OMC Customer Profile", linked), False

    matches = _profile_matches(manual)
    if len(matches) > 1:
        frappe.throw(
            "Multiple customer profiles match this walk-in customer. Resolve the duplicate records before conversion.",
            frappe.ValidationError,
        )
    if matches:
        return frappe.get_doc("OMC Customer Profile", matches[0]), False

    email = _text(manual.email).lower()
    identity_value = _text(manual.cnic) or _text(getattr(manual, "ntn", None))
    if not email:
        frappe.throw(
            "A real customer email is required before conversion.",
            frappe.ValidationError,
        )
    if not identity_value:
        frappe.throw(
            "Customer CNIC or NTN is required before conversion.",
            frappe.ValidationError,
        )

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
    return profile, True


def _sync_profile(profile, manual) -> None:
    profile.customer_origin = "Walk-in"
    profile.customer_status = "Active"
    profile.approval_status = "Approved"
    profile.is_active = 1
    profile.manual_customer_status = "Linked"
    if not _text(profile.full_name):
        profile.full_name = _text(manual.full_name)
    if not _text(profile.phone):
        profile.phone = _text(manual.mobile)
    if not _text(profile.cnic):
        profile.cnic = _text(manual.cnic)
    if not _text(profile.address):
        profile.address = _text(manual.address)
    profile.save(ignore_permissions=True)


def _optional_customer_account(profile, erp_customer: str) -> str:
    user = _text(profile.user or profile.linked_app_user or profile.email).lower()
    if not user or not frappe.db.exists("User", user):
        return ""
    account = identity.ensure_customer_account_from_legacy(user)
    if not account:
        return ""
    if erp_customer and _text(account.erp_customer) != erp_customer:
        frappe.db.set_value(
            "OMC Customer Account",
            account.name,
            {
                "erp_customer": erp_customer,
                "account_link_status": "Linked",
                "mapping_provenance": "Reviewed Reconciliation",
                "mapping_confidence": "Reviewed",
            },
            update_modified=False,
        )
    return account.name


@frappe.whitelist(methods=["POST"])
def convert_manual_customer(manual_customer=None, request_name=None):
    values = access.get_mobile_capabilities()
    if not values.get("can_manage_customers"):
        frappe.throw(
            "You do not have permission to convert walk-in customers.",
            frappe.PermissionError,
        )
    security.enforce_rate_limit("staff_mutation")

    manual_name = _text(manual_customer)
    request_name = _text(request_name)
    if not manual_name or not request_name:
        frappe.throw(
            "manual_customer and request_name are required.",
            frappe.ValidationError,
        )
    if not frappe.db.exists("OMC Manual Customer", manual_name):
        frappe.throw("Walk-in customer not found.", frappe.DoesNotExistError)
    locked = frappe.db.get_value(
        "OMC Service Request",
        request_name,
        "name",
        for_update=True,
    )
    if not locked:
        frappe.throw("Service request not found.", frappe.DoesNotExistError)

    manual = frappe.get_doc("OMC Manual Customer", manual_name)
    request = frappe.get_doc("OMC Service Request", locked)
    if _text(request.manual_customer) != manual.name:
        frappe.throw(
            "The service request does not belong to this walk-in customer.",
            frappe.ValidationError,
        )

    profile, created_profile = _resolve_profile(manual)
    _sync_profile(profile, manual)
    customer_result = erp_customer_resolver.resolve_profile_customer(profile)
    if _text(customer_result.get("status")) not in {"Resolved", "Created"}:
        frappe.throw(
            customer_result.get("reason") or "ERP Customer could not be resolved.",
            frappe.ValidationError,
        )
    erp_customer = _text(customer_result.get("customer"))
    account_name = _optional_customer_account(profile, erp_customer)

    manual.verification_status = "Verified"
    manual.conversion_status = "Linked"
    manual.linked_customer_profile = profile.name
    manual.save(ignore_permissions=True)

    values = {
        "customer_profile": profile.name,
        "erp_customer": erp_customer,
    }
    if account_name:
        values["customer_account"] = account_name
    frappe.db.set_value(
        "OMC Service Request",
        request.name,
        values,
        update_modified=False,
    )

    # Conversion only repairs identity/customer linkage. It never creates ERP
    # Service/Task records directly. Financial opening and the durable bridge
    # own all activation work after the canonical eligibility gates pass.
    payment_name = payment_opening.ensure_service_payment(request.name)
    operation = bridge_outbox.enqueue_if_eligible(request.name)
    security.audit_event(
        event_type="customer.manual_conversion_completed",
        capability="can_manage_customers",
        target_doctype="OMC Service Request",
        target_name=request.name,
        new_state="customer_linked",
        safe_reason="legacy_walk_in_conversion",
    )
    return {
        "manual_customer": manual.name,
        "customer_profile": profile.name,
        "customer_account": account_name,
        "profile_created": created_profile,
        "erp_customer": erp_customer,
        "erp_customer_created": bool(customer_result.get("created")),
        "payment": payment_name or "",
        "bridge_operation": operation or "",
        "erp_sync_status": "Queued" if operation else "Not Eligible",
        "erp_service": _text(frappe.db.get_value("OMC Service Request", request.name, "erp_service")),
        "erp_task": _text(frappe.db.get_value("OMC Service Request", request.name, "erp_task")),
    }
