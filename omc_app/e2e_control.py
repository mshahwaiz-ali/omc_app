from __future__ import annotations

import os

import frappe
from frappe.utils import flt, now_datetime, nowdate, time_diff_in_hours

from omc_app.api import accounting_policy, bridge_outbox, capabilities, payments


def _required_env(name: str) -> str:
    value = str(os.environ.get(name) or "").strip()
    if not value:
        frappe.throw(f"{name} is required for the customer E2E control actor.")
    return value


def _guard_local_e2e() -> None:
    if str(os.environ.get("OMC_E2E_CONTROL") or "").strip() != "1":
        frappe.throw("OMC_E2E_CONTROL=1 is required for the customer E2E control actor.")
    site = str(getattr(frappe.local, "site", "") or "").strip().lower()
    if not (site == "localhost" or site.endswith(".local")):
        frappe.throw(
            "The customer E2E control actor is restricted to local development sites."
        )


def _profile_for_user(user: str):
    for filters in (
        {"user": user},
        {"linked_app_user": user},
        {"email": user},
        {"username": user},
    ):
        name = frappe.db.get_value("OMC Customer Profile", filters, "name")
        if name:
            return frappe.get_doc("OMC Customer Profile", name)
    frappe.throw(f"No OMC Customer Profile is linked to E2E customer {user}.")


def _service_for_title(title: str):
    names = frappe.get_all(
        "OMC Service",
        filters={"title": title, "is_active": 1},
        pluck="name",
        limit_page_length=2,
    )
    if len(names) != 1:
        frappe.throw(
            f'E2E_SERVICE_TITLE must resolve to exactly one active service; "{title}" '
            f"resolved to {len(names)}."
        )
    return frappe.get_doc("OMC Service", names[0])


def _runtime_context() -> dict:
    _guard_local_e2e()
    customer_user = _required_env("E2E_USERNAME")
    service_title = _required_env("E2E_SERVICE_TITLE")
    finance_user = _required_env("E2E_FINANCE_USER")
    invoice_item = _required_env("E2E_INVOICE_ITEM_CODE")
    payment_account = _required_env("E2E_PAYMENT_ACCOUNT")

    profile = _profile_for_user(customer_user)
    service = _service_for_title(service_title)

    customer_caps = capabilities.effective(customer_user)
    if not customer_caps.get("can_create_service_request"):
        frappe.throw(
            "E2E customer is not an approved customer with service-request access."
        )
    for capability in ("can_review_payments", "can_reconcile_settlement"):
        capabilities.require(capability, user=finance_user)

    if not frappe.db.exists("User", finance_user):
        frappe.throw(f"E2E finance user does not exist: {finance_user}")
    if not frappe.db.get_value("User", finance_user, "enabled"):
        frappe.throw(f"E2E finance user is disabled: {finance_user}")
    if not frappe.has_permission("Sales Invoice", "create", user=finance_user):
        frappe.throw("E2E finance user cannot create Sales Invoices in ERPNext.")
    if not frappe.has_permission("Payment Entry", "create", user=finance_user):
        frappe.throw("E2E finance user cannot create Payment Entries in ERPNext.")

    if str(service.activation_policy or "").strip() != "Full Settlement":
        frappe.throw(
            "Phase 2 customer E2E requires a Full Settlement service so the real "
            "accounting and activation bridge can be exercised."
        )
    if flt(service.base_price) <= 0:
        frappe.throw("Phase 2 customer E2E requires a positive service base price.")
    company = str(service.company or "").strip()
    if not company or not frappe.db.exists("Company", company):
        frappe.throw("The selected E2E service must have an authoritative ERP company.")

    company_currency = str(
        frappe.db.get_value("Company", company, "default_currency") or ""
    ).strip()
    service_currency = str(service.currency or company_currency).strip()
    if not company_currency or service_currency != company_currency:
        frappe.throw(
            "Phase 2 E2E currently requires the service currency to match the ERP "
            "company default currency; it will not invent an exchange rate."
        )

    erp_customer = str(profile.linked_erpnext_customer or "").strip()
    if not erp_customer or not frappe.db.exists("Customer", erp_customer):
        frappe.throw(
            "The E2E customer must be linked to a real ERPNext Customer before settlement."
        )
    if not frappe.db.exists("Item", invoice_item):
        frappe.throw(f"E2E invoice item does not exist: {invoice_item}")

    account = frappe.db.get_value(
        "Account",
        payment_account,
        ["name", "company", "is_group", "root_type"],
        as_dict=True,
    )
    if not account:
        frappe.throw(f"E2E payment account does not exist: {payment_account}")
    if account.company != company or account.is_group or account.root_type != "Asset":
        frappe.throw(
            "E2E_PAYMENT_ACCOUNT must be a leaf Asset account for the selected service company."
        )

    return {
        "customer_user": customer_user,
        "finance_user": finance_user,
        "profile": profile,
        "service": service,
        "company": company,
        "currency": service_currency,
        "erp_customer": erp_customer,
        "invoice_item": invoice_item,
        "payment_account": payment_account,
    }


def preflight() -> str:
    """Fail fast on real-customer and ERP accounting prerequisites."""
    context = _runtime_context()
    return (
        f"ok|customer={context['customer_user']}|service={context['service'].name}"
        f"|company={context['company']}"
    )


