"""Permission-guarded mobile API overrides.

These wrappers keep customer-facing mobile routes stable while enforcing
server-side capability checks for internal-only service case actions.
"""

import frappe

from omc_app.api import mobile


@frappe.whitelist()
def get_service_cases():
    """Return service case list with the same tracking summary used by detail."""

    response = mobile.get_service_cases()
    cases = _extract_service_case_list(response)
    if not isinstance(cases, list):
        return response

    can_access_internal_workspace = mobile._can_access_internal_workspace()
    for service_case in cases:
        if isinstance(service_case, dict):
            _normalize_service_case(service_case, can_access_internal_workspace)

    return response


@frappe.whitelist()
def get_service_case(case_id=None, name=None, service_request=None, request_id=None):
    """Return service case detail with backend-owned customer/admin gates."""

    resolved_case_id = case_id or name or service_request or request_id
    response = mobile.get_service_case(case_id=resolved_case_id)
    service_case = response.get("case") if isinstance(response, dict) else None
    if not isinstance(service_case, dict):
        return response

    _normalize_service_case(service_case)

    timeline = service_case.get("timeline")
    if isinstance(timeline, list) and timeline:
        _normalize_service_case_timeline(timeline)
        return response

    service_case["timeline"] = _fallback_service_case_timeline(service_case)
    _normalize_service_case_timeline(service_case["timeline"])
    return response


def _extract_service_case_list(response):
    if not isinstance(response, dict):
        return None

    for key in ("cases", "results", "records", "data"):
        value = response.get(key)
        if isinstance(value, list):
            return value

    message = response.get("message")
    if isinstance(message, dict):
        for key in ("cases", "results", "records", "data"):
            value = message.get(key)
            if isinstance(value, list):
                return value

    return None



def _service_request_id(service_case):
    """Resolve a stable OMC Service Request id from mobile case payloads."""
    if not isinstance(service_case, dict):
        return ""

    for key in (
        "name",
        "id",
        "reference",
        "case_reference",
        "case_id",
        "service_request",
        "request_id",
    ):
        value = service_case.get(key)
        if value:
            return str(value).strip()

    return ""


def _normalize_service_case(service_case, can_access_internal_workspace=None):
    _hydrate_service_case(service_case)
    _apply_service_case_capabilities(service_case, can_access_internal_workspace)
    _normalize_service_case_documents(service_case)
    _normalize_service_case_payments(service_case)
    _apply_service_case_tracking_summary(service_case)


def _hydrate_service_case(service_case):
    case_id = _service_request_id(service_case)
    if not case_id or not frappe.db.exists("OMC Service Request", case_id):
        return

    try:
        request = frappe.get_doc("OMC Service Request", case_id)
    except Exception:
        return

    service_case["name"] = request.name
    service_case["id"] = request.name
    service_case["reference"] = request.name
    service_case["case_reference"] = request.name
    service_case["title"] = request.title or getattr(request, "service_title", None) or service_case.get("title") or "Service Request"
    service_case["status"] = request.status or service_case.get("status") or ""
    service_case["priority"] = request.priority or service_case.get("priority") or ""
    service_case["service_id"] = request.service or service_case.get("service_id") or ""
    service_case["service"] = request.service or service_case.get("service") or ""
    service_case["service_title"] = getattr(request, "service_title", None) or service_case.get("service_title") or ""
    service_case["description"] = request.description or service_case.get("description") or ""
    service_case["created_at"] = _format_mobile_date(request.creation) or service_case.get("created_at") or ""
    service_case["submitted_on"] = _format_mobile_datetime(getattr(request, "submitted_on", None) or request.creation) or service_case.get("submitted_on") or ""
    service_case["updated_at"] = _format_mobile_date(request.modified) or service_case.get("updated_at") or ""
    service_case["expected_completion_date"] = str(getattr(request, "expected_completion_date", None) or service_case.get("expected_completion_date") or "")
    customer_profile_name = getattr(request, "customer_profile", None) or ""
    service_case["customer_profile"] = customer_profile_name
    service_case["customer_name"] = getattr(request, "customer_name", None) or service_case.get("customer_name") or ""
    service_case["contact_email"] = getattr(request, "contact_email", None) or service_case.get("contact_email") or ""
    service_case["contact_phone"] = getattr(request, "contact_phone", None) or service_case.get("contact_phone") or ""
    service_case["requested_by"] = getattr(request, "requested_by", None) or service_case.get("requested_by") or ""

    if customer_profile_name and frappe.db.exists("OMC Customer Profile", customer_profile_name):
        try:
            profile = frappe.get_doc("OMC Customer Profile", customer_profile_name)
            service_case["customer_name"] = service_case["customer_name"] or profile.full_name or ""
            service_case["contact_email"] = service_case["contact_email"] or profile.email or ""
            service_case["contact_phone"] = service_case["contact_phone"] or profile.phone or profile.get("whatsapp_no") or ""
            service_case["ntn"] = profile.get("ntn") or ""
            service_case["cnic"] = profile.get("cnic") or ""
            service_case["company_name"] = profile.get("company_name") or ""
            service_case["customer_type"] = profile.get("customer_type") or ""
        except Exception:
            pass


