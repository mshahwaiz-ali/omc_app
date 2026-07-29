from __future__ import annotations

import frappe

from omc_app.api import mobile, payments
from omc_app.omc_app.doctype.omc_service_payment.omc_service_payment import (
    TERMINAL_PAYMENT_STATUSES,
    TERMINAL_SERVICE_REQUEST_STATUSES,
)


def _payment_id(payment_id=None, name=None):
    value = payment_id or name
    if not value:
        frappe.throw("payment_id is required")
    return value


def _load_mutable_payment(payment_id):
    if not frappe.db.exists(payments.PAYMENT_DOCTYPE, payment_id):
        frappe.throw("Payment not found", frappe.DoesNotExistError)

    payment = frappe.get_doc(payments.PAYMENT_DOCTYPE, payment_id)
    status = (payment.status or "").strip()
    if status in TERMINAL_PAYMENT_STATUSES:
        frappe.throw(f"Payment {payment.name} is already {status} and cannot be changed.")

    request_status = frappe.db.get_value(
        "OMC Service Request",
        payment.service_request,
        "status",
    )
    if request_status in TERMINAL_SERVICE_REQUEST_STATUSES:
        frappe.throw(
            f"Payment cannot be changed after service request {payment.service_request} "
            f"is {request_status}."
        )
    return payment


def _same_text(current, requested):
    return requested is None or (current or "") == (requested or "")


def _review_is_noop(payment, *, status, remarks=None, payment_reference=None):
    return (
        (payment.status or "") == (status or "")
        and _same_text(payment.remarks, remarks)
        and _same_text(payment.payment_reference, payment_reference)
    )


def _noop_review_response(payment):
    return {
        "updated": False,
        "name": payment.name,
        "case_id": payment.service_request,
        "old_status": payment.status,
        "status": payment.status,
        "paid_on": mobile._format_datetime(payment.paid_on),
        "receipt_url": payment.receipt_attachment or "",
        "payment_reference": payment.payment_reference or "",
        "remarks": payment.remarks or "",
        "case_status": frappe.db.get_value(
            "OMC Service Request",
            payment.service_request,
            "status",
        )
        or "",
        "case_transition_status": None,
        "message": "Payment receipt already has this status.",
    }


@frappe.whitelist()
def upload_payment_receipt_file(
    payment_id=None,
    name=None,
    file_name=None,
    content_base64=None,
    payment_reference=None,
    remarks=None,
):
    resolved_id = _payment_id(payment_id, name)
    _load_mutable_payment(resolved_id)
    return payments.upload_payment_receipt_file(
        payment_id=resolved_id,
        file_name=file_name,
        content_base64=content_base64,
        payment_reference=payment_reference,
        remarks=remarks,
    )


@frappe.whitelist()
def review_payment_receipt(
    payment_id=None,
    name=None,
    status=None,
    remarks=None,
    payment_reference=None,
):
    resolved_id = _payment_id(payment_id, name)
    payment = _load_mutable_payment(resolved_id)
    if _review_is_noop(
        payment,
        status=status,
        remarks=remarks,
        payment_reference=payment_reference,
    ):
        return _noop_review_response(payment)

    return payments.review_payment_receipt(
        payment_id=resolved_id,
        status=status,
        remarks=remarks,
        payment_reference=payment_reference,
    )
