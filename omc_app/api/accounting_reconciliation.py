from __future__ import annotations

import hashlib

import frappe
from frappe.utils import flt, now_datetime

from omc_app.api import capabilities, request_lifecycle, security


LINKABLE_REQUEST_STATES = {
    "Pending Payment",
    "Payment Not Required",
    "Ready for Activation",
    "Activating",
    "Activated",
    "Activation Failed",
    "Financial Hold",
}


def _text(value) -> str:
    return str(value or "").strip()


def _source_key(*values) -> str:
    return hashlib.sha256("|".join(_text(value) for value in values).encode()).hexdigest()


def _invoice_basis(invoice) -> float:
    return max(flt(invoice.grand_total or 0, 6), 0)


def _request_basis(request) -> float:
    return max(flt(request.payable_amount if request.payable_amount is not None else request.final_price, 6), 0)


def settlement_state(*, required, invoice_basis, allocated, invalid_reason="", reversed_exists=False):
    """Classify settlement from ERP reference allocations, never header paid amounts."""
    required = max(flt(required, 6), 0)
    invoice_basis = max(flt(invoice_basis, 6), 0)
    allocated = max(flt(allocated, 6), 0)
    capped = min(allocated, invoice_basis, required) if required else 0
    if invalid_reason:
        state = "Review Required"
    elif not invoice_basis:
        state = "Unmatched"
    elif required and capped + 0.000001 >= required:
        state = "Settled"
    elif reversed_exists:
        state = "Reversed"
    elif allocated > 0:
        state = "Partially Settled"
    else:
        state = "Unmatched"
    return state, capped


def assert_invoice_matches_request(request, invoice) -> None:
    if int(getattr(invoice, "docstatus", 0) or 0) != 1:
        frappe.throw("Only a submitted Sales Invoice can be linked.", frappe.ValidationError)
    if int(getattr(invoice, "is_return", 0) or 0):
        frappe.throw("A return Sales Invoice cannot be used as base settlement evidence.", frappe.ValidationError)
    if _text(request.request_state) not in LINKABLE_REQUEST_STATES or _text(request.status) == "Completed":
        frappe.throw("The service request is not in a linkable accounting state.", frappe.ValidationError)

    expected_customer = _text(request.erp_customer)
    expected_company = _text(request.get("company_snapshot"))
    expected_currency = _text(request.pricing_currency)
    if not expected_customer:
        frappe.throw("The service request has no authoritative ERP Customer snapshot.", frappe.ValidationError)
    if not expected_company:
        frappe.throw(
            "The service request has no authoritative Company snapshot and requires explicit finance reconciliation.",
            frappe.ValidationError,
        )
    if not expected_currency:
        frappe.throw("The service request has no authoritative pricing currency.", frappe.ValidationError)
    if _text(invoice.customer) != expected_customer:
        frappe.throw("Sales Invoice customer does not match the service request.", frappe.ValidationError)
    if _text(invoice.company) != expected_company:
        frappe.throw("Sales Invoice company does not match the service request snapshot.", frappe.ValidationError)
    if _text(invoice.currency) != expected_currency:
        frappe.throw("Sales Invoice currency does not match the service request quote.", frappe.ValidationError)
    if _invoice_basis(invoice) <= 0:
        frappe.throw("Sales Invoice must have a positive total.", frappe.ValidationError)


def _invoice_reconciliation_error(request, invoice) -> str:
    if int(getattr(invoice, "docstatus", 0) or 0) != 1 or int(getattr(invoice, "is_return", 0) or 0):
        return "Linked Sales Invoice is cancelled or reversed."
    if not _text(request.get("company_snapshot")):
        return "Service request has no authoritative Company snapshot."
    if _text(invoice.customer) != _text(request.erp_customer):
        return "Linked Sales Invoice customer no longer matches the request."
    if _text(invoice.company) != _text(request.get("company_snapshot")):
        return "Linked Sales Invoice company no longer matches the request snapshot."
    if _text(invoice.currency) != _text(request.pricing_currency):
        return "Linked Sales Invoice currency no longer matches the request quote."
    if _invoice_basis(invoice) <= 0:
        return "Linked Sales Invoice no longer has a positive total."
    if frappe.db.exists(
        "Sales Invoice",
        {"return_against": invoice.name, "docstatus": 1, "is_return": 1},
    ):
        return "A submitted Sales Invoice return requires finance review."
    return ""