def _apply_service_case_capabilities(service_case, can_access_internal_workspace=None):
    if can_access_internal_workspace is None:
        can_access_internal_workspace = mobile._can_access_internal_workspace()

    capabilities = mobile.get_mobile_capabilities()
    case_id = _service_request_id(service_case)

    service_case["id"] = case_id
    service_case["reference"] = case_id
    service_case["case_reference"] = case_id
    service_case["current_stage"] = service_case.get("status") or ""
    service_case["can_update_status"] = capabilities["can_update_service_status"]
    service_case["can_review_documents"] = capabilities["can_review_documents"]
    service_case["can_review_payments"] = capabilities.get("can_review_payments", False)
    service_case["can_view_internal_notes"] = can_access_internal_workspace
    service_case["can_cancel"] = _can_customer_cancel_service_case(case_id, service_case.get("status"))

    if not can_access_internal_workspace:
        service_case["remarks"] = ""


def _normalize_service_case_documents(service_case):
    service_request = _service_request_id(service_case)
    service_name = service_case.get("service_id") or service_case.get("service")

    try:
        documents = mobile._get_service_documents(service_request) if service_request else []
    except Exception:
        documents = service_case.get("submitted_documents") or service_case.get("documents") or []

    try:
        required_document_templates = mobile._service_required_documents(service_name) if service_name else []
    except Exception:
        required_document_templates = service_case.get("required_documents") or []

    document_details = _merged_document_details(documents, required_document_templates)
    submitted_documents = [doc for doc in document_details if _document_is_submitted(doc)]
    missing_documents = [doc for doc in document_details if _document_needs_upload(doc)]
    approved_documents = [doc for doc in document_details if _document_is_approved(doc)]
    rejected_documents = [doc for doc in document_details if _document_is_rejected(doc)]

    service_case["required_documents"] = document_details
    service_case["document_details"] = document_details
    service_case["required_document_details"] = document_details
    service_case["submitted_documents"] = submitted_documents
    service_case["missing_documents"] = missing_documents
    service_case["attachments"] = submitted_documents
    service_case["required_documents_count"] = len(document_details)
    service_case["submitted_documents_count"] = len(submitted_documents)
    service_case["missing_documents_count"] = len(missing_documents)
    service_case["approved_documents_count"] = len(approved_documents)
    service_case["rejected_documents_count"] = len(rejected_documents)


