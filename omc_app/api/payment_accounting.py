from __future__ import annotations

import hashlib

import frappe
from frappe.utils import add_to_date, flt, now_datetime, nowdate

from omc_app.api import accounting_reconciliation, access, payments, security


RECEIPT_DOCTYPE = "OMC Payment Receipt"
MAX_ATTEMPTS = 5


def _text(value) -> str:
    return str(value or "").strip()


def _current_user() -> str:
    return _text(getattr(getattr(frappe, "session", None), "user", None)) or "Guest"


def _require_review_access() -> dict:
    values = access.get_mobile_capabilities()
    if not values.get("can_review_payments"):
        frappe.throw("You do not have permission to review payments.", frappe.PermissionError)
    return values


def _assigned_review_todo(payment_name: str, actor: str):
    return frappe.db.get_value(
        "ToDo",
        {
            "reference_type": payments.PAYMENT_DOCTYPE,
            "reference_name": payment_name,
            "allocated_to": actor,
            "status": ["not in", ["Closed", "Cancelled"]],
        },
        "name",
    )


def _assert_assigned_reviewer(payment, actor: str) -> str:
    todo = _assigned_review_todo(payment.name, actor)
    if not todo:
        frappe.throw(
            "This payment review is assigned to another reviewer. Reassign the review before verifying or rejecting it.",
            frappe.PermissionError,
        )
    return todo


def _base_link(request_name: str):
    return frappe.db.get_value(
        "OMC Accounting Link",
        {"base_request_key": request_name},
        ["name", "sales_invoice", "accounting_status"],
        as_dict=True,
    )


def _remaining_amount(payment) -> float:
    link = _base_link(payment.service_request)
    if not link:
        return max(flt(payment.amount or 0, 6), 0)
    result = accounting_reconciliation.reconcile_request(payment.service_request)
    return max(flt(result.get("remaining_amount") or 0, 6), 0)


def _mapped_payment_accounts(*, company: str, currency: str) -> list[dict]:
    rows = frappe.get_all(
        "OMC Payment Account",
        filters={"is_active": 1},
        fields=[
            "name",
            "title",
            "currency",
            "erp_account",
            "mode_of_payment",
        ],
        order_by="sort_order asc, modified desc",
        limit_page_length=100,
    )
    result = []
    for row in rows:
        account_name = _text(row.erp_account)
        if not account_name or not frappe.db.exists("Account", account_name):
            continue
        account = frappe.db.get_value(
            "Account",
            account_name,
            ["company", "is_group", "root_type", "account_currency"],
            as_dict=True,
        )
        if not account or account.company != company or int(account.is_group or 0):
            continue
        if _text(account.root_type) != "Asset":
            continue
        account_currency = _text(account.account_currency)
        configured_currency = _text(row.currency)
        if account_currency and account_currency != currency:
            continue
        if configured_currency and configured_currency != currency:
            continue
        result.append(
            {
                "name": row.name,
                "title": _text(row.title) or row.name,
                "erp_account": account_name,
                "mode_of_payment": _text(row.mode_of_payment),
            }
        )
    return result


def _service_accounting_config(request):
    if not request.service or not frappe.db.exists("OMC Service", request.service):
        frappe.throw("The request has no valid OMC Service configuration.", frappe.ValidationError)
    service = frappe.get_doc("OMC Service", request.service)
    invoice_item = _text(getattr(service, "erp_invoice_item", None))
    if not invoice_item or not frappe.db.exists("Item", invoice_item):
        frappe.throw(
            "Configure an ERP Invoice Item on this OMC Service before verifying payment.",
            frappe.ValidationError,
        )
    if not int(frappe.db.get_value("Item", invoice_item, "is_sales_item") or 0):
        frappe.throw("The configured ERP Invoice Item is not a sales item.", frappe.ValidationError)
    tax_amount = flt(getattr(request, "tax_amount", 0) or 0, 6)
    tax_template = _text(getattr(service, "erp_sales_taxes_and_charges_template", None))
    if tax_amount > 0 and (
        not tax_template
        or not frappe.db.exists("Sales Taxes and Charges Template", tax_template)
    ):
        frappe.throw(
            "Configure the ERP Sales Taxes and Charges Template for this taxed OMC Service before verifying payment.",
            frappe.ValidationError,
        )
    return service, invoice_item, tax_template