def _payment_allocation_error(request, invoice, payment, reference) -> str:
    if int(getattr(payment, "docstatus", 0) or 0) != 1:
        return "Payment Entry is not submitted."
    if _text(getattr(payment, "payment_type", None)) != "Receive":
        return "A refund or reversal allocation requires finance review."
    if _text(getattr(payment, "party_type", None)) != "Customer":
        return "Payment Entry party type does not match the request customer."
    if _text(getattr(payment, "party", None)) != _text(request.erp_customer):
        return "Payment Entry party does not match the request customer."
    if _text(getattr(payment, "company", None)) != _text(request.get("company_snapshot")):
        return "Payment Entry company does not match the request company snapshot."
    if _text(getattr(payment, "company", None)) != _text(invoice.company):
        return "Payment Entry company does not match the linked invoice."
    payment_currency = _text(getattr(payment, "paid_from_account_currency", None))
    if payment_currency and payment_currency != _text(invoice.currency):
        return "Payment Entry currency does not match the linked invoice."
    if flt(getattr(reference, "allocated_amount", 0) or 0, 6) <= 0:
        return "A non-positive allocation requires finance review."
    return ""


def _upsert_link(request, invoice, *, payment_entry=None, reference=None, state="Unmatched"):
    reference_name = _text(getattr(reference, "name", None))
    source_key = _source_key(
        "payment" if payment_entry else "invoice",
        request.name,
        invoice.name,
        getattr(payment_entry, "name", ""),
        reference_name,
    )
    name = frappe.db.get_value("OMC Accounting Link", {"source_key": source_key}, "name")
    doc = frappe.get_doc("OMC Accounting Link", name) if name else frappe.new_doc("OMC Accounting Link")
    doc.source_key = source_key
    doc.service_request = request.name
    doc.sales_invoice = invoice.name
    doc.payment_entry = getattr(payment_entry, "name", None)
    doc.payment_reference_row = reference_name
    doc.erp_customer = invoice.customer
    doc.company = invoice.company
    doc.invoice_currency = invoice.currency
    doc.payment_currency = (
        _text(getattr(payment_entry, "paid_to_account_currency", None))
        or _text(getattr(payment_entry, "paid_from_account_currency", None))
        if payment_entry else ""
    )
    if doc.is_new():
        doc.linked_by = frappe.session.user
        doc.linked_at = now_datetime()
    allocated = max(flt(getattr(reference, "allocated_amount", 0) or 0, 6), 0)
    conversion_rate = flt(getattr(invoice, "conversion_rate", 1) or 1, 9)
    doc.allocated_amount = min(allocated, _invoice_basis(invoice))
    doc.base_allocated_amount = flt(doc.allocated_amount * conversion_rate, 6)
    doc.exchange_rate = conversion_rate
    doc.invoice_docstatus = invoice.docstatus
    doc.payment_docstatus = getattr(payment_entry, "docstatus", 0) if payment_entry else 0
    doc.invoice_outstanding_amount = flt(invoice.outstanding_amount or 0, 6)
    doc.accounting_status = state
    doc.source_version = _source_key(
        invoice.name, invoice.modified, getattr(payment_entry, "name", ""),
        getattr(payment_entry, "modified", ""), reference_name, allocated,
    )
    doc.reconciled_at = now_datetime()
    doc.reconciliation_error = ""
    if doc.is_new():
        doc.insert(ignore_permissions=True)
    else:
        doc.save(ignore_permissions=True)
    return doc