def _normalize_service_case_payments(service_case):
    service_request = _service_request_id(service_case)
    if not service_request:
        service_case.update(_empty_payment_summary())
        return

    try:
        payments = frappe.get_all(
            "OMC Service Payment",
            filters={"service_request": service_request, "visible_to_customer": 1},
            fields=[
                "name",
                "service_request",
                "payment_title",
                "amount",
                "currency",
                "status",
                "due_date",
                "paid_on",
                "payment_reference",
                "receipt_attachment",
                "remarks",
            ],
            order_by="due_date asc, creation asc",
        )
    except Exception:
        frappe.log_error(frappe.get_traceback(), "Service payment tracking lookup failed")
        payments = []

    payment_details = [_payment_detail(row) for row in payments]
    active_payments = [payment for payment in payment_details if not _payment_is_cancelled(payment)]
    paid_payments = [payment for payment in active_payments if _payment_is_paid(payment)]
    rejected_payments = [payment for payment in active_payments if _payment_is_rejected(payment)]
    open_payments = [payment for payment in active_payments if not _payment_is_paid(payment)]

    service_case["payments"] = payment_details
    service_case["payment_details"] = payment_details
    service_case["payments_count"] = len(active_payments)
    service_case["paid_payments_count"] = len(paid_payments)
    service_case["open_payments_count"] = len(open_payments)
    service_case["rejected_payments_count"] = len(rejected_payments)


def _empty_payment_summary():
    return {
        "payments": [],
        "payment_details": [],
        "payments_count": 0,
        "paid_payments_count": 0,
        "open_payments_count": 0,
        "rejected_payments_count": 0,
    }


def _apply_service_case_tracking_summary(service_case):
    status = (service_case.get("status") or "").strip()
    normalized_status = status.lower()
    missing_documents = service_case.get("missing_documents") or []
    rejected_documents_count = _int_number(service_case.get("rejected_documents_count"))
    open_payments_count = _int_number(service_case.get("open_payments_count"))
    rejected_payments_count = _int_number(service_case.get("rejected_payments_count"))

    customer_action_required = bool(missing_documents) or rejected_documents_count > 0 or rejected_payments_count > 0
    if normalized_status in {"waiting for documents", "waiting for customer", "waiting for payment"}:
        customer_action_required = True

    progress = _weighted_service_case_progress(service_case)
    service_case["customer_action_required"] = customer_action_required
    service_case["current_stage"] = status
    service_case["next_step"] = _service_case_next_step(
        status,
        missing_documents=missing_documents,
        rejected_documents_count=rejected_documents_count,
        open_payments_count=open_payments_count,
        rejected_payments_count=rejected_payments_count,
    )
    service_case["progress"] = progress
    service_case["progress_percent"] = int(round(progress * 100))


def _merged_document_details(documents, required_document_templates=None):
    merged = []
    seen_keys = set()
    uploaded_by_key = {}

    for document in documents or []:
        if isinstance(document, dict):
            key = _document_key(document)
            if key:
                uploaded_by_key[key] = document

    for template in required_document_templates or []:
        if not isinstance(template, dict):
            continue
        key = _document_key(template)
        if not key:
            continue
        uploaded = uploaded_by_key.get(key)
        merged.append(_document_detail_from_uploaded(uploaded, template) if uploaded else _document_detail_from_template(template))
        seen_keys.add(key)

    for document in documents or []:
        if not isinstance(document, dict):
            continue
        key = _document_key(document)
        if key and key in seen_keys:
            continue
        merged.append(_document_detail_from_uploaded(document, None))

    return merged


def _document_key(item):
    title = (item.get("title") or item.get("document_title") or "").strip().lower()
    doc_type = (item.get("type") or item.get("document_type") or "").strip().lower()
    return title or doc_type


def _document_detail_from_template(template):
    title = template.get("title") or template.get("document_title") or ""
    doc_type = template.get("type") or template.get("document_type") or ""
    return {
        "name": "-",
        "id": "-",
        "title": title,
        "document_title": title,
        "type": doc_type,
        "document_type": doc_type,
        "file_url": "",
        "attachment": "",
        "status": "Pending",
        "remarks": template.get("instructions") or "",
        "uploaded_at": "",
        "uploaded_by": "",
        "is_required": template.get("is_required", 1),
    }