def _preflight(payment, payment_account=None):
    request = frappe.get_doc("OMC Service Request", payment.service_request)
    company = _text(getattr(request, "company_snapshot", None))
    currency = _text(getattr(request, "pricing_currency", None)) or _text(payment.currency)
    customer = _text(getattr(request, "erp_customer", None))
    if not company or not frappe.db.exists("Company", company):
        frappe.throw("The service request has no valid ERP Company snapshot.", frappe.ValidationError)
    if not customer or not frappe.db.exists("Customer", customer):
        frappe.throw("The service request has no valid ERP Customer mapping.", frappe.ValidationError)
    if not currency:
        frappe.throw("The service request has no pricing currency.", frappe.ValidationError)
    service, invoice_item, tax_template = _service_accounting_config(request)
    accounts = _mapped_payment_accounts(company=company, currency=currency)
    selected = _text(payment_account)
    if selected:
        match = next((row for row in accounts if row["name"] == selected), None)
        if not match:
            frappe.throw(
                "The selected OMC Payment Account is not mapped to a valid ERP asset account for this company and currency.",
                frappe.ValidationError,
            )
    elif len(accounts) == 1:
        match = accounts[0]
    elif not accounts:
        frappe.throw(
            "Configure an ERP Account on an active OMC Payment Account before verifying payment.",
            frappe.ValidationError,
        )
    else:
        frappe.throw("Select the bank/cash account where this payment was received.", frappe.ValidationError)
    return {
        "request": request,
        "service": service,
        "invoice_item": invoice_item,
        "tax_template": tax_template,
        "payment_account": match,
        "company": company,
        "currency": currency,
        "customer": customer,
    }


def _source_key(payment, receipt_attachment: str) -> str:
    return hashlib.sha256(
        f"{payment.name}|{receipt_attachment}".encode("utf-8")
    ).hexdigest()


def _receipt_for_current_evidence(payment):
    attachment = _text(payment.receipt_attachment)
    if not attachment:
        frappe.throw("A receipt must be uploaded before payment verification.", frappe.ValidationError)
    key = _source_key(payment, attachment)
    name = frappe.db.get_value(RECEIPT_DOCTYPE, {"source_key": key}, "name")
    return frappe.get_doc(RECEIPT_DOCTYPE, name) if name else None, key


def _create_receipt_evidence(payment, *, key: str, actor: str):
    doc = frappe.new_doc(RECEIPT_DOCTYPE)
    doc.service_payment = payment.name
    doc.service_request = payment.service_request
    doc.source_key = key
    doc.receipt_attachment = payment.receipt_attachment
    doc.submitted_reference = payment.payment_reference
    doc.submitted_remarks = payment.remarks
    doc.submitted_by = payment.owner
    doc.submitted_at = payment.modified
    doc.currency = payment.currency or "PKR"
    doc.review_status = "Submitted"
    doc.verification_source = "Manual"
    doc.accounting_state = "Not Started"
    doc.insert(ignore_permissions=True)
    return doc


def _queue_receipt(receipt_name: str) -> None:
    frappe.enqueue(
        "omc_app.api.payment_accounting.process_receipt",
        queue="short",
        enqueue_after_commit=True,
        job_name=f"omc-payment-{receipt_name}",
        receipt_name=receipt_name,
    )


@frappe.whitelist()
def get_review_context(payment_id=None, name=None):
    _require_review_access()
    payment_id = _text(payment_id or name)
    if not payment_id or not frappe.db.exists(payments.PAYMENT_DOCTYPE, payment_id):
        frappe.throw("Payment not found", frappe.DoesNotExistError)
    payment = frappe.get_doc(payments.PAYMENT_DOCTYPE, payment_id)
    actor = _current_user()
    _assert_assigned_reviewer(payment, actor)
    request = frappe.get_doc("OMC Service Request", payment.service_request)
    company = _text(request.company_snapshot)
    currency = _text(request.pricing_currency) or _text(payment.currency) or "PKR"
    accounts = _mapped_payment_accounts(company=company, currency=currency)
    return {
        "payment": payment.name,
        "currency": currency,
        "remaining_amount": _remaining_amount(payment),
        "payment_accounts": accounts,
    }


