import base64
import re
from urllib.parse import quote

import frappe

from omc_app.api import access, mobile, review_routing


PAYMENT_ACCOUNT_DOCTYPE = "OMC Payment Account"
PAYMENT_DOCTYPE = "OMC Service Payment"
DEFAULT_PAYMENT_WHATSAPP_NUMBER = "923122114116"
ALLOWED_RECEIPT_EXTENSIONS = {"pdf", "jpg", "jpeg", "png"}
MAX_RECEIPT_SIZE_BYTES = 10 * 1024 * 1024


def _require_payment_review_access():
    capabilities = access.get_mobile_capabilities()
    if not capabilities.get("can_review_payments"):
        frappe.throw(
            "You do not have permission to review payments.",
            frappe.PermissionError,
        )
    return capabilities


def _clean_text(value):
    return (value or "").strip()


def _current_user():
    user = frappe.session.user if getattr(frappe, "session", None) else "Guest"
    return user or "Guest"


def _customer_profile_name_for_user(user):
    if not user or user == "Guest":
        return None

    for filters in (
        {"linked_app_user": user},
        {"user": user},
        {"email": user},
    ):
        profile_name = frappe.db.get_value(
            "OMC Customer Profile",
            filters,
            "name",
        )
        if profile_name:
            return profile_name

    return None


def _owned_referral_profile_names(user):
    if not user or user == "Guest":
        return []

    return frappe.get_all(
        "OMC Customer Profile",
        filters={
            "referred_by": user,
            "referral_assistance_consent": 1,
        },
        pluck="name",
    )


def _accessible_service_request_names(*, profile=None, internal_user=None):
    if profile:
        return set(
            frappe.get_all(
                "OMC Service Request",
                filters={"customer_profile": profile.name},
                pluck="name",
            )
        )

    user = internal_user or _current_user()
    if not user or user == "Guest":
        return set()

    accessible = set()

    own_profile_name = _customer_profile_name_for_user(user)
    if own_profile_name:
        accessible.update(
            frappe.get_all(
                "OMC Service Request",
                filters={"customer_profile": own_profile_name},
                pluck="name",
            )
        )

    referral_profiles = _owned_referral_profile_names(user)
    if referral_profiles:
        accessible.update(
            frappe.get_all(
                "OMC Service Request",
                filters={
                    "customer_mode": "My Referral",
                    "referral_owner": user,
                    "customer_profile": ["in", referral_profiles],
                },
                pluck="name",
            )
        )

    return accessible


def _assert_service_request_payment_access(
    service_request,
    *,
    profile=None,
    internal_user=None,
):
    accessible = _accessible_service_request_names(
        profile=profile,
        internal_user=internal_user,
    )
    if service_request not in accessible:
        frappe.throw(
            "You do not have permission to access this payment.",
            frappe.PermissionError,
        )


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
        # Compatibility: existing mobile clients read payment_url/payment_link.
        # This URL opens WhatsApp support; it is not an online gateway checkout.
        "payment_url": whatsapp_url,
        "payment_link": whatsapp_url,
        "gateway_url": "",
        "payment_channel": "whatsapp_support",
        "payment_action_label": "Contact OMC on WhatsApp",
        "online_gateway_available": False,
        "whatsapp_number": whatsapp_number,
    }



def _notify_customer(
    service_case,
    *,
    title,
    message,
    notification_type="Service",
    reference_doctype="OMC Service Request",
    reference_name=None,
):
    if not getattr(service_case, "customer_profile", None):
        return None
    return mobile._create_customer_notification(
        customer_profile=service_case.customer_profile,
        title=title,
        message=message,
        notification_type=notification_type,
        reference_doctype=reference_doctype,
        reference_name=reference_name or service_case.name,
    )


