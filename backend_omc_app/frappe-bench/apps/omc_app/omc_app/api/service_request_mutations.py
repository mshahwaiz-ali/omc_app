from __future__ import annotations

import frappe

from omc_app.api import access, identity, mobile, request_lifecycle, security


def _text(value) -> str:
    return str(value or "").strip()


def _request_name(case_id=None, name=None, service_request=None, request_id=None) -> str:
    value = _text(case_id or name or service_request or request_id)
    if not value:
        frappe.throw("Service request reference is required.", frappe.ValidationError)
    return value


def _current_user() -> str:
    user = _text(getattr(getattr(frappe, "session", None), "user", None))
    if not user or user == "Guest":
        frappe.throw("Login is required.", frappe.PermissionError)
    return user


def _customer_owned_request(request_name: str):
    context = identity.require_customer_context()
    request = frappe.get_doc("OMC Service Request", request_name)
    if not identity.request_is_owned(request, context):
        frappe.throw(
            "Only the owning customer can cancel this service request.",
            frappe.PermissionError,
        )
    return request


def _customer_cancellation_allowed(request) -> bool:
    if _text(request.request_state) not in {
        "Draft",
        "Pending Payment",
        "Payment Not Required",
        "Ready for Activation",
        "Activation Failed",
    }:
        return False
    # Once ERP accounting has been linked, finance/staff must review the
    # cancellation so accepted settlement is never silently discarded.
    if frappe.db.exists("OMC Accounting Link", {"service_request": request.name}):
        return False
    return True


@frappe.whitelist(methods=["POST"])
def cancel_service_request(
    case_id=None,
    name=None,
    service_request=None,
    request_id=None,
    reason=None,
):
    security.enforce_rate_limit("staff_mutation")
    request_name = _request_name(case_id, name, service_request, request_id)
    user = _current_user()

    if user == "Administrator":
        request = frappe.get_doc("OMC Service Request", request_name)
        customer_cancelled = False
        capability = "framework_recovery"
    elif mobile._can_access_internal_workspace(user):
        capabilities = access.get_mobile_capabilities(user=user)
        if not (
            capabilities.get("can_update_service_status")
            or capabilities.get("can_update_assigned_service_status")
        ):
            frappe.throw(
                "You do not have permission to cancel service requests.",
                frappe.PermissionError,
            )
        # Reuse the canonical assigned/all-case scope check rather than broad
        # role membership.
        mobile._require_service_case_update_scope(request_name)
        request = frappe.get_doc("OMC Service Request", request_name)
        customer_cancelled = False
        capability = (
            "can_update_service_status"
            if capabilities.get("can_update_service_status")
            else "can_update_assigned_service_status"
        )
    else:
        request = _customer_owned_request(request_name)
        if not _customer_cancellation_allowed(request):
            frappe.throw(
                "This request requires OMC review before it can be cancelled.",
                frappe.ValidationError,
            )
        customer_cancelled = True
        capability = "customer_ownership"

    cancellation_reason = _text(reason) or (
        "Service request cancelled by customer."
        if customer_cancelled
        else "Service request cancelled by authorized staff."
    )
    if request.request_state == "Cancelled":
        return {
            "service_request": request.name,
            "request_state": "Cancelled",
            "status": "Cancelled",
            "message": "Service request is already cancelled.",
            "can_cancel": False,
        }

    result = request_lifecycle.transition_request_state(
        request.name,
        "Cancelled",
        reason=cancellation_reason,
        actor=user,
        capability=capability,
        customer_cancelled=customer_cancelled,
        idempotency_key=f"cancel:{request.name}",
    )
    request = result.request
    request.add_comment("Comment", cancellation_reason)
    return {
        "service_request": request.name,
        "request_state": request.request_state,
        "status": request.status,
        "message": "Service request cancelled successfully.",
        "can_cancel": False,
    }


@frappe.whitelist(methods=["POST"])
def update_service_case_status(
    case_id=None,
    name=None,
    service_request=None,
    request_id=None,
    status=None,
    note=None,
    expected_completion_date=None,
):
    security.enforce_rate_limit("staff_mutation")
    request_name = _request_name(case_id, name, service_request, request_id)
    user = _current_user()
    _user, capabilities = mobile._require_service_case_update_scope(request_name)
    target = _text(status)
    if not target:
        frappe.throw("status is required.", frappe.ValidationError)

    capability = (
        "can_update_service_status"
        if capabilities.get("can_update_service_status")
        else "can_update_assigned_service_status"
    )
    result = request_lifecycle.update_operational_status(
        request_name,
        target,
        reason=_text(note),
        actor=user,
        capability=capability,
    )
    request = result.request

    if expected_completion_date is not None:
        frappe.db.set_value(
            request.doctype,
            request.name,
            "expected_completion_date",
            expected_completion_date or None,
            update_modified=False,
        )
        request.expected_completion_date = expected_completion_date or None
        security.audit_event(
            event_type="service_request.expected_completion_updated",
            capability=capability,
            target_doctype=request.doctype,
            target_name=request.name,
            safe_reason="staff_update",
            actor=user,
        )

    return {
        "name": request.name,
        "request_state": request.request_state,
        "status": request.status,
        "updated": bool(result.changed or expected_completion_date is not None),
        "message": "Service case updated.",
    }