def review_receipt(
    *,
    payment_id: str,
    decision: str,
    remarks=None,
    payment_reference=None,
    verified_amount=None,
    payment_account=None,
    verification_source="Manual",
    gateway_transaction_id=None,
):
    _require_review_access()
    actor = _current_user()
    if not payment_id or not frappe.db.exists(payments.PAYMENT_DOCTYPE, payment_id):
        frappe.throw("Payment not found", frappe.DoesNotExistError)
    payment = frappe.get_doc(payments.PAYMENT_DOCTYPE, payment_id)
    _assert_assigned_reviewer(payment, actor)
    decision = _text(decision).lower()
    if decision not in {"verified", "rejected"}:
        frappe.throw("decision must be Verified or Rejected.", frappe.ValidationError)

    existing, key = _receipt_for_current_evidence(payment)
    if existing and existing.review_status in {"Verified", "Rejected"}:
        return {
            **payments._payment_dict(payment, capabilities=access.get_mobile_capabilities()),
            "updated": False,
            "receipt_evidence": existing.name,
            "message": f"Receipt is already {existing.review_status.lower()}.",
        }
    receipt = existing or _create_receipt_evidence(payment, key=key, actor=actor)

    if decision == "rejected":
        clean_remarks = _text(remarks)
        if not clean_remarks:
            frappe.throw("Review remarks are required when rejecting a payment.", frappe.ValidationError)
        response = payments.review_payment_receipt(
            payment_id=payment.name,
            status="Rejected",
            remarks=clean_remarks,
            payment_reference=payment_reference,
        )
        receipt.reload()
        receipt.review_status = "Rejected"
        receipt.reviewed_by = actor
        receipt.reviewed_at = now_datetime()
        receipt.verification_source = _text(verification_source) or "Manual"
        receipt.gateway_transaction_id = _text(gateway_transaction_id)
        receipt.accounting_state = "Cancelled"
        receipt.save(ignore_permissions=True)
        security.audit_event(
            event_type="payment.receipt_rejected",
            capability="can_review_payments",
            target_doctype=RECEIPT_DOCTYPE,
            target_name=receipt.name,
            actor=actor,
            safe_reason="receipt_rejected",
        )
        return {**response, "receipt_evidence": receipt.name}

    config = _preflight(payment, payment_account=payment_account)
    remaining = _remaining_amount(payment)
    amount = flt(verified_amount if verified_amount is not None else remaining, 6)
    if remaining <= 0:
        frappe.throw("This payment is already fully settled.", frappe.ValidationError)
    if amount <= 0:
        frappe.throw("Verified amount must be greater than zero.", frappe.ValidationError)
    if amount > remaining + 0.000001:
        frappe.throw(
            f"Verified amount cannot exceed the remaining amount of {config['currency']} {remaining:g}.",
            frappe.ValidationError,
        )

    response = payments.review_payment_receipt(
        payment_id=payment.name,
        status="Paid",
        remarks=remarks,
        payment_reference=payment_reference,
    )
    receipt.reload()
    receipt.review_status = "Verified"
    receipt.verified_amount = amount
    receipt.payment_account = config["payment_account"]["name"]
    receipt.reviewed_by = actor
    receipt.reviewed_at = now_datetime()
    receipt.verification_source = _text(verification_source) or "Manual"
    receipt.gateway_transaction_id = _text(gateway_transaction_id)
    receipt.accounting_state = "Pending"
    receipt.next_attempt_at = now_datetime()
    receipt.save(ignore_permissions=True)
    security.audit_event(
        event_type="payment.receipt_verified",
        capability="can_review_payments",
        target_doctype=RECEIPT_DOCTYPE,
        target_name=receipt.name,
        actor=actor,
        safe_reason="receipt_verified",
    )
    frappe.db.commit()
    _queue_receipt(receipt.name)
    return {
        **response,
        "receipt_evidence": receipt.name,
        "verified_amount": amount,
        "accounting_queued": True,
        "message": "Receipt verified. ERP accounting has been queued.",
    }


