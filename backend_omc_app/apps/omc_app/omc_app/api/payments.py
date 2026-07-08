import re

import frappe

from omc_app.api import mobile


ACTIVE_REQUEST_STATUSES = {"Open", "Waiting for Customer", "In Progress", "Under Review"}
PAYMENT_ACCOUNT_DOCTYPE = "OMC Payment Account"
PAYMENT_DOCTYPE = "OMC Service Payment"


def _clean_text(value):
    return (value or "").strip()


def _first_payment_account():
    if not mobile._has_doctype(PAYMENT_ACCOUNT_DOCTYPE):
        return None

    rows = frappe.get_all(
        PAYMENT_ACCOUNT_DOCTYPE,
        filters={"is_active": 1},
        fields=[
            "name",
            "title",
            "bank_name",
            "account_title",
            "account_number",
            "iban",
            "branch",
            "currency",
            "whatsapp_number",
            "instructions",
            "sort_order",
        ],
        order_by="sort_order asc, modified desc",
        limit=1,
    )

    return rows[0] if rows else None


def _digits_only(value):
    return re.sub(r"\D+", "", value or "")


def _payment_support_payload(payment=None, service_case=None):
    account = _first_payment_account()
    account_title = _clean_text(getattr(account, "account_title", "")) if account else ""
    bank_name = _clean_text(getattr(account, "bank_name", "")) if account else ""
    account_number = _clean_text(getattr(account, "account_number", "")) if account else ""
    iban = _clean_text(getattr(account, "iban", "")) if account else ""
    branch = _clean_text(getattr(account, "branch", "")) if account else ""
    whatsapp_number = _clean_text(getattr(account, "whatsapp_number", "")) if account else ""
    instructions = _clean_text(getattr(account, "instructions", "")) if account else ""

    bank_lines = []
    if bank_name:
        bank_lines.append(f"Bank: {bank_name}")
    if account_title:
        bank_lines.append(f"Account title: {account_title}")
    if account_number:
        bank_lines.append(f"Account number: {account_number}")
    if iban:
        bank_lines.append(f"IBAN: {iban}")
    if branch:
        bank_lines.append(f"Branch: {branch}")

    if not instructions:
        instructions = (
            "Contact OMC support for payment details, transfer the amount, "
            "then upload the receipt screenshot here for finance review."
        )

    case_name = getattr(service_case, "name", "") or getattr(payment, "service_request", "") or ""
    payment_name = getattr(payment, "name", "") or ""
    amount = getattr(payment, "amount", None)
    currency = getattr(payment, "currency", None) or (getattr(account, "currency", None) if account else None) or "PKR"

    message_parts = ["Hi OMC, I need payment details."]
    if case_name:
        message_parts.append(f"Service Request: {case_name}")
    if payment_name:
        message_parts.append(f"Payment ID: {payment_name}")
    if amount is not None:
        message_parts.append(f"Amount: {currency} {amount}")

    whatsapp_url = ""
    digits = _digits_only(whatsapp_number)
    if digits:
        whatsapp_url = "https://wa.me/{0}?text={1}".format(
            digits,
            frappe.utils.quote("\n".join(message_parts)),
        )

    return {
        "payment_instructions": instructions,
        "bank_account_details": "\n".join(bank_lines),
        "payment_url": whatsapp_url,
        "payment_link": whatsapp_url,
        "gateway_url": "",
        "whatsapp_number": whatsapp_number,
    }


def _approved_required_documents(service_case):
    required_templates = mobile._service_required_documents(service_case.service)
    required_templates = [row for row in required_templates if row.get("is_required")]

    if not required_templates:
        return True

    uploaded_docs = frappe.get_all(
        "OMC Service Document",
        filters={
            "service_request": service_case.name,
            "visible_to_customer": 1,
        },
        fields=["document_title", "document_type", "status", "attachment"],
    )

    approved_docs = [
        doc
        for doc in uploaded_docs
        if (doc.status or "").strip().lower() == "approved" and doc.attachment
    ]

    for template in required_templates:
        template_title = _clean_text(template.get("title") or template.get("document_title")).lower()
        template_type = _clean_text(template.get("type") or template.get("document_type")).lower()
        matched = False

        for doc in approved_docs:
            doc_title = _clean_text(doc.document_title).lower()
            doc_type = _clean_text(doc.document_type).lower()
            if template_title and doc_title == template_title:
                matched = True
                break
            if template_type and doc_type == template_type:
                matched = True
                break

        if not matched:
            return False

    return True


