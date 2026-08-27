from __future__ import annotations

import hashlib

import frappe
from frappe.utils import flt, now_datetime

from omc_app.api import capabilities, reconciliation_queues, request_lifecycle, security


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
    return max(
        flt(
            request.payable_amount
            if request.payable_amount is not None
            else request.final_price,
            6,
        ),
        0,
    )


def settlement_state(
    *,
    required,
    invoice_basis,
    allocated,
    invalid_reason="",
    technical_reason="",
    reversed_exists=False,
):
    """Classify ERP settlement without conflating review and quarantine."""
    required = max(flt(required, 6), 0)
    invoice_basis = max(flt(invoice_basis, 6), 0)
    allocated = max(flt(allocated, 6), 0)
    capped = min(allocated, invoice_basis, required) if required else 0
    if technical_reason:
        state = "Quarantined"
    elif invalid_reason:
        state = "Review Required"
    elif reversed_exists:
        state = "Reversed"
    elif not invoice_basis:
        state = "Unmatched"
    elif required and capped + 0.000001 >= required:
        state = "Settled"
    elif allocated > 0:
        state = "Partially Settled"
    else:
        state = "Unmatched"
    return state, capped


def assert_invoice_matches_request(request, invoice) -> None:
    if int(getattr(invoice, "docstatus", 0) or 0) != 1:
        frappe.throw("Only a submitted Sales Invoice can be linked.", frappe.ValidationError)
    if int(getattr(invoice, "is_return", 0) or 0):
        frappe.throw(
            "A return Sales Invoice cannot be used as base settlement evidence.",
            frappe.ValidationError,
        )
    if (
        _text(request.request_state) not in LINKABLE_REQUEST_STATES
        or _text(request.status) == "Completed"
    ):
        frappe.throw(
            "The service request is not in a linkable accounting state.",
            frappe.ValidationError,
        )

    expected_customer = _text(request.erp_customer)
    expected_company = _text(request.get("company_snapshot"))
    expected_currency = _text(request.pricing_currency)
    if not expected_customer:
        frappe.throw(
            "The service request has no authoritative ERP Customer snapshot.",
            frappe.ValidationError,
        )
    if not expected_company:
        frappe.throw(
            "The service request has no authoritative Company snapshot and requires explicit finance reconciliation.",
            frappe.ValidationError,
        )
    if not expected_currency:
        frappe.throw(
            "The service request has no authoritative pricing currency.",
            frappe.ValidationError,
        )
    if _text(invoice.customer) != expected_customer:
        frappe.throw(
            "Sales Invoice customer does not match the service request.",
            frappe.ValidationError,
        )
    if _text(invoice.company) != expected_company:
        frappe.throw(
            "Sales Invoice company does not match the service request snapshot.",
            frappe.ValidationError,
        )
    if _text(invoice.currency) != expected_currency:
        frappe.throw(
            "Sales Invoice currency does not match the service request quote.",
            frappe.ValidationError,
        )
    if _invoice_basis(invoice) <= 0:
        frappe.throw("Sales Invoice must have a positive total.", frappe.ValidationError)


def _issue(kind: str, code: str, message: str, *, source_doctype="", source_name="", source_version="", evidence=None):
    return {
        "kind": kind,
        "code": code,
        "message": message,
        "source_doctype": source_doctype,
        "source_name": source_name,
        "source_version": source_version,
        "evidence": evidence or {},
    }