def _ensure_invoice(request, service, invoice_item: str, tax_template: str):
    base = _base_link(request.name)
    if base and base.sales_invoice and frappe.db.exists("Sales Invoice", base.sales_invoice):
        invoice = frappe.get_doc("Sales Invoice", base.sales_invoice)
        if int(invoice.docstatus or 0) != 1:
            frappe.throw("The linked Sales Invoice is not submitted.", frappe.ValidationError)
        accounting_reconciliation.assert_invoice_matches_request(request, invoice)
        return invoice

    from erpnext.controllers.accounts_controller import get_taxes_and_charges

    invoice = frappe.new_doc("Sales Invoice")
    invoice.customer = request.erp_customer
    invoice.company = request.company_snapshot
    invoice.posting_date = nowdate()
    invoice.due_date = nowdate()
    invoice.currency = request.pricing_currency
    line_rate = flt(request.final_price if request.final_price is not None else request.payable_amount, 6)
    invoice.append("items", {"item_code": invoice_item, "qty": 1, "rate": line_rate})
    if tax_template:
        invoice.taxes_and_charges = tax_template
        for tax in get_taxes_and_charges("Sales Taxes and Charges Template", tax_template) or []:
            invoice.append("taxes", tax)
    invoice.flags.ignore_permissions = True
    invoice.insert(ignore_permissions=True)
    expected = flt(request.payable_amount or 0, 6)
    actual = flt(invoice.grand_total or 0, 6)
    if abs(actual - expected) > 0.01:
        frappe.throw(
            f"ERP Sales Invoice total {actual:g} does not match the OMC payable amount {expected:g}. Check the service item/tax mapping.",
            frappe.ValidationError,
        )
    invoice.flags.ignore_permissions = True
    invoice.submit()
    accounting_reconciliation.assert_invoice_matches_request(request, invoice)

    existing_invoice_request = frappe.db.get_value(
        "OMC Accounting Link", {"base_invoice_key": invoice.name}, "service_request"
    )
    existing_request_invoice = frappe.db.get_value(
        "OMC Accounting Link", {"base_request_key": request.name}, "sales_invoice"
    )
    if existing_invoice_request and existing_invoice_request != request.name:
        frappe.throw("Sales Invoice is already linked to another request.", frappe.ValidationError)
    if existing_request_invoice and existing_request_invoice != invoice.name:
        frappe.throw("Service request already has a base Sales Invoice.", frappe.ValidationError)
    link = accounting_reconciliation._upsert_link(request, invoice)
    security.audit_event(
        event_type="accounting.invoice_auto_linked",
        target_doctype=request.doctype,
        target_name=request.name,
        source_version=link.source_version,
        actor=_current_user(),
        safe_reason="verified_payment_automation",
    )
    frappe.db.set_value(
        payments.PAYMENT_DOCTYPE,
        {"service_request": request.name, "status": ["!=", "Cancelled"]},
        "linked_invoice",
        invoice.name,
        update_modified=False,
    )
    return invoice


def _create_payment_entry(receipt, invoice, account):
    from erpnext.accounts.doctype.payment_entry.payment_entry import get_payment_entry

    payment_entry = get_payment_entry(
        "Sales Invoice",
        invoice.name,
        party_amount=flt(receipt.verified_amount or 0, 6),
        bank_account=account["erp_account"],
    )
    payment_entry.paid_to = account["erp_account"]
    if account.get("mode_of_payment"):
        payment_entry.mode_of_payment = account["mode_of_payment"]
    payment_entry.reference_no = (
        _text(receipt.submitted_reference)
        or _text(receipt.gateway_transaction_id)
        or receipt.name
    )
    payment_entry.reference_date = nowdate()
    if payment_entry.meta.get_field("custom_remarks"):
        payment_entry.custom_remarks = f"OMC verified receipt {receipt.name} for {receipt.service_request}."
    payment_entry.flags.ignore_permissions = True
    payment_entry.insert(ignore_permissions=True)
    payment_entry.flags.ignore_permissions = True
    payment_entry.submit()
    return payment_entry