@frappe.whitelist(methods=["POST"])
def link_sales_invoice(service_request=None, sales_invoice=None):
    capabilities.require("can_reconcile_settlement")
    security.enforce_rate_limit("staff_mutation")
    request_name = _text(service_request)
    invoice_name = _text(sales_invoice)
    if not request_name or not invoice_name:
        frappe.throw("service_request and sales_invoice are required.", frappe.ValidationError)
    locked = frappe.db.get_value("OMC Service Request", request_name, "name", for_update=True)
    if not locked or not frappe.db.exists("Sales Invoice", invoice_name):
        frappe.throw("Accounting source is not available.", frappe.DoesNotExistError)
    request = frappe.get_doc("OMC Service Request", locked)
    invoice = frappe.get_doc("Sales Invoice", invoice_name)
    assert_invoice_matches_request(request, invoice)

    existing_invoice_request = frappe.db.get_value(
        "OMC Accounting Link", {"base_invoice_key": invoice.name}, "service_request"
    )
    if existing_invoice_request and existing_invoice_request != request.name:
        frappe.throw("Sales Invoice is already linked to another request.", frappe.ValidationError)
    existing_request_invoice = frappe.db.get_value(
        "OMC Accounting Link", {"base_request_key": request.name}, "sales_invoice"
    )
    if existing_request_invoice and existing_request_invoice != invoice.name:
        frappe.throw("Service request already has a base Sales Invoice.", frappe.ValidationError)

    link = _upsert_link(request, invoice)
    security.audit_event(
        event_type="accounting.invoice_linked",
        capability="can_reconcile_settlement",
        target_doctype=request.doctype,
        target_name=request.name,
        source_version=link.source_version,
        actor=frappe.session.user,
    )
    result = reconcile_request(request.name)
    return {"success": True, "accounting_link": link.name, **result}


def _submitted_allocations(invoice_names: set[str]):
    if not invoice_names:
        return []
    names = frappe.get_all(
        "Payment Entry Reference",
        filters={"reference_doctype": "Sales Invoice", "reference_name": ["in", sorted(invoice_names)]},
        pluck="parent",
        limit_page_length=1000,
    )
    allocations = []
    for name in sorted(set(names)):
        if frappe.db.get_value("Payment Entry", name, "docstatus") != 1:
            continue
        payment = frappe.get_doc("Payment Entry", name)
        for row in payment.references:
            if row.reference_doctype == "Sales Invoice" and row.reference_name in invoice_names:
                allocations.append((payment, row))
    return allocations


def _project_receipt_compatibility(request_name: str, state: str, payment_entry: str = "") -> None:
    rows = frappe.get_all(
        "OMC Service Payment",
        filters={"service_request": request_name, "status": ["!=", "Cancelled"]},
        pluck="name",
        order_by="creation desc",
        limit_page_length=10,
    )
    for name in rows:
        values = {"accounting_status": state, "linked_payment_entry": payment_entry or None}
        if state == "Settled":
            values.update({"status": "Paid", "paid_on": now_datetime(), "settled_at": now_datetime()})
        elif frappe.db.get_value("OMC Service Payment", name, "status") == "Paid":
            values.update({"status": "Under Review", "paid_on": None, "settled_at": None})
        frappe.db.set_value("OMC Service Payment", name, values, update_modified=False)


def _set_hold_reason(request, reason: str) -> None:
    value = _text(reason) or "Accounting settlement requires finance review."
    frappe.db.set_value(request.doctype, request.name, "financial_hold_reason", value, update_modified=False)
    request.financial_hold_reason = value


def _clear_hold_reason(request) -> None:
    frappe.db.set_value(request.doctype, request.name, "financial_hold_reason", None, update_modified=False)
    request.financial_hold_reason = None


