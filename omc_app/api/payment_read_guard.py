from __future__ import annotations

import base64

import frappe
from frappe.utils import escape_html, flt, fmt_money
from frappe.utils.pdf import get_pdf
from frappe.www import printview

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


def _with_invoice_alias(payload):
    """Keep existing mobile clients compatible with the canonical OMC invoice."""
    if not payload:
        return payload
    result = dict(payload)
    linked_invoice = (result.get("linked_invoice") or "").strip()
    result["invoice_number"] = linked_invoice
    return result


def _submitted_invoice_payment_total(invoice_name):
    """Return submitted ERP Payment Entry allocation against this invoice."""
    rows = frappe.db.sql(
        """
        SELECT COALESCE(SUM(ref.allocated_amount), 0)
        FROM `tabPayment Entry Reference` AS ref
        INNER JOIN `tabPayment Entry` AS pe
            ON pe.name = ref.parent
        WHERE ref.reference_doctype = 'Sales Invoice'
          AND ref.reference_name = %s
          AND pe.docstatus = 1
        """,
        (invoice_name,),
    )

    value = rows[0][0] if rows and rows[0] else 0
    return max(flt(value or 0, 6), 0)


def _render_invoice_pdf_with_outstanding(invoice_name):
    """Render the customer invoice using the client's ERP Sales Format."""
    invoice = frappe.get_doc("Sales Invoice", invoice_name)
    print_format_name = "Sales Format"

    if not frappe.db.exists("Print Format", print_format_name):
        frappe.throw(
            "Customer invoice print format is not available.",
            frappe.ValidationError,
        )

    rendered = printview.get_html_and_style(
        doc=invoice,
        print_format=print_format_name,
        no_letterhead=0,
    )

    body = (rendered or {}).get("html") or ""
    if not body:
        frappe.throw(
            "Invoice print is not available.",
            frappe.ValidationError,
        )

    style = (rendered or {}).get("style") or ""

    # For non-POS invoices, Sales Invoice.paid_amount is not authoritative
    # when settlement occurs through separate Payment Entries.
    # Count only submitted ERP Payment Entry allocations.
    # Cancelled Payment Entries are excluded by docstatus = 1.
    paid_total = _submitted_invoice_payment_total(invoice.name)

    settlement_rows = []

    if "Paid / Settled" not in body:
        paid = escape_html(
            fmt_money(
                paid_total,
                currency=invoice.currency,
            )
        )

        settlement_rows.append(
            f"""
            <div style="margin-bottom: 4px;">
                <span style="font-weight: 600; margin-right: 12px;">
                    Paid / Settled:
                </span>
                <span style="font-weight: 600; white-space: nowrap;">
                    {paid}
                </span>
            </div>
            """
        )

    if "Outstanding Amount" not in body:
        outstanding = escape_html(
            fmt_money(
                invoice.outstanding_amount or 0,
                currency=invoice.currency,
            )
        )

        settlement_rows.append(
            f"""
            <div>
                <span style="font-weight: 600; margin-right: 12px;">
                    Outstanding Amount:
                </span>
                <span style="font-weight: 600; white-space: nowrap;">
                    {outstanding}
                </span>
            </div>
            """
        )

    settlement_html = ""

    if settlement_rows:
        settlement_html = (
            '<div class="omc-invoice-settlement" '
            'style="margin-top: 8px; text-align: right;">'
            + "".join(settlement_rows)
            + "</div>"
        )

    style_block = f"<style>{style}</style>" if style else ""

    html = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
{style_block}
</head>
<body>
<div class="print-format-gutter">
    <div class="print-format">
        {body}
        {settlement_html}
    </div>
</div>
</body>
</html>
"""

    return get_pdf(html)


def _safe_payment_payload(name, *, capabilities, customer_view):
    try:
        payment = _load_readable_payment(name)
        return _with_invoice_alias(
            payments._payment_dict(
                payment,
                capabilities=capabilities,
                customer_view=customer_view,
            )
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

    payload = _with_invoice_alias(
        payments._payment_dict(
            payment,
            capabilities=capabilities,
            customer_view=profile is not None,
        )
    )
    payload["invoice_numbers"] = payments._payment_invoice_numbers(payment)
    payload["receipt_urls"] = (
        payments._payment_receipt_urls(payment)
        if profile is not None or capabilities.get("can_view_payment_receipts")
        else []
    )
    return payload


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
    eligible = sorted(
        {
            name
            for name in links
            if name and frappe.db.get_value("Sales Invoice", name, "docstatus") == 1
        }
    )
    if invoice_id:
        if invoice_id not in eligible:
            _payment_not_found()
        resolved = invoice_id
    else:
        if len(eligible) != 1:
            frappe.throw(
                "Select an invoice when the request has multiple eligible invoices."
                if eligible
                else "Invoice is not available.",
                frappe.ValidationError if eligible else frappe.DoesNotExistError,
            )
        resolved = eligible[0]
    previous_ignore_print_permissions = frappe.local.flags.get(
        "ignore_print_permissions"
    )
    frappe.local.flags.ignore_print_permissions = True
    try:
        content = _render_invoice_pdf_with_outstanding(resolved)
    finally:
        frappe.local.flags.ignore_print_permissions = (
            previous_ignore_print_permissions
        )

    if isinstance(content, str):
        content = content.encode("utf-8")

    return {
        "invoice_id": resolved,
        "file_name": f"{resolved}.pdf",
        "mime_type": "application/pdf",
        "file_content": base64.b64encode(content).decode("ascii"),
    }