def _ensure_payment_for_case(service_case):
    if not mobile._has_doctype(PAYMENT_DOCTYPE):
        return None

    existing = frappe.get_all(
        PAYMENT_DOCTYPE,
        filters={
            "service_request": service_case.name,
            "visible_to_customer": 1,
            "status": ["not in", ["Cancelled"]],
        },
        fields=["name"],
        limit=1,
    )
    if existing:
        return existing[0].name

    if not _approved_required_documents(service_case):
        return None

    service = frappe.get_doc("OMC Service", service_case.service) if service_case.service and frappe.db.exists("OMC Service", service_case.service) else None

    payment = frappe.new_doc(PAYMENT_DOCTYPE)
    payment.service_request = service_case.name
    payment.payment_title = f"{service_case.service_title or getattr(service, 'title', None) or service_case.title or 'Service'} Payment"
    payment.amount = getattr(service, "base_price", None) or 0
    payment.currency = getattr(service, "currency", None) or "PKR"
    payment.status = "Pending"
    payment.visible_to_customer = 1
    payment.remarks = "Payment opened after required documents were approved."
    payment.insert(ignore_permissions=True)

    mobile._create_service_timeline_entry(
        service_request=service_case.name,
        event_type="Payment Opened",
        title="Payment Opened",
        description="Payment is now available. Contact OMC for payment details and upload your receipt after payment.",
        visible_to_customer=1,
    )

    frappe.db.commit()
    return payment.name


def _accessible_service_requests(profile=None):
    filters = {}
    if profile:
        filters["customer_profile"] = profile.name

    return frappe.get_all(
        "OMC Service Request",
        filters=filters,
        fields=["name", "title", "service", "service_title", "customer_profile", "status"],
        order_by="modified desc",
    )


def _ensure_available_payments(profile=None):
    for case_row in _accessible_service_requests(profile=profile):
        if case_row.status in {"Completed", "Cancelled"}:
            continue
        service_case = frappe.get_doc("OMC Service Request", case_row.name)
        _ensure_payment_for_case(service_case)


def _payment_dict(payment, capabilities=None):
    service_case = frappe.get_doc("OMC Service Request", payment.service_request) if payment.service_request else None
    support = _payment_support_payload(payment=payment, service_case=service_case)

    return {
        "name": payment.name,
        "payment_id": payment.name,
        "case_id": payment.service_request,
        "service_reference": payment.service_request,
        "title": payment.payment_title or "Service Payment",
        "amount": payment.amount or 0,
        "currency": payment.currency or "PKR",
        "status": payment.status or "Pending",
        "due_date": str(payment.due_date) if payment.due_date else "",
        "paid_on": str(payment.paid_on) if payment.paid_on else "",
        "payment_reference": payment.payment_reference or "",
        "receipt_url": payment.receipt_attachment or "",
        "remarks": payment.remarks or "",
        "can_review_payments": (capabilities or {}).get("can_review_payments", False),
        **support,
    }


@frappe.whitelist()
def get_payments():
    profile = None if mobile._can_access_internal_workspace() else mobile._assert_approved_customer()
    capabilities = mobile._get_mobile_capabilities(profile=profile)

    _ensure_available_payments(profile=profile)

    service_request_names = [row.name for row in _accessible_service_requests(profile=profile)]
    if not service_request_names:
        return {"payments": []}

    payment_names = frappe.get_all(
        PAYMENT_DOCTYPE,
        filters={
            "service_request": ["in", service_request_names],
            "visible_to_customer": 1,
        },
        pluck="name",
        order_by="due_date desc, creation desc",
    )

    return {
        "payments": [
            _payment_dict(frappe.get_doc(PAYMENT_DOCTYPE, name), capabilities=capabilities)
            for name in payment_names
        ]
    }


@frappe.whitelist()
def get_payment(payment_id=None, name=None):
    payment_id = payment_id or name
    if not payment_id:
        frappe.throw("payment_id is required")

    if not frappe.db.exists(PAYMENT_DOCTYPE, payment_id):
        frappe.throw("Payment not found", frappe.DoesNotExistError)

    payment = frappe.get_doc(PAYMENT_DOCTYPE, payment_id)
    if not payment.visible_to_customer:
        frappe.throw("Payment not found", frappe.DoesNotExistError)

    profile = None if mobile._can_access_internal_workspace() else mobile._assert_approved_customer()
    capabilities = mobile._get_mobile_capabilities(profile=profile)
    service_case = frappe.get_doc("OMC Service Request", payment.service_request)

    if profile and service_case.customer_profile and service_case.customer_profile != profile.name:
        frappe.throw("You do not have permission to access this payment", frappe.PermissionError)

    return _payment_dict(payment, capabilities=capabilities)