def _latest_receipt_request(context: dict):
    rows = frappe.get_all(
        "OMC Service Request",
        filters={
            "customer_profile": context["profile"].name,
            "service": context["service"].name,
        },
        fields=["name", "creation"],
        order_by="creation desc",
        limit_page_length=1,
    )
    if not rows:
        frappe.throw("No E2E customer request was created for the selected service.")
    if time_diff_in_hours(now_datetime(), rows[0].creation) > 1:
        frappe.throw(
            "The latest matching customer request is older than one hour; refusing "
            "to settle a stale request."
        )

    request = frappe.get_doc("OMC Service Request", rows[0].name)
    payment_name = frappe.db.get_value(
        "OMC Payment",
        {
            "service_request": request.name,
            "status": ["in", ["Receipt Submitted", "Under Review", "Paid"]],
        },
        "name",
        order_by="creation desc",
    )
    if not payment_name:
        frappe.throw(
            "The latest E2E request does not have submitted customer payment proof."
        )
    payment = frappe.get_doc("OMC Payment", payment_name)
    if not str(payment.receipt_attachment or "").strip():
        frappe.throw("The E2E payment has no real uploaded receipt attachment.")
    return request, payment


def _create_sales_invoice(context: dict, request):
    amount = flt(request.payable_amount)
    if amount <= 0:
        frappe.throw("The E2E request payable amount must be positive.")

    company = str(getattr(request, "company_snapshot", None) or context["company"]).strip()
    currency = str(request.pricing_currency or context["currency"]).strip()
    customer = str(request.erp_customer or context["erp_customer"]).strip()
    if company != context["company"] or currency != context["currency"]:
        frappe.throw(
            "The request pricing snapshot no longer matches the selected E2E service company/currency."
        )
    if customer != context["erp_customer"]:
        frappe.throw("The request ERP customer does not match the E2E customer mapping.")

    invoice = frappe.new_doc("Sales Invoice")
    invoice.customer = customer
    invoice.company = company
    invoice.posting_date = nowdate()
    invoice.due_date = nowdate()
    invoice.currency = currency
    invoice.append(
        "items",
        {
            "item_code": context["invoice_item"],
            "qty": 1,
            "rate": amount,
        },
    )
    invoice.insert()
    invoice.submit()

    if abs(flt(invoice.grand_total) - amount) > 0.01:
        frappe.throw(
            "The submitted E2E Sales Invoice total does not equal the authoritative request payable amount."
        )
    return invoice


def _create_payment_entry(context: dict, invoice):
    from erpnext.accounts.doctype.payment_entry.payment_entry import get_payment_entry

    payment_entry = get_payment_entry("Sales Invoice", invoice.name)
    payment_entry.paid_to = context["payment_account"]
    payment_entry.reference_no = f"OMC-E2E-{invoice.name}"
    payment_entry.reference_date = nowdate()
    payment_entry.insert()
    payment_entry.submit()
    return payment_entry


def settle_latest_customer_request() -> str:
    """Use real finance review, ERP settlement, reconciliation and bridge logic."""
    context = _runtime_context()
    request, payment = _latest_receipt_request(context)

    settled_link = frappe.db.get_value(
        "OMC Accounting Link",
        {"service_request": request.name, "accounting_status": "Settled"},
        "name",
    )
    if settled_link and request.request_state == "Activated":
        return request.name

    frappe.set_user(context["finance_user"])

    if payment.status == "Receipt Submitted":
        payments.review_payment_receipt(
            payment_id=payment.name,
            status="Paid",
            remarks="OMC E2E finance review accepted the submitted receipt.",
        )
        payment.reload()
    if payment.status not in {"Under Review", "Paid"}:
        frappe.throw(
            f"E2E payment cannot be settled from current status {payment.status}."
        )

    link = frappe.db.get_value(
        "OMC Accounting Link",
        {"service_request": request.name},
        ["name", "sales_invoice", "accounting_status"],
        as_dict=True,
    )
    invoice = None
    if link and link.sales_invoice and frappe.db.exists("Sales Invoice", link.sales_invoice):
        invoice = frappe.get_doc("Sales Invoice", link.sales_invoice)
    if invoice is None:
        invoice = _create_sales_invoice(context, request)
        accounting_policy.link_sales_invoice(
            service_request=request.name,
            sales_invoice=invoice.name,
        )
        frappe.db.commit()

    if invoice.docstatus != 1:
        frappe.throw("The E2E Sales Invoice must be submitted before settlement.")

    current_link_state = frappe.db.get_value(
        "OMC Accounting Link",
        {"service_request": request.name},
        "accounting_status",
    )
    if current_link_state != "Settled":
        _create_payment_entry(context, invoice)
        frappe.db.commit()

    request.reload()
    payment.reload()
    current_link_state = frappe.db.get_value(
        "OMC Accounting Link",
        {"service_request": request.name},
        "accounting_status",
    )
    if current_link_state != "Settled":
        frappe.throw(
            f"ERP Payment Entry did not reconcile the request to Settled; got {current_link_state}."
        )
    if payment.status != "Paid":
        frappe.throw(
            f"Settled accounting did not project payment status to Paid; got {payment.status}."
        )

    operation_name = bridge_outbox.enqueue_if_eligible(request.name)
    if not operation_name:
        operation_name = frappe.db.get_value(
            "OMC Bridge Operation",
            {"service_request": request.name, "operation_type": "Activate Request"},
            "name",
            order_by="creation desc",
        )
    if not operation_name:
        frappe.throw("Settlement did not create an activation bridge operation.")

    bridge_result = bridge_outbox.process_operation(operation_name)
    frappe.db.commit()
    request.reload()
    if bridge_result.get("status") != "completed" or request.request_state != "Activated":
        frappe.throw(
            "The real activation bridge did not complete the E2E request: "
            f"{bridge_result}."
        )
    if not request.erp_service or not request.erp_task:
        frappe.throw("Activated E2E request is missing ERP Service/Task links.")

    return request.name