def _invoice_reconciliation_issue(request, invoice):
    version = _source_key(invoice.name, invoice.modified)
    evidence = {"sales_invoice": invoice.name}
    if int(getattr(invoice, "docstatus", 0) or 0) != 1 or int(
        getattr(invoice, "is_return", 0) or 0
    ):
        return _issue(
            "reversed",
            "invoice_reversed",
            "Linked Sales Invoice is cancelled or reversed.",
            source_doctype="Sales Invoice",
            source_name=invoice.name,
            source_version=version,
            evidence=evidence,
        )
    if not _text(request.get("company_snapshot")):
        return _issue(
            "technical",
            "missing_company_snapshot",
            "Service request has no authoritative Company snapshot.",
            source_doctype=request.doctype,
            source_name=request.name,
            source_version=_text(request.modified),
        )
    if _text(invoice.customer) != _text(request.erp_customer):
        return _issue(
            "human",
            "invoice_customer_mismatch",
            "Linked Sales Invoice customer no longer matches the request.",
            source_doctype="Sales Invoice",
            source_name=invoice.name,
            source_version=version,
            evidence=evidence,
        )
    if _text(invoice.company) != _text(request.get("company_snapshot")):
        return _issue(
            "human",
            "invoice_company_mismatch",
            "Linked Sales Invoice company no longer matches the request snapshot.",
            source_doctype="Sales Invoice",
            source_name=invoice.name,
            source_version=version,
            evidence=evidence,
        )
    if _text(invoice.currency) != _text(request.pricing_currency):
        return _issue(
            "human",
            "invoice_currency_mismatch",
            "Linked Sales Invoice currency no longer matches the request quote.",
            source_doctype="Sales Invoice",
            source_name=invoice.name,
            source_version=version,
            evidence={**evidence, "invoice_currency": _text(invoice.currency)},
        )
    if _invoice_basis(invoice) <= 0:
        return _issue(
            "human",
            "invoice_non_positive_total",
            "Linked Sales Invoice no longer has a positive total.",
            source_doctype="Sales Invoice",
            source_name=invoice.name,
            source_version=version,
            evidence=evidence,
        )
    if frappe.db.exists(
        "Sales Invoice",
        {"return_against": invoice.name, "docstatus": 1, "is_return": 1},
    ):
        return _issue(
            "human",
            "invoice_return_exists",
            "A submitted Sales Invoice return requires finance review.",
            source_doctype="Sales Invoice",
            source_name=invoice.name,
            source_version=version,
            evidence=evidence,
        )
    return None


def _payment_allocation_issue(request, invoice, payment, reference):
    version = _source_key(payment.name, payment.modified, reference.name, reference.allocated_amount)
    evidence = {
        "payment_entry": payment.name,
        "sales_invoice": invoice.name,
        "reference_row": reference.name,
    }
    if int(getattr(payment, "docstatus", 0) or 0) != 1:
        return _issue(
            "technical",
            "payment_not_submitted",
            "Payment Entry referenced by reconciliation is not submitted.",
            source_doctype="Payment Entry",
            source_name=payment.name,
            source_version=version,
            evidence=evidence,
        )
    if _text(getattr(payment, "payment_type", None)) != "Receive":
        return _issue(
            "human",
            "payment_not_receive",
            "A refund or reversal allocation requires finance review.",
            source_doctype="Payment Entry",
            source_name=payment.name,
            source_version=version,
            evidence=evidence,
        )
    if _text(getattr(payment, "party_type", None)) != "Customer":
        return _issue(
            "human",
            "payment_party_type_mismatch",
            "Payment Entry party type does not match the request customer.",
            source_doctype="Payment Entry",
            source_name=payment.name,
            source_version=version,
            evidence=evidence,
        )
    if _text(getattr(payment, "party", None)) != _text(request.erp_customer):
        return _issue(
            "human",
            "payment_party_mismatch",
            "Payment Entry party does not match the request customer.",
            source_doctype="Payment Entry",
            source_name=payment.name,
            source_version=version,
            evidence=evidence,
        )
    if _text(getattr(payment, "company", None)) != _text(request.get("company_snapshot")):
        return _issue(
            "human",
            "payment_company_mismatch",
            "Payment Entry company does not match the request company snapshot.",
            source_doctype="Payment Entry",
            source_name=payment.name,
            source_version=version,
            evidence=evidence,
        )
    if _text(getattr(payment, "company", None)) != _text(invoice.company):
        return _issue(
            "human",
            "payment_invoice_company_mismatch",
            "Payment Entry company does not match the linked invoice.",
            source_doctype="Payment Entry",
            source_name=payment.name,
            source_version=version,
            evidence=evidence,
        )
    payment_currency = _text(getattr(payment, "paid_from_account_currency", None))
    if payment_currency and payment_currency != _text(invoice.currency):
        return _issue(
            "human",
            "payment_currency_mismatch",
            "Payment Entry currency does not match the linked invoice.",
            source_doctype="Payment Entry",
            source_name=payment.name,
            source_version=version,
            evidence={**evidence, "payment_currency": payment_currency},
        )
    if flt(getattr(reference, "allocated_amount", 0) or 0, 6) <= 0:
        return _issue(
            "human",
            "payment_non_positive_allocation",
            "A non-positive allocation requires finance review.",
            source_doctype="Payment Entry",
            source_name=payment.name,
            source_version=version,
            evidence=evidence,
        )
    return None


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
    doc = (
        frappe.get_doc("OMC Accounting Link", name)
        if name
        else frappe.new_doc("OMC Accounting Link")
    )
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
        if payment_entry
        else ""
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
        invoice.name,
        invoice.modified,
        getattr(payment_entry, "name", ""),
        getattr(payment_entry, "modified", ""),
        reference_name,
        allocated,
    )
    doc.reconciled_at = now_datetime()
    doc.reconciliation_error = ""
    if doc.is_new():
        doc.insert(ignore_permissions=True)
    else:
        doc.save(ignore_permissions=True)
    return doc