def _apply_accounting_lifecycle(request, accounting_status: str, reason: str = "") -> None:
    current = _text(request.request_state) or "Draft"
    if current in {"Cancelled", "Expired"} or _text(request.status) == "Completed":
        return

    if accounting_status == "Settled":
        target = ""
        if current == "Financial Hold":
            target = "Activated" if (request.activated_at or request.erp_service or request.erp_task) else "Ready for Activation"
        elif current in {"Pending Payment", "Payment Not Required", "Activation Failed"}:
            target = "Ready for Activation"
        if target:
            request_lifecycle.transition_request_state(
                request.name,
                target,
                reason="ERP accounting settlement verified.",
                actor=frappe.session.user,
                capability="can_reconcile_settlement",
                idempotency_key=f"accounting:settled:{request.name}",
            )
            request.request_state = target
            _clear_hold_reason(request)
        return

    if accounting_status not in {"Reversed", "Review Required"}:
        return

    hold_reason = _text(reason) or "Accounting settlement was reversed or requires finance review."
    if current == "Financial Hold":
        _set_hold_reason(request, hold_reason)
        return
    if current in {
        "Pending Payment", "Payment Not Required", "Ready for Activation", "Activating", "Activated", "Activation Failed"
    }:
        request_lifecycle.transition_request_state(
            request.name,
            "Financial Hold",
            reason=hold_reason,
            actor=frappe.session.user,
            capability="can_reconcile_settlement",
            idempotency_key=f"accounting:hold:{request.name}",
        )
        request.request_state = "Financial Hold"
        _set_hold_reason(request, hold_reason)


def reconcile_request(request_name: str) -> dict:
    locked = frappe.db.get_value("OMC Service Request", request_name, "name", for_update=True)
    if not locked:
        frappe.throw("Service request is not available.", frappe.DoesNotExistError)
    request = frappe.get_doc("OMC Service Request", locked)
    base_links = frappe.get_all(
        "OMC Accounting Link",
        filters={"service_request": request.name, "payment_entry": ["is", "not set"]},
        fields=["name", "sales_invoice"],
        order_by="creation asc, name asc",
        limit_page_length=100,
    )
    invoices = []
    invalid_reason = ""
    for link in base_links:
        if not frappe.db.exists("Sales Invoice", link.sales_invoice):
            invalid_reason = "Linked Sales Invoice is missing."
            continue
        invoice = frappe.get_doc("Sales Invoice", link.sales_invoice)
        invoice_error = _invoice_reconciliation_error(request, invoice)
        if invoice_error:
            invalid_reason = invoice_error
        invoices.append(invoice)

    allocated = 0.0
    latest_payment = ""
    invoice_names = {
        invoice.name for invoice in invoices
        if invoice.docstatus == 1 and not int(getattr(invoice, "is_return", 0) or 0)
    }
    for payment, reference in _submitted_allocations(invoice_names):
        invoice = next(item for item in invoices if item.name == reference.reference_name)
        allocation_error = _payment_allocation_error(request, invoice, payment, reference)
        if allocation_error:
            invalid_reason = allocation_error
            continue
        allocation = _upsert_link(request, invoice, payment_entry=payment, reference=reference)
        allocated += min(flt(allocation.allocated_amount or 0, 6), _invoice_basis(invoice))
        latest_payment = payment.name

    required = _request_basis(request)
    invoice_basis = flt(sum(_invoice_basis(item) for item in invoices), 6)
    reversed_exists = bool(
        frappe.db.exists(
            "OMC Accounting Link", {"service_request": request.name, "accounting_status": "Reversed"}
        )
    )
    state, capped = settlement_state(
        required=required,
        invoice_basis=invoice_basis,
        allocated=allocated,
        invalid_reason=invalid_reason,
        reversed_exists=reversed_exists,
    )

    for link in base_links:
        frappe.db.set_value(
            "OMC Accounting Link", link.name,
            {"accounting_status": state, "reconciled_at": now_datetime(), "reconciliation_error": invalid_reason},
            update_modified=False,
        )
    _project_receipt_compatibility(request.name, state, latest_payment)
    _apply_accounting_lifecycle(request, state, invalid_reason)
    if state == "Settled":
        from omc_app.api.bridge_outbox import enqueue_if_eligible

        enqueue_if_eligible(request.name)
    return {
        "request": request.name,
        "request_state": request.request_state,
        "accounting_status": state,
        "allocated_amount": capped,
        "required_amount": required,
        "remaining_amount": max(flt(required - capped, 6), 0),
        "linked_invoices": sorted(invoice_names),
        "payment_entry": latest_payment,
        "reconciliation_error": invalid_reason,
    }


