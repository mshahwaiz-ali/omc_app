import base64
import re
from urllib.parse import quote

import frappe

from omc_app.api import access, mobile


PAYMENT_ACCOUNT_DOCTYPE = "OMC Payment Account"
PAYMENT_DOCTYPE = "OMC Service Payment"
DEFAULT_PAYMENT_WHATSAPP_NUMBER = "923001234567"
ALLOWED_RECEIPT_EXTENSIONS = {"pdf", "jpg", "jpeg", "png"}
MAX_RECEIPT_SIZE_BYTES = 10 * 1024 * 1024


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


def _file_extension(file_name):
    clean_name = _clean_text(file_name).split("?")[0].rsplit("/", 1)[-1]
    if "." not in clean_name:
        return ""
    return clean_name.rsplit(".", 1)[-1].lower().strip()


def _assert_payment_customer_access(payment):
    profile = None if mobile._can_access_internal_workspace() else mobile._assert_approved_customer()
    service_case = frappe.get_doc("OMC Service Request", payment.service_request)

    if profile and service_case.customer_profile and service_case.customer_profile != profile.name:
        frappe.throw("You do not have permission to update this payment", frappe.PermissionError)

    return profile, service_case


def _payment_support_payload(payment=None, service_case=None):
    account = _first_payment_account()
    account_title = _clean_text(getattr(account, "account_title", "")) if account else ""
    bank_name = _clean_text(getattr(account, "bank_name", "")) if account else ""
    account_number = _clean_text(getattr(account, "account_number", "")) if account else ""
    iban = _clean_text(getattr(account, "iban", "")) if account else ""
    branch = _clean_text(getattr(account, "branch", "")) if account else ""
    whatsapp_number = _clean_text(getattr(account, "whatsapp_number", "")) if account else ""
    instructions = _clean_text(getattr(account, "instructions", "")) if account else ""

    if not whatsapp_number:
        whatsapp_number = DEFAULT_PAYMENT_WHATSAPP_NUMBER

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
            "Contact OMC support on WhatsApp for payment details, transfer the amount, "
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
            quote("\n".join(message_parts)),
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
        event_type="Payment Updated",
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


def _payment_dict(payment, capabilities=None, *, customer_view=False):
    capabilities = capabilities or {}
    service_case = (
        frappe.get_doc("OMC Service Request", payment.service_request)
        if payment.service_request
        else None
    )
    support = (
        _payment_support_payload(payment=payment, service_case=service_case)
        if customer_view
        else {}
    )
    can_view_receipt = bool(capabilities.get("can_view_payment_receipts"))
    can_review = bool(capabilities.get("can_review_payments"))

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
        "payment_reference": (
            payment.payment_reference or ""
            if customer_view or can_view_receipt
            else ""
        ),
        "receipt_url": (
            payment.receipt_attachment or ""
            if customer_view or can_view_receipt
            else ""
        ),
        "remarks": payment.remarks or "" if customer_view or can_review else "",
        "can_review_payments": can_review,
        **support,
    }


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

    # Read endpoints must never create payment records or mutate workflow state.
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
            _payment_dict(
                frappe.get_doc(PAYMENT_DOCTYPE, name),
                capabilities=capabilities,
                customer_view=profile is not None,
            )
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

    is_internal = mobile._can_access_internal_workspace()
    profile = None if is_internal else mobile._assert_approved_customer()
    capabilities = access.get_mobile_capabilities()
    service_case = frappe.get_doc("OMC Service Request", payment.service_request)

    if profile and service_case.customer_profile and service_case.customer_profile != profile.name:
        frappe.throw("You do not have permission to access this payment", frappe.PermissionError)

    if is_internal and not (
        capabilities.get("can_view_payment_summaries")
        or capabilities.get("can_view_payment_receipts")
        or capabilities.get("can_review_payments")
    ):
        frappe.throw(
            "You do not have permission to access this payment.",
            frappe.PermissionError,
        )

    return _payment_dict(
        payment,
        capabilities=capabilities,
        customer_view=profile is not None,
    )


@frappe.whitelist()
def upload_payment_receipt_file(payment_id=None, name=None, file_name=None, content_base64=None, payment_reference=None, remarks=None):
    payment_id = payment_id or name
    if not payment_id:
        frappe.throw("payment_id is required")
    if not file_name:
        frappe.throw("file_name is required")
    if not content_base64:
        frappe.throw("content_base64 is required")

    if not frappe.db.exists(PAYMENT_DOCTYPE, payment_id):
        frappe.throw("Payment not found", frappe.DoesNotExistError)

    payment = frappe.get_doc(PAYMENT_DOCTYPE, payment_id)
    profile, _service_case = _assert_payment_customer_access(payment)
    if profile is None:
        frappe.throw(
            "Payment receipt upload is a customer action.",
            frappe.PermissionError,
        )

    capabilities = access.get_mobile_capabilities()
    if not (
        capabilities.get("can_upload_payment_receipt")
        or capabilities.get("can_upload_payment_receipts")
    ):
        frappe.throw(
            "You do not have permission to upload payment receipts.",
            frappe.PermissionError,
        )

    extension = _file_extension(file_name)
    if extension not in ALLOWED_RECEIPT_EXTENSIONS:
        frappe.throw("Unsupported receipt type. Please upload PDF, JPG or PNG files only.")

    try:
        content = base64.b64decode(content_base64)
    except Exception:
        frappe.throw("Receipt file data is invalid. Please choose the file again.")

    if not content:
        frappe.throw("Uploaded receipt is empty.")
    if len(content) > MAX_RECEIPT_SIZE_BYTES:
        frappe.throw("Receipt is too large. Maximum allowed size is 10 MB.")

    file_doc = frappe.get_doc({
        "doctype": "File",
        "file_name": file_name,
        "attached_to_doctype": PAYMENT_DOCTYPE,
        "attached_to_name": payment.name,
        "is_private": 1,
        "content": content,
    })
    file_doc.insert(ignore_permissions=True)

    payment.receipt_attachment = file_doc.file_url
    payment.payment_reference = payment_reference or payment.payment_reference
    payment.remarks = remarks or payment.remarks
    payment.status = "Receipt Submitted"
    payment.save(ignore_permissions=True)

    mobile._create_service_timeline_entry(
        service_request=payment.service_request,
        event_type="Payment Updated",
        title="Payment Receipt Submitted",
        description=remarks or f"Receipt submitted for {payment.payment_title or 'payment'} and is waiting for OMC review.",
        visible_to_customer=1,
    )

    frappe.db.commit()

    return {
        "updated": True,
        "name": payment.name,
        "case_id": payment.service_request,
        "status": payment.status,
        "receipt_url": payment.receipt_attachment or "",
        "payment_reference": payment.payment_reference or "",
        "remarks": payment.remarks or "",
        "file_url": file_doc.file_url,
    }