def _project_link_state(request_name: str, state: str, reason: str = "") -> None:
    """Keep base and allocation evidence on one authoritative request state."""
    names = frappe.get_all(
        "OMC Accounting Link",
        filters={"service_request": request_name},
        pluck="name",
        limit_page_length=1000,
    )
    reconciled_at = now_datetime()
    for name in names:
        frappe.db.set_value(
            "OMC Accounting Link",
            name,
            {
                "accounting_status": state,
                "reconciled_at": reconciled_at,
                "reconciliation_error": reason,
            },
            update_modified=False,
        )


@frappe.whitelist(methods=["POST"])
def link_sales_invoice(service_request=None, sales_invoice=None):
    capabilities.require("can_reconcile_settlement")
    security.enforce_rate_limit("staff_mutation")
    request_name = _text(service_request)
    invoice_name = _text(sales_invoice)
    if not request_name or not invoice_name:
        frappe.throw(
            "service_request and sales_invoice are required.",
            frappe.ValidationError,
        )
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
        frappe.throw(
            "Sales Invoice is already linked to another request.",
            frappe.ValidationError,
        )
    existing_request_invoice = frappe.db.get_value(
        "OMC Accounting Link", {"base_request_key": request.name}, "sales_invoice"
    )
    if existing_request_invoice and existing_request_invoice != invoice.name:
        frappe.throw(
            "Service request already has a base Sales Invoice.",
            frappe.ValidationError,
        )

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
        filters={
            "reference_doctype": "Sales Invoice",
            "reference_name": ["in", sorted(invoice_names)],
        },
        pluck="parent",
        limit_page_length=1000,
    )
    allocations = []
    for name in sorted(set(names)):
        if frappe.db.get_value("Payment Entry", name, "docstatus") != 1:
            continue
        payment = frappe.get_doc("Payment Entry", name)
        for row in payment.references:
            if (
                row.reference_doctype == "Sales Invoice"
                and row.reference_name in invoice_names
            ):
                allocations.append((payment, row))
    return allocations


def _project_receipt_compatibility(
    request_name: str,
    state: str,
    payment_entry: str = "",
) -> None:
    rows = frappe.get_all(
        "OMC Service Payment",
        filters={"service_request": request_name, "status": ["!=", "Cancelled"]},
        pluck="name",
        order_by="creation desc",
        limit_page_length=10,
    )
    for name in rows:
        values = {
            "accounting_status": state,
            "linked_payment_entry": payment_entry or None,
        }
        if state == "Settled":
            values.update(
                {
                    "status": "Paid",
                    "paid_on": now_datetime(),
                    "settled_at": now_datetime(),
                }
            )
        elif frappe.db.get_value("OMC Service Payment", name, "status") == "Paid":
            values.update(
                {"status": "Under Review", "paid_on": None, "settled_at": None}
            )
        frappe.db.set_value(
            "OMC Service Payment", name, values, update_modified=False
        )


def _set_hold_reason(request, reason: str) -> None:
    value = _text(reason) or "Accounting settlement requires finance review."
    frappe.db.set_value(
        request.doctype,
        request.name,
        "financial_hold_reason",
        value,
        update_modified=False,
    )
    request.financial_hold_reason = value


def _clear_hold_reason(request) -> None:
    frappe.db.set_value(
        request.doctype,
        request.name,
        "financial_hold_reason",
        None,
        update_modified=False,
    )
    request.financial_hold_reason = None


def _apply_accounting_lifecycle(
    request,
    accounting_status: str,
    reason: str = "",
) -> None:
    current = _text(request.request_state) or "Draft"
    if current in {"Cancelled", "Expired"} or _text(request.status) == "Completed":
        return

    if accounting_status == "Settled":
        target = ""
        if current == "Financial Hold":
            target = (
                "Activated"
                if (request.activated_at or request.erp_service or request.erp_task)
                else "Ready for Activation"
            )
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

    if accounting_status not in {"Reversed", "Review Required", "Quarantined"}:
        return

    if accounting_status == "Quarantined":
        default_reason = "Accounting reconciliation is technically quarantined pending recovery."
    elif accounting_status == "Review Required":
        default_reason = "Accounting settlement requires finance review."
    else:
        default_reason = "Accounting settlement was reversed."
    hold_reason = _text(reason) or default_reason
    if current == "Financial Hold":
        _set_hold_reason(request, hold_reason)
        return
    if current in {
        "Pending Payment",
        "Payment Not Required",
        "Ready for Activation",
        "Activating",
        "Activated",
        "Activation Failed",
    }:
        request_lifecycle.transition_request_state(
            request.name,
            "Financial Hold",
            reason=hold_reason,
            actor=frappe.session.user,
            capability="can_reconcile_settlement",
            idempotency_key=f"accounting:hold:{request.name}:{accounting_status}",
        )
        request.request_state = "Financial Hold"
        _set_hold_reason(request, hold_reason)