def _cleanup_failed_receipt_file(file_doc, payment):
    if not file_doc:
        return False

    file_name = getattr(file_doc, "name", None)
    if not file_name:
        return False

    try:
        if not frappe.db.exists("File", file_name):
            return False

        persisted = frappe.get_doc("File", file_name)
        if (
            (persisted.attached_to_doctype or "")
            != PAYMENT_DOCTYPE
            or (persisted.attached_to_name or "")
            != payment.name
        ):
            return False

        linked_payment = frappe.db.exists(
            PAYMENT_DOCTYPE,
            {
                "name": payment.name,
                "receipt_attachment": (
                    persisted.file_url or ""
                ),
            },
        )
        if linked_payment:
            return False

        frappe.delete_doc(
            "File",
            persisted.name,
            ignore_permissions=True,
            force=True,
        )
        return True
    except Exception:
        frappe.log_error(
            frappe.get_traceback(),
            "Payment receipt cleanup failed",
        )
        return False


def _payment_receipt_submission_is_unchanged(
    payment,
    *,
    receipt_attachment,
    payment_reference="",
    remarks="",
):
    return (
        (payment.status or "").strip() == "Receipt Submitted"
        and (payment.receipt_attachment or "").strip()
        == (receipt_attachment or "").strip()
        and (payment.payment_reference or "").strip()
        == (payment_reference or "").strip()
        and (payment.remarks or "").strip()
        == (remarks or "").strip()
    )


def _assert_payment_accepts_receipt(payment):
    status = (payment.status or "").strip()
    if status in {"Paid", "Cancelled"}:
        frappe.throw(
            (
                "A receipt cannot be uploaded after this payment is "
                f"{status.lower()}."
            ),
            frappe.ValidationError,
        )


def _set_case_status(service_case, status):
    if not service_case or service_case.status in {"Completed", "Cancelled"}:
        return False
    if service_case.status == status:
        return False
    service_case.status = status
    service_case.save(ignore_permissions=True)
    return True



def _approved_required_documents(service_case):
    required_templates = mobile._service_required_documents(
        service_case.service
    )

    uploaded_docs = frappe.get_all(
        "OMC Service Document",
        filters={
            "service_request": service_case.name,
            "visible_to_customer": 1,
        },
        fields=[
            "document_title",
            "document_type",
            "status",
            "attachment",
        ],
    )

    documents = [
        {
            "document_title": doc.document_title or "",
            "document_type": doc.document_type or "",
            "status": doc.status or "",
            "attachment": doc.attachment or "",
        }
        for doc in uploaded_docs
    ]

    return mobile._required_documents_complete(
        required_templates,
        documents,
    )



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

    service = (
        frappe.get_doc("OMC Service", service_case.service)
        if service_case.service
        and frappe.db.exists("OMC Service", service_case.service)
        else None
    )
    request_final_price = getattr(service_case, "final_price", None)
    amount = frappe.utils.flt(
        request_final_price
        if request_final_price is not None
        else getattr(service, "base_price", None) or 0
    )
    if amount <= 0:
        frappe.log_error(
            message=(
                f"Payment was not opened for service request {service_case.name} "
                "because the linked service has no positive base price."
            ),
            title="OMC Payment Automation Configuration",
        )
        return None

    payment = frappe.new_doc(PAYMENT_DOCTYPE)
    payment.service_request = service_case.name
    payment.payment_title = (
        f"{service_case.service_title or getattr(service, 'title', None) or service_case.title or 'Service'} Payment"
    )
    payment.amount = amount
    payment.currency = (
        getattr(service_case, "pricing_currency", None)
        or getattr(service, "currency", None)
        or "PKR"
    )
    payment.status = "Pending"
    payment.visible_to_customer = 1
    payment.remarks = "Payment opened after required documents were approved."
    payment.insert(ignore_permissions=True)

    _set_case_status(service_case, "Waiting for Payment")

    message = (
        f"Your required documents are approved. Payment of "
        f"{payment.currency} {payment.amount:g} is now available."
    )
    mobile._create_service_timeline_entry(
        service_request=service_case.name,
        event_type="Payment Updated",
        title="Payment Opened",
        description=message,
        visible_to_customer=1,
    )
    _notify_customer(
        service_case,
        title="Payment is ready",
        message=message,
        notification_type="Payment",
        reference_doctype=PAYMENT_DOCTYPE,
        reference_name=payment.name,
    )

    frappe.db.commit()
    return payment.name


