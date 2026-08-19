from __future__ import annotations

import frappe

from omc_app.api import accounting_reconciliation, capabilities, security


def _text(value) -> str:
    return str(value or "").strip()


def assert_invoice_matches_request(request, invoice) -> None:
    """Validate immutable OMC request authority against ERP accounting evidence."""
    if int(getattr(invoice, "docstatus", 0) or 0) != 1:
        frappe.throw("Only a submitted Sales Invoice can be linked.", frappe.ValidationError)
    if int(getattr(invoice, "is_return", 0) or 0):
        frappe.throw("A return Sales Invoice cannot be used as base settlement evidence.", frappe.ValidationError)

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
        frappe.throw("Sales Invoice customer does not match the service request.", frappe.ValidationError)
    if _text(invoice.company) != expected_company:
        frappe.throw("Sales Invoice company does not match the service request snapshot.", frappe.ValidationError)
    if _text(invoice.currency) != expected_currency:
        frappe.throw("Sales Invoice currency does not match the service request quote.", frappe.ValidationError)
    if frappe.utils.flt(getattr(invoice, "grand_total", 0) or 0, 6) <= 0:
        frappe.throw("Sales Invoice must have a positive total.", frappe.ValidationError)


@frappe.whitelist(methods=["POST"])
def link_sales_invoice(service_request=None, sales_invoice=None):
    capabilities.require("can_reconcile_settlement")
    security.enforce_rate_limit("staff_mutation")

    request_name = _text(service_request)
    invoice_name = _text(sales_invoice)
    if not request_name or not invoice_name:
        frappe.throw("service_request and sales_invoice are required.", frappe.ValidationError)

    locked = frappe.db.get_value(
        "OMC Service Request",
        request_name,
        "name",
        for_update=True,
    )
    if not locked or not frappe.db.exists("Sales Invoice", invoice_name):
        frappe.throw("Accounting source is not available.", frappe.DoesNotExistError)

    request = frappe.get_doc("OMC Service Request", locked)
    invoice = frappe.get_doc("Sales Invoice", invoice_name)
    assert_invoice_matches_request(request, invoice)

    return accounting_reconciliation.link_sales_invoice(
        service_request=request.name,
        sales_invoice=invoice.name,
    )