def _document_detail_from_uploaded(document, template=None):
    document = document or {}
    template = template or {}
    title = document.get("title") or document.get("document_title") or template.get("title") or template.get("document_title") or ""
    doc_type = document.get("type") or document.get("document_type") or template.get("type") or template.get("document_type") or ""
    status = document.get("status") or "Uploaded"
    attachment = document.get("file_url") or document.get("attachment") or ""
    if status.strip().lower() == "rejected":
        attachment = ""

    return {
        "name": document.get("name") or document.get("id") or "",
        "id": document.get("name") or document.get("id") or "",
        "title": title,
        "document_title": title,
        "type": doc_type,
        "document_type": doc_type,
        "file_url": attachment,
        "attachment": attachment,
        "status": status,
        "remarks": document.get("remarks") or "",
        "uploaded_at": _format_mobile_datetime(document.get("uploaded_at") or document.get("uploaded_on")),
        "uploaded_by": document.get("uploaded_by") or "",
        "is_required": template.get("is_required", 0),
    }


def _payment_detail(payment):
    return {
        "name": payment.name,
        "id": payment.name,
        "case_id": payment.service_request,
        "title": payment.payment_title or "Payment",
        "amount": payment.amount or 0,
        "currency": payment.currency or "PKR",
        "status": payment.status or "Open",
        "due_date": _format_mobile_datetime(payment.due_date),
        "paid_on": _format_mobile_datetime(payment.paid_on),
        "payment_reference": payment.payment_reference or "",
        "receipt_url": payment.receipt_attachment or "",
        "receipt_attachment": payment.receipt_attachment or "",
        "remarks": payment.remarks or "",
    }


def _document_is_submitted(document):
    status = (document.get("status") or "").strip().lower()
    has_file = bool(document.get("file_url") or document.get("attachment"))
    if status in {"rejected", "pending", "missing", "required", "expired"}:
        return False
    return has_file or status in {"uploaded", "approved", "submitted", "accepted", "verified", "under review"}


def _document_needs_upload(document):
    status = (document.get("status") or "").strip().lower()
    has_file = bool(document.get("file_url") or document.get("attachment"))
    return status in {"pending", "missing", "required", "rejected", "expired"} or not has_file


def _document_is_approved(document):
    return (document.get("status") or "").strip().lower() in {"approved", "accepted", "verified"}


def _document_is_rejected(document):
    return (document.get("status") or "").strip().lower() == "rejected"


def _payment_is_paid(payment):
    return (payment.get("status") or "").strip().lower() in {"paid", "approved", "payment approved"}


def _payment_is_rejected(payment):
    return (payment.get("status") or "").strip().lower() == "rejected"


def _payment_is_cancelled(payment):
    return (payment.get("status") or "").strip().lower() == "cancelled"


def _normalize_service_case_timeline(timeline):
    for entry in timeline or []:
        if not isinstance(entry, dict):
            continue
        for key in ("created_at", "created_on", "creation", "date", "updated_at", "modified", "event_time"):
            value = entry.get(key)
            if value:
                entry[key] = _format_mobile_datetime(value)


def _format_mobile_datetime(value):
    if not value:
        return ""
    try:
        return frappe.utils.format_datetime(value, "dd MMM yyyy, h:mm a")
    except Exception:
        text = str(value).strip()
        return text.split(".", 1)[0] if "." in text else text


def _format_mobile_date(value):
    if not value:
        return ""
    try:
        return str(value.date())
    except Exception:
        text = str(value).strip()
        return text.split(" ", 1)[0] if " " in text else text


def _service_case_progress(status):
    normalized = (status or "").strip().lower()
    mapping = {
        "open": 0.10,
        "waiting for documents": 0.10,
        "documents under review": 0.25,
        "waiting for payment": 0.45,
        "payment under review": 0.55,
        "waiting for customer": 0.35,
        "in progress": 0.75,
        "under review": 0.80,
        "completed": 1.00,
        "closed": 1.00,
        "cancelled": 0.00,
    }
    return mapping.get(normalized, 0.10)