def payment_entry_submitted(doc, method=None):
    requests = set()
    for row in doc.references or []:
        if row.reference_doctype != "Sales Invoice" or not row.reference_name:
            continue
        requests.update(
            frappe.get_all(
                "OMC Accounting Link",
                filters={"sales_invoice": row.reference_name},
                pluck="service_request",
                limit_page_length=100,
            )
        )
    for request_name in sorted(requests):
        reconcile_request(request_name)
    from omc_app.api.commission_projection import project_payment_entry

    project_payment_entry(doc)


def payment_entry_cancelled(doc, method=None):
    links = frappe.get_all(
        "OMC Accounting Link", filters={"payment_entry": doc.name},
        fields=["name", "service_request"], limit_page_length=1000,
    )
    requests = {row.service_request for row in links}
    for row in links:
        frappe.db.set_value(
            "OMC Accounting Link", row.name,
            {"accounting_status": "Reversed", "payment_docstatus": 2, "reconciled_at": now_datetime()},
            update_modified=False,
        )
    from omc_app.api.commission_projection import reverse_payment_entry

    reverse_payment_entry(doc, reason="Payment Entry cancelled")
    for request_name in sorted(requests):
        reconcile_request(request_name)


def sales_invoice_cancelled(doc, method=None):
    requests = set(
        frappe.get_all(
            "OMC Accounting Link", filters={"sales_invoice": doc.name},
            pluck="service_request", limit_page_length=100,
        )
    )
    for request_name in sorted(requests):
        reconcile_request(request_name)


def sales_invoice_submitted(doc, method=None):
    if not int(getattr(doc, "is_return", 0) or 0) or not getattr(doc, "return_against", None):
        return
    requests = set(
        frappe.get_all(
            "OMC Accounting Link", filters={"sales_invoice": doc.return_against},
            pluck="service_request", limit_page_length=100,
        )
    )
    for request_name in sorted(requests):
        reconcile_request(request_name)


@frappe.whitelist(methods=["POST"])
def approve_post_paid(service_request=None):
    capabilities.require("can_approve_post_paid")
    security.enforce_rate_limit("staff_mutation")
    name = _text(service_request)
    locked = frappe.db.get_value("OMC Service Request", name, "name", for_update=True)
    if not locked:
        frappe.throw("Service request is not available.", frappe.DoesNotExistError)
    request = frappe.get_doc("OMC Service Request", locked)
    if request.payment_policy_snapshot != "Post-paid Approval":
        frappe.throw("Request is not eligible for post-paid approval.", frappe.ValidationError)
    if request.request_state != "Pending Payment":
        frappe.throw("Request is not awaiting finance approval.", frappe.ValidationError)

    frappe.db.set_value(
        request.doctype,
        request.name,
        {"post_paid_approved_by": frappe.session.user, "post_paid_approved_at": now_datetime()},
        update_modified=False,
    )
    result = request_lifecycle.transition_request_state(
        request.name,
        "Ready for Activation",
        reason="Post-paid service approved by finance.",
        actor=frappe.session.user,
        capability="can_approve_post_paid",
        idempotency_key=f"postpaid:{request.name}",
    )
    security.audit_event(
        event_type="accounting.post_paid_approved",
        capability="can_approve_post_paid",
        target_doctype=request.doctype,
        target_name=request.name,
        old_state=result.old_state,
        new_state=result.new_state,
        actor=frappe.session.user,
    )
    from omc_app.api.bridge_outbox import enqueue_if_eligible

    operation = enqueue_if_eligible(request.name)
    return {"success": True, "request_state": result.new_state, "operation": operation}