def process_receipt(receipt_name: str) -> dict:
    locked = frappe.db.get_value(RECEIPT_DOCTYPE, receipt_name, "name", for_update=True)
    if not locked:
        return {"status": "missing"}
    receipt = frappe.get_doc(RECEIPT_DOCTYPE, locked)
    if receipt.review_status != "Verified":
        return {"status": "ignored", "reason": "receipt is not verified"}
    if receipt.accounting_state == "Completed":
        return {
            "status": "completed",
            "sales_invoice": receipt.sales_invoice,
            "payment_entry": receipt.payment_entry,
        }
    if receipt.accounting_state == "Failed":
        return {"status": "failed", "reason": receipt.last_error or ""}

    attempts = int(receipt.attempt_count or 0) + 1
    frappe.db.set_value(
        RECEIPT_DOCTYPE,
        receipt.name,
        {
            "accounting_state": "Processing",
            "attempt_count": attempts,
            "last_attempt_at": now_datetime(),
            "next_attempt_at": None,
            "last_error": None,
        },
        update_modified=False,
    )
    savepoint = "omc_verified_payment_accounting"
    frappe.db.savepoint(savepoint)
    try:
        payment = frappe.get_doc(payments.PAYMENT_DOCTYPE, receipt.service_payment)
        config = _preflight(payment, payment_account=receipt.payment_account)
        request = config["request"]
        invoice = _ensure_invoice(
            request,
            config["service"],
            config["invoice_item"],
            config["tax_template"],
        )
        payment_entry = _create_payment_entry(
            receipt,
            invoice,
            config["payment_account"],
        )
        result = accounting_reconciliation.reconcile_request(request.name)
        if result.get("accounting_status") not in {"Partially Settled", "Settled"}:
            frappe.throw(
                "ERP Payment Entry did not reconcile to a paid state.",
                frappe.ValidationError,
            )
        frappe.db.set_value(
            RECEIPT_DOCTYPE,
            receipt.name,
            {
                "accounting_state": "Completed",
                "sales_invoice": invoice.name,
                "payment_entry": payment_entry.name,
                "next_attempt_at": None,
                "last_error": None,
            },
            update_modified=False,
        )
        frappe.db.set_value(
            payments.PAYMENT_DOCTYPE,
            payment.name,
            {
                "linked_invoice": invoice.name,
                "linked_payment_entry": payment_entry.name,
            },
            update_modified=False,
        )
        security.audit_event(
            event_type="payment.erp_accounting_completed",
            target_doctype=RECEIPT_DOCTYPE,
            target_name=receipt.name,
            actor=_current_user(),
            safe_reason=_text(result.get("accounting_status")),
        )
        return {
            "status": "completed",
            "accounting_status": result.get("accounting_status"),
            "sales_invoice": invoice.name,
            "payment_entry": payment_entry.name,
            "remaining_amount": result.get("remaining_amount"),
        }
    except Exception:
        frappe.db.rollback(save_point=savepoint)
        state = "Failed" if attempts >= MAX_ATTEMPTS else "Retry"
        frappe.db.set_value(
            RECEIPT_DOCTYPE,
            receipt.name,
            {
                "accounting_state": state,
                "next_attempt_at": (
                    None
                    if state == "Failed"
                    else add_to_date(now_datetime(), minutes=min(2 ** attempts, 60))
                ),
                "last_error": "ERP accounting automation could not be completed.",
            },
            update_modified=False,
        )
        frappe.log_error(
            frappe.get_traceback(),
            f"OMC Verified Payment Accounting Failed: {receipt.name}",
        )
        return {"status": state.lower(), "reason": "ERP accounting automation could not be completed."}


def process_pending_receipts(limit: int = 25):
    names = frappe.get_all(
        RECEIPT_DOCTYPE,
        filters={
            "review_status": "Verified",
            "accounting_state": ["in", ["Pending", "Retry"]],
            "next_attempt_at": ["<=", now_datetime()],
        },
        pluck="name",
        order_by="next_attempt_at asc, creation asc",
        limit_page_length=min(max(int(limit or 25), 1), 100),
    )
    return [process_receipt(name) for name in names]
