from __future__ import annotations

import frappe

from omc_app.api import access, mobile, payments


def _payment_not_found():
    frappe.throw("Payment not found", frappe.DoesNotExistError)


def _load_readable_payment(payment_id):
    if not payment_id or not frappe.db.exists(payments.PAYMENT_DOCTYPE, payment_id):
        _payment_not_found()

    payment = frappe.get_doc(payments.PAYMENT_DOCTYPE, payment_id)
    service_request = (getattr(payment, "service_request", None) or "").strip()
    if not service_request or not frappe.db.exists(
        "OMC Service Request",
        service_request,
    ):
        _payment_not_found()
    return payment


def _safe_payment_payload(name, *, capabilities, customer_view):
    try:
        payment = _load_readable_payment(name)
        return payments._payment_dict(
            payment,
            capabilities=capabilities,
            customer_view=customer_view,
        )
    except frappe.DoesNotExistError:
        return None


@frappe.whitelist()
def get_payments():
    is_internal = mobile._can_access_internal_workspace()
    profile = None if is_internal else mobile._assert_approved_customer()
    capabilities = access.get_mobile_capabilities()

    if is_internal and not (
        capabilities.get("can_view_payment_queue")
        or capabilities.get("can_view_payment_summaries")
        or capabilities.get("can_review_payments")
    ):
        frappe.throw(
            "You do not have permission to view payments.",
            frappe.PermissionError,
        )

    service_request_names = [
        row.name
        for row in payments._accessible_service_requests(
            profile=profile,
            internal_user=payments._current_user() if is_internal else None,
        )
    ]
    if not service_request_names:
        return {"payments": []}

    payment_names = frappe.get_all(
        payments.PAYMENT_DOCTYPE,
        filters={
            "service_request": ["in", service_request_names],
            "visible_to_customer": 1,
        },
        pluck="name",
        order_by="due_date desc, creation desc",
    )

    rows = []
    for name in payment_names:
        payload = _safe_payment_payload(
            name,
            capabilities=capabilities,
            customer_view=profile is not None,
        )
        if payload:
            rows.append(payload)
    return {"payments": rows}


@frappe.whitelist()
def get_payment(payment_id=None, name=None):
    resolved_id = payment_id or name
    if not resolved_id:
        frappe.throw("payment_id is required")

    payment = _load_readable_payment(resolved_id)
    if not payment.visible_to_customer:
        _payment_not_found()

    is_internal = mobile._can_access_internal_workspace()
    profile = None if is_internal else mobile._assert_approved_customer()
    capabilities = access.get_mobile_capabilities()

    payments._assert_service_request_payment_access(
        payment.service_request,
        profile=profile,
        internal_user=payments._current_user() if is_internal else None,
    )

    if is_internal and not (
        capabilities.get("can_view_payment_summaries")
        or capabilities.get("can_view_payment_receipts")
        or capabilities.get("can_review_payments")
    ):
        frappe.throw(
            "You do not have permission to access this payment.",
            frappe.PermissionError,
        )

    return payments._payment_dict(
        payment,
        capabilities=capabilities,
        customer_view=profile is not None,
    )