def _persist_reconciliation_issues(request, issues: list[dict]) -> tuple[list[str], list[str]]:
    reviews: list[str] = []
    quarantines: list[str] = []
    for issue in issues:
        evidence = {
            "request": request.name,
            "source_doctype": issue.get("source_doctype", ""),
            "source_name": issue.get("source_name", ""),
            **dict(issue.get("evidence") or {}),
        }
        if issue["kind"] == "human":
            review = reconciliation_queues.open_human_review(
                domain="Accounting",
                source_doctype=request.doctype,
                source_name=request.name,
                reason_code=issue["code"],
                source_version=issue.get("source_version", ""),
                safe_evidence=evidence,
            )
            reviews.append(review.name)
        elif issue["kind"] == "technical":
            quarantine = reconciliation_queues.open_technical_quarantine(
                domain="Accounting",
                source_doctype=request.doctype,
                source_name=request.name,
                failure_code=issue["code"],
                source_version=issue.get("source_version", ""),
                safe_evidence=evidence,
            )
            quarantines.append(quarantine.name)
    return reviews, quarantines


def reconcile_request(request_name: str) -> dict:
    locked = frappe.db.get_value(
        "OMC Service Request", request_name, "name", for_update=True
    )
    if not locked:
        frappe.throw("Service request is not available.", frappe.DoesNotExistError)
    request = frappe.get_doc("OMC Service Request", locked)
    base_links = frappe.get_all(
        "OMC Accounting Link",
        filters={
            "service_request": request.name,
            "payment_entry": ["is", "not set"],
        },
        fields=["name", "sales_invoice", "source_version"],
        order_by="creation asc, name asc",
        limit_page_length=100,
    )

    issues: list[dict] = []
    if len(base_links) > 1:
        issues.append(
            _issue(
                "technical",
                "multiple_base_invoice_links",
                "Multiple base Sales Invoice links exist for one service request.",
                source_doctype=request.doctype,
                source_name=request.name,
                source_version=_source_key(*(row.source_version for row in base_links)),
                evidence={"base_link_count": len(base_links)},
            )
        )

    invoices = []
    for link in base_links:
        if not frappe.db.exists("Sales Invoice", link.sales_invoice):
            issues.append(
                _issue(
                    "technical",
                    "linked_invoice_missing",
                    "Linked Sales Invoice is missing.",
                    source_doctype="Sales Invoice",
                    source_name=link.sales_invoice,
                    source_version=_text(link.source_version),
                    evidence={"sales_invoice": link.sales_invoice},
                )
            )
            continue
        invoice = frappe.get_doc("Sales Invoice", link.sales_invoice)
        issue = _invoice_reconciliation_issue(request, invoice)
        if issue:
            issues.append(issue)
        _upsert_link(request, invoice)
        invoices.append(invoice)

    allocated = 0.0
    latest_payment = ""
    invoice_names = {
        invoice.name
        for invoice in invoices
        if invoice.docstatus == 1 and not int(getattr(invoice, "is_return", 0) or 0)
    }
    for payment, reference in _submitted_allocations(invoice_names):
        invoice = next(
            item for item in invoices if item.name == reference.reference_name
        )
        issue = _payment_allocation_issue(request, invoice, payment, reference)
        if issue:
            issues.append(issue)
            continue
        allocation = _upsert_link(
            request,
            invoice,
            payment_entry=payment,
            reference=reference,
        )
        allocated += min(
            flt(allocation.allocated_amount or 0, 6),
            _invoice_basis(invoice),
        )
        latest_payment = payment.name

    technical_issues = [issue for issue in issues if issue["kind"] == "technical"]
    human_issues = [issue for issue in issues if issue["kind"] == "human"]
    reversal_issues = [issue for issue in issues if issue["kind"] == "reversed"]
    technical_reason = technical_issues[0]["message"] if technical_issues else ""
    human_reason = human_issues[0]["message"] if human_issues else ""

    required = _request_basis(request)
    invoice_basis = flt(
        sum(
            _invoice_basis(item)
            for item in invoices
            if int(getattr(item, "docstatus", 0) or 0) == 1
            and not int(getattr(item, "is_return", 0) or 0)
        ),
        6,
    )
    reversed_exists = bool(reversal_issues) or bool(
        frappe.db.exists(
            "OMC Accounting Link",
            {
                "service_request": request.name,
                "accounting_status": "Reversed",
            },
        )
    )
    state, capped = settlement_state(
        required=required,
        invoice_basis=invoice_basis,
        allocated=allocated,
        invalid_reason=human_reason,
        technical_reason=technical_reason,
        reversed_exists=reversed_exists,
    )

    reviews, quarantines = _persist_reconciliation_issues(request, issues)
    if not technical_issues and not human_issues:
        reconciliation_queues.resolve_source_queues(
            domain="Accounting",
            source_doctype=request.doctype,
            source_name=request.name,
        )

    reason = technical_reason or human_reason
    if not reason and reversal_issues:
        reason = reversal_issues[0]["message"]

    _project_link_state(request.name, state, reason)
    _project_receipt_compatibility(request.name, state, latest_payment)
    _apply_accounting_lifecycle(request, state, reason)

    if state == "Settled":
        from omc_app.api.bridge_outbox import enqueue_if_eligible

        enqueue_if_eligible(request.name)

    disposition = {
        "Quarantined": "technical_quarantine",
        "Review Required": "human_review",
        "Reversed": "reversed",
        "Settled": "clean",
        "Partially Settled": "clean",
        "Unmatched": "unmatched",
    }.get(state, "clean")
    return {
        "request": request.name,
        "request_state": request.request_state,
        "accounting_status": state,
        "reconciliation_disposition": disposition,
        "allocated_amount": capped,
        "required_amount": required,
        "remaining_amount": max(flt(required - capped, 6), 0),
        "linked_invoices": sorted(invoice_names),
        "payment_entry": latest_payment,
        "reconciliation_error": reason,
        "human_review_ids": sorted(set(reviews)),
        "technical_quarantine_ids": sorted(set(quarantines)),
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
        "OMC Accounting Link",
        filters={"payment_entry": doc.name},
        fields=["name", "service_request"],
        limit_page_length=1000,
    )
    requests = {row.service_request for row in links}
    for row in links:
        frappe.db.set_value(
            "OMC Accounting Link",
            row.name,
            {
                "accounting_status": "Reversed",
                "payment_docstatus": 2,
                "reconciled_at": now_datetime(),
            },
            update_modified=False,
        )
    from omc_app.api.commission_projection import reverse_payment_entry

    reverse_payment_entry(doc, reason="Payment Entry cancelled")
    for request_name in sorted(requests):
        reconcile_request(request_name)