def handle_document_review(service_request, status, remarks=None):
    if not service_request or not frappe.db.exists(
        "OMC Service Request", service_request
    ):
        return {"payment": None, "case_status": None}

    service_case = frappe.get_doc("OMC Service Request", service_request)
    normalized = _clean_text(status).lower()
    payment_name = None

    if normalized == "rejected":
        changed = _set_case_status(service_case, "Waiting for Customer")
        message = remarks or (
            "A document needs correction. Review the rejection reason and upload "
            "a replacement document."
        )
        _notify_customer(
            service_case,
            title="Document needs attention",
            message=message,
            notification_type="Document",
        )
        if changed:
            mobile._create_service_timeline_entry(
                service_request=service_case.name,
                event_type="Status Updated",
                title="Waiting for Customer",
                description="The request is waiting for a corrected document.",
                visible_to_customer=1,
            )

    elif normalized == "approved":
        payment_name = _ensure_payment_for_case(service_case)
        if not payment_name:
            _notify_customer(
                service_case,
                title="Document approved",
                message=remarks or "Your document has been approved.",
                notification_type="Document",
            )

    return {
        "payment": payment_name,
        "case_status": service_case.status,
    }


def _accessible_service_requests(profile=None, internal_user=None):
    names = _accessible_service_request_names(
        profile=profile,
        internal_user=internal_user,
    )
    if not names:
        return []

    return frappe.get_all(
        "OMC Service Request",
        filters={"name": ["in", list(names)]},
        fields=[
            "name",
            "title",
            "service",
            "service_title",
            "customer_profile",
            "status",
        ],
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

    customer_profile = (
        frappe.get_doc("OMC Customer Profile", service_case.customer_profile)
        if service_case
        and service_case.customer_profile
        and frappe.db.exists("OMC Customer Profile", service_case.customer_profile)
        else None
    )
    current_user = _current_user()
    own_profile_name = _customer_profile_name_for_user(current_user)
    scope_type = (
        "own"
        if customer_view
        or (
            own_profile_name
            and service_case
            and service_case.customer_profile == own_profile_name
        )
        else "referral"
        if service_case
        and service_case.referral_owner == current_user
        and (service_case.customer_mode or "").strip() == "My Referral"
        else ""
    )

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
        "customer_profile": (
            service_case.customer_profile if service_case else ""
        ),
        "customer_name": (
            customer_profile.full_name
            if customer_profile
            else getattr(service_case, "customer_name", "") or ""
        ),
        "scope_type": scope_type,
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
    internal_user = _current_user() if is_internal else None
    service_request_names = [
        row.name
        for row in _accessible_service_requests(
            profile=profile,
            internal_user=internal_user,
        )
    ]
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

    _assert_service_request_payment_access(
        service_case.name,
        profile=profile,
        internal_user=_current_user() if is_internal else None,
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

    return _payment_dict(
        payment,
        capabilities=capabilities,
        customer_view=profile is not None,
    )


@frappe.whitelist()
def upload_payment_receipt_file(
    payment_id=None,
    name=None,
    file_name=None,
    content_base64=None,
    payment_reference=None,
    remarks=None,
):
    payment_id = payment_id or name
    if not payment_id:
        frappe.throw("payment_id is required")
    if not file_name:
        frappe.throw("file_name is required")
    if not content_base64:
        frappe.throw("content_base64 is required")

    if not frappe.db.exists(PAYMENT_DOCTYPE, payment_id):
        frappe.throw(
            "Payment not found",
            frappe.DoesNotExistError,
        )

    payment = frappe.get_doc(PAYMENT_DOCTYPE, payment_id)
    profile, service_case = _assert_payment_customer_access(
        payment
    )
    if not profile:
        frappe.throw(
            "Payment receipt upload is a customer action.",
            frappe.PermissionError,
        )

    _assert_payment_accepts_receipt(payment)

    capabilities = mobile._get_mobile_capabilities()
    if not (
        capabilities.get("can_upload_payment_receipt")
        or capabilities.get("can_upload_payment_receipts")
    ):
        frappe.throw(
            "You do not have permission to upload payment receipts.",
            frappe.PermissionError,
        )

    file_doc = None
    try:
        file_doc = mobile._save_base64_file(
            file_name=file_name,
            content_base64=content_base64,
            is_private=1,
            attached_to_doctype=PAYMENT_DOCTYPE,
            attached_to_name=payment.name,
        )

        clean_reference = (payment_reference or "").strip()
        clean_remarks = (remarks or "").strip()

        if _payment_receipt_submission_is_unchanged(
            payment,
            receipt_attachment=file_doc.file_url,
            payment_reference=clean_reference,
            remarks=clean_remarks,
        ):
            _cleanup_failed_receipt_file(
                file_doc,
                payment,
            )
            return {
                "updated": False,
                "name": payment.name,
                "case_id": payment.service_request,
                "status": payment.status,
                "receipt_url": (
                    payment.receipt_attachment or ""
                ),
                "payment_reference": (
                    payment.payment_reference or ""
                ),
                "remarks": payment.remarks or "",
                "message": "No payment receipt change.",
            }

        payment.receipt_attachment = file_doc.file_url
        payment.payment_reference = clean_reference
        payment.remarks = clean_remarks
        payment.status = "Receipt Submitted"
        payment.paid_on = None
        payment.save(ignore_permissions=True)

        description = (
            clean_remarks
            or (
                f"Receipt submitted for "
                f"{payment.payment_title or 'payment'} "
                "and is waiting for OMC review."
            )
        )
        mobile._create_service_timeline_entry(
            service_request=payment.service_request,
            event_type="Payment Updated",
            title="Payment Receipt Submitted",
            description=description,
            visible_to_customer=1,
        )

        _set_case_status(
            service_case,
            "Waiting for Payment",
        )
        review_routing.ensure_review_assignment(payment, service_case)

        frappe.db.commit()

        return {
            "updated": True,
            "name": payment.name,
            "case_id": payment.service_request,
            "status": payment.status,
            "receipt_url": (
                payment.receipt_attachment or ""
            ),
            "payment_reference": (
                payment.payment_reference or ""
            ),
            "remarks": payment.remarks or "",
        }
    except Exception:
        _cleanup_failed_receipt_file(
            file_doc,
            payment,
        )
        raise




@frappe.whitelist()
def review_payment_receipt(
    payment_id=None,
    name=None,
    status=None,
    remarks=None,
    payment_reference=None,
):
    _require_payment_review_access()

    payment_id = payment_id or name
    if not payment_id:
        frappe.throw("payment_id is required")
    if not status:
        frappe.throw("status is required")

    allowed_statuses = {
        "Under Review",
        "Paid",
        "Rejected",
        "Cancelled",
    }
    if status not in allowed_statuses:
        frappe.throw(
            "status must be one of: Under Review, Paid, Rejected, Cancelled"
        )

    if not frappe.db.exists(PAYMENT_DOCTYPE, payment_id):
        frappe.throw(
            "Payment not found",
            frappe.DoesNotExistError,
        )

    payment = frappe.get_doc(PAYMENT_DOCTYPE, payment_id)
    service_case = frappe.get_doc(
        "OMC Service Request",
        payment.service_request,
    )
    _assert_service_request_payment_access(
        service_case.name,
        internal_user=_current_user(),
    )

    case_status = (service_case.status or "").strip()
    if case_status in {"Completed", "Cancelled"}:
        frappe.throw(
            (
                "Payments cannot be reviewed after a service request is "
                f"{case_status.lower()}."
            ),
            frappe.ValidationError,
        )

    old_status = (payment.status or "").strip()
    clean_remarks = (remarks or "").strip()

    if old_status == status:
        return {
            "updated": False,
            "name": payment.name,
            "case_id": payment.service_request,
            "old_status": old_status,
            "status": old_status,
            "paid_on": mobile._format_datetime(payment.paid_on),
            "receipt_url": payment.receipt_attachment or "",
            "payment_reference": payment.payment_reference or "",
            "remarks": payment.remarks or "",
            "case_status": service_case.status,
            "case_transition_status": None,
            "message": "No payment status change.",
        }

    if old_status in {"Paid", "Cancelled"}:
        frappe.throw(
            (
                f"A {old_status.lower()} payment review is final "
                "and cannot be changed."
            ),
            frappe.ValidationError,
        )

    if old_status == "Rejected":
        frappe.throw(
            (
                "A rejected payment must receive a new customer "
                "receipt before it can be reviewed again."
            ),
            frappe.ValidationError,
        )

    allowed_transitions = {
        "Pending": {"Cancelled"},
        "Receipt Submitted": {
            "Under Review",
            "Paid",
            "Rejected",
            "Cancelled",
        },
        "Under Review": {
            "Paid",
            "Rejected",
            "Cancelled",
        },
        "": {"Cancelled"},
    }
    if status not in allowed_transitions.get(old_status, set()):
        frappe.throw(
            (
                "Invalid payment status transition: "
                f"{old_status or 'None'} to {status}."
            ),
            frappe.ValidationError,
        )

    if status in {"Under Review", "Paid", "Rejected"}:
        if not payment.receipt_attachment:
            frappe.throw(
                (
                    "A receipt must be uploaded before this "
                    f"payment can be marked as {status}."
                ),
                frappe.ValidationError,
            )

    if status == "Rejected" and not clean_remarks:
        frappe.throw(
            "Review remarks are required when rejecting a payment.",
            frappe.ValidationError,
        )

    payment.status = status

    if payment_reference is not None:
        payment.payment_reference = (payment_reference or "").strip()

    if remarks is not None:
        payment.remarks = clean_remarks

    if status == "Paid":
        payment.paid_on = frappe.utils.now_datetime()
    elif status in {"Rejected", "Cancelled"}:
        payment.paid_on = None

    payment.save(ignore_permissions=True)
    if status in {"Paid", "Rejected", "Cancelled"}:
        review_routing.close_review_todos(
            PAYMENT_DOCTYPE,
            payment.name,
            cancelled=status == "Cancelled",
        )

    timeline_title = f"Payment {status}"
    timeline_description = (
        clean_remarks
        or f"{payment.payment_title or 'Payment'} marked as {status}."
    )
    mobile._create_service_timeline_entry(
        service_request=payment.service_request,
        event_type="Payment Updated",
        title=timeline_title,
        description=timeline_description,
        visible_to_customer=1,
    )

    case_transition_status = None

    if status == "Paid":
        if _set_case_status(service_case, "In Progress"):
            case_transition_status = "In Progress"
            mobile._create_service_timeline_entry(
                service_request=service_case.name,
                event_type="Status Updated",
                title="Work Started",
                description=(
                    "Payment has been confirmed and work on your "
                    "service request is now in progress."
                ),
                visible_to_customer=1,
            )
            if getattr(service_case, "assigned_staff", None):
                mobile._create_customer_notification(
                    recipient_user=service_case.assigned_staff,
                    title="Payment confirmed - start work",
                    message=(
                        f"Payment for {service_case.name} has been confirmed. "
                        "The request is ready for processing."
                    ),
                    notification_type="Payment",
                    reference_doctype="OMC Service Request",
                    reference_name=service_case.name,
                )

    elif status == "Rejected":
        if _set_case_status(service_case, "Waiting for Customer"):
            case_transition_status = "Waiting for Customer"
            mobile._create_service_timeline_entry(
                service_request=service_case.name,
                event_type="Status Updated",
                title="Waiting for Customer",
                description=(
                    "The payment receipt needs correction or replacement "
                    "before work can continue."
                ),
                visible_to_customer=1,
            )

    elif status == "Under Review":
        if _set_case_status(service_case, "Waiting for Payment"):
            case_transition_status = "Waiting for Payment"

    mobile._create_customer_notification(
        customer_profile=service_case.customer_profile,
        title=timeline_title,
        message=timeline_description,
        notification_type="Payment",
        reference_doctype=PAYMENT_DOCTYPE,
        reference_name=payment.name,
    )

    frappe.db.commit()

    return {
        "updated": True,
        "name": payment.name,
        "case_id": payment.service_request,
        "old_status": old_status,
        "status": payment.status,
        "paid_on": mobile._format_datetime(payment.paid_on),
        "receipt_url": payment.receipt_attachment or "",
        "payment_reference": payment.payment_reference or "",
        "remarks": payment.remarks or "",
        "case_status": service_case.status,
        "case_transition_status": case_transition_status,
        "message": "Payment receipt reviewed.",
    }