def _weighted_service_case_progress(service_case):
    status = (service_case.get("status") or "").strip().lower()
    if status == "cancelled":
        return 0.0
    if status in {"completed", "closed"}:
        return 1.0

    required_documents_count = _int_number(service_case.get("required_documents_count"))
    approved_documents_count = _int_number(service_case.get("approved_documents_count"))
    payments_count = _int_number(service_case.get("payments_count"))
    paid_payments_count = _int_number(service_case.get("paid_payments_count"))

    document_ratio = min(1.0, approved_documents_count / required_documents_count) if required_documents_count > 0 else (1.0 if status in {"waiting for payment", "payment under review", "in progress", "completed", "closed"} else 0.0)
    payment_ratio = min(1.0, paid_payments_count / payments_count) if payments_count > 0 else (1.0 if status in {"in progress", "completed", "closed"} else 0.0)

    internal_stage_ratio = 0.0
    if status == "documents under review":
        internal_stage_ratio = 0.20
    elif status == "payment under review":
        internal_stage_ratio = 0.35
    elif status == "in progress":
        internal_stage_ratio = 0.75

    completed_bonus = 10 if status in {"completed", "closed"} else 0
    percent = 10 + (document_ratio * 35) + (payment_ratio * 25) + (internal_stage_ratio * 20) + completed_bonus
    return max(0.0, min(1.0, percent / 100))


def _service_case_next_step(status, missing_documents=None, rejected_documents_count=0, open_payments_count=0, rejected_payments_count=0):
    if rejected_documents_count:
        return "A document was rejected. Please upload the corrected document again."
    if missing_documents:
        return "Please upload the missing required document(s)."
    if rejected_payments_count:
        return "A payment receipt was rejected. Please upload the corrected receipt again."
    if open_payments_count:
        return "Please complete the pending payment or submit its receipt."

    normalized = (status or "").strip().lower()
    if normalized == "open":
        return "OMC team will review your request shortly."
    if normalized == "waiting for documents":
        return "Please upload the required document(s)."
    if normalized == "documents under review":
        return "Your documents are under OMC review."
    if normalized == "waiting for payment":
        return "Please complete the pending payment."
    if normalized == "payment under review":
        return "Your payment receipt is under OMC review."
    if normalized == "waiting for customer":
        return "OMC is waiting for your response or required documents."
    if normalized == "in progress":
        return "OMC team is working on your service request."
    if normalized == "under review":
        return "Your request is under final review."
    if normalized == "completed":
        return "Your service request has been completed."
    if normalized == "cancelled":
        return "This service request has been cancelled."
    return "OMC team will update this service request shortly."


def _fallback_service_case_timeline(service_case):
    status = (service_case.get("status") or "").strip()
    normalized_status = status.lower()
    progress = _progress_number(service_case.get("progress"))
    created_on = service_case.get("submitted_on") or service_case.get("created_at") or ""
    expected_completion = service_case.get("expected_completion_date") or ""
    next_step = service_case.get("next_step") or "OMC team will update this service request shortly."

    stages = [
        {"title": "Request received", "subtitle": created_on or "Your request has been received by OMC.", "is_done": progress >= 0.05 or bool(created_on)},
        {"title": "Documents review", "subtitle": _documents_stage_subtitle(service_case, normalized_status), "is_done": progress >= 0.35},
        {"title": "Payment review", "subtitle": _payments_stage_subtitle(service_case, normalized_status), "is_done": progress >= 0.60},
        {"title": "OMC processing", "subtitle": next_step, "is_done": progress >= 0.75},
    ]

    if expected_completion:
        stages.append({"title": "Expected completion", "subtitle": expected_completion, "is_done": normalized_status == "completed"})

    stages.append({"title": "Completed", "subtitle": "Service completed." if normalized_status == "completed" else "Pending completion.", "is_done": normalized_status == "completed" or progress >= 1})
    return stages