def sales_invoice_cancelled(doc, method=None):
    requests = set(
        frappe.get_all(
            "OMC Accounting Link",
            filters={"sales_invoice": doc.name},
            pluck="service_request",
            limit_page_length=100,
        )
    )
    for request_name in sorted(requests):
        reconcile_request(request_name)


def sales_invoice_submitted(doc, method=None):
    if not int(getattr(doc, "is_return", 0) or 0) or not getattr(
        doc, "return_against", None
    ):
        return
    requests = set(
        frappe.get_all(
            "OMC Accounting Link",
            filters={"sales_invoice": doc.return_against},
            pluck="service_request",
            limit_page_length=100,
        )
    )
    for request_name in sorted(requests):
        reconcile_request(request_name)


@frappe.whitelist(methods=["POST"])
def approve_post_paid(service_request=None):
    capabilities.require("can_approve_post_paid")
    security.enforce_rate_limit("staff_mutation")
    name = _text(service_request)
    locked = frappe.db.get_value(
        "OMC Service Request", name, "name", for_update=True
    )
    if not locked:
        frappe.throw("Service request is not available.", frappe.DoesNotExistError)
    request = frappe.get_doc("OMC Service Request", locked)
    if request.payment_policy_snapshot != "Post-paid Approval":
        frappe.throw(
            "Request is not eligible for post-paid approval.",
            frappe.ValidationError,
        )
    if request.request_state != "Pending Payment":
        frappe.throw(
            "Request is not awaiting finance approval.",
            frappe.ValidationError,
        )

    frappe.db.set_value(
        request.doctype,
        request.name,
        {
            "post_paid_approved_by": frappe.session.user,
            "post_paid_approved_at": now_datetime(),
        },
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
    return {
        "success": True,
        "request_state": result.new_state,
        "operation": operation,
    }
