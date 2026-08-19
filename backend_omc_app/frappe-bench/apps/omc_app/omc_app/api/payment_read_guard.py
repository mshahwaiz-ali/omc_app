from __future__ import annotations

import frappe

from omc_app.api import access, capabilities, identity, mobile, payments, security


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
def get_payments(
    limit_start=0,
    limit_page_length=50,
    search=None,
    status=None,
):
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
        return {
            "payments": [],
            "limit_start": 0,
            "limit_page_length": 0,
            "total": 0,
            "has_more": False,
        }

    try:
        start = max(int(limit_start or 0), 0)
        page_length = min(max(int(limit_page_length or 50), 1), 100)
    except (TypeError, ValueError):
        frappe.throw("Invalid payment pagination values.", frappe.ValidationError)

    payment_rows = frappe.get_all(
        payments.PAYMENT_DOCTYPE,
        filters={
            "service_request": ["in", service_request_names],
            "visible_to_customer": 1,
        },
        fields=[
            "name",
            "payment_title",
            "payment_reference",
            "status",
            "service_request",
        ],
        order_by="due_date desc, creation desc",
        limit_page_length=1000,
    )

    status_values = {
        payments._clean_text(value).lower()
        for value in payments._clean_text(status).split(",")
        if payments._clean_text(value)
    }
    query = payments._clean_text(search).lower()
    case_context = {
        row.name: " ".join(
            payments._clean_text(row.get(fieldname))
            for fieldname in (
                "customer_name",
                "customer_profile",
                "service_title",
                "service",
            )
        ).lower()
        for row in frappe.get_all(
            "OMC Service Request",
            filters={"name": ["in", service_request_names]},
            fields=[
                "name",
                "customer_name",
                "customer_profile",
                "service_title",
                "service",
            ],
            limit_page_length=1000,
        )
    }
    filtered_rows = []
    for row in payment_rows:
        if status_values and payments._clean_text(row.status).lower() not in status_values:
            continue
        if query:
            haystack = " ".join(
                (
                    payments._clean_text(row.name),
                    payments._clean_text(row.payment_title),
                    payments._clean_text(row.payment_reference),
                    payments._clean_text(row.service_request),
                    case_context.get(row.service_request, ""),
                )
            ).lower()
            if query not in haystack:
                continue
        filtered_rows.append(row)

    valid_payloads = []
    for row in filtered_rows:
        payload = _safe_payment_payload(
            row.name,
            capabilities=capabilities,
            customer_view=profile is not None,
        )
        if payload:
            valid_payloads.append(payload)
    total = len(valid_payloads)
    rows = valid_payloads[start : start + page_length]
    return {
        "payments": rows,
        "limit_start": start,
        "limit_page_length": page_length,
        "total": total,
        "has_more": start + len(rows) < total,
    }


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


@frappe.whitelist()
def download_invoice_pdf(payment_id=None, invoice_id=None):
    payment_id = str(payment_id or "").strip()
    invoice_id = str(invoice_id or "").strip()
    payment = _load_readable_payment(payment_id)
    user = identity.current_user()
    if access.is_internal_user(user):
        values = capabilities.effective(user)
        if not (
            values.get("can_view_payment_summaries")
            or values.get("can_view_payment_receipts")
            or values.get("can_reconcile_settlement")
        ):
            _payment_not_found()
    else:
        identity.require_owned_request(payment.service_request)
    security.enforce_rate_limit("authenticated_list", actor=user)
    links = frappe.get_all(
        "OMC Accounting Link",
        filters={
            "service_request": payment.service_request,
            "payment_entry": ["is", "not set"],
            "invoice_docstatus": 1,
        },
        pluck="sales_invoice",
        order_by="creation asc, name asc",
        limit_page_length=100,
    )
    eligible = sorted({name for name in links if name and frappe.db.get_value("Sales Invoice", name, "docstatus") == 1})
    if invoice_id:
        if invoice_id not in eligible:
            _payment_not_found()
        resolved = invoice_id
    else:
        if len(eligible) != 1:
            frappe.throw(
                "Select an invoice when the request has multiple eligible invoices."
                if eligible else "Invoice is not available.",
                frappe.ValidationError if eligible else frappe.DoesNotExistError,
            )
        resolved = eligible[0]
    content = frappe.get_print("Sales Invoice", resolved, as_pdf=True)
    frappe.local.response.filename = f"{resolved}.pdf"
    frappe.local.response.filecontent = content
    frappe.local.response.type = "download"