def _documents_stage_subtitle(service_case, normalized_status):
    missing_count = _int_number(service_case.get("missing_documents_count"))
    approved_count = _int_number(service_case.get("approved_documents_count"))
    required_count = _int_number(service_case.get("required_documents_count"))
    if missing_count > 0:
        return f"{missing_count} document(s) still needed."
    if required_count > 0:
        return f"{approved_count}/{required_count} document(s) approved."
    if normalized_status == "waiting for customer":
        return "OMC is waiting for customer input."
    return "OMC will confirm document requirements."


def _payments_stage_subtitle(service_case, normalized_status):
    payments_count = _int_number(service_case.get("payments_count"))
    paid_count = _int_number(service_case.get("paid_payments_count"))
    rejected_count = _int_number(service_case.get("rejected_payments_count"))
    if rejected_count > 0:
        return f"{rejected_count} payment receipt(s) need correction."
    if payments_count > 0:
        return f"{paid_count}/{payments_count} payment(s) approved."
    if normalized_status == "waiting for payment":
        return "Payment is pending."
    return "No payment has been opened yet."


def _progress_number(value):
    try:
        number = float(value or 0)
    except (TypeError, ValueError):
        return 0.0
    if number > 1:
        number = number / 100
    return max(0.0, min(1.0, number))


def _int_number(value):
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0


def _can_customer_cancel_service_case(case_id, status=None):
    if not case_id:
        return False
    normalized_status = (status or "").strip().lower()
    if normalized_status not in {"open", "waiting for customer", "waiting for documents"}:
        return False
    if frappe.db.exists("OMC Service Document", {"service_request": case_id, "attachment": ["!=", ""]}):
        return False
    if frappe.db.exists("OMC Service Payment", {"service_request": case_id}):
        return False
    return True


@frappe.whitelist()
def cancel_service_request(case_id=None, name=None, service_request=None, request_id=None, reason=None):
    resolved_case_id = case_id or name or service_request or request_id
    if not resolved_case_id:
        frappe.throw("Service request reference is required.")

    request = frappe.get_doc("OMC Service Request", resolved_case_id)
    user = frappe.session.user
    can_access_internal_workspace = mobile._can_access_internal_workspace()
    customer_profile = None if can_access_internal_workspace else mobile.get_current_customer_profile()
    owns_request = bool(customer_profile and getattr(request, "customer_profile", None) == customer_profile.name)

    if user != "Administrator" and not owns_request and not can_access_internal_workspace:
        frappe.throw("You cannot cancel this service request.")

    if not _can_customer_cancel_service_case(request.name, request.status):
        frappe.throw("This request can no longer be cancelled from the app. Please contact OMC support.")

    request.status = "Cancelled"
    request.closed_on = frappe.utils.now_datetime()
    request.add_comment("Comment", reason or "Service request cancelled by customer from mobile app.")
    request.save(ignore_permissions=True)
    frappe.db.commit()

    return {"service_request": request.name, "status": request.status, "message": "Service request cancelled successfully.", "can_cancel": False}


@frappe.whitelist()
def update_service_case_status(case_id=None, name=None, service_request=None, request_id=None, status=None, note=None, expected_completion_date=None):
    """Allow only internal workspace users to update service case status."""

    mobile.require_omc_staff(mobile.SERVICE_STATUS_ROLES, "You do not have permission to update service case status.")
    resolved_case_id = case_id or name or service_request or request_id
    return mobile.update_service_case_status(case_id=resolved_case_id, status=status, note=note, expected_completion_date=expected_completion_date)


@frappe.whitelist()
def update_service_document_status(document_id=None, document=None, name=None, status=None, remarks=None):
    """Allow only internal workspace users to approve/reject documents."""

    mobile.require_omc_staff(mobile.DOCUMENT_REVIEW_ROLES, "You do not have permission to review service documents.")
    resolved_document_id = document_id or document or name
    return mobile.update_service_document_status(document_id=resolved_document_id, status=status, remarks=remarks)
