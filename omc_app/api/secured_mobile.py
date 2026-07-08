"""Permission-guarded mobile API overrides.

These wrappers keep customer-facing mobile routes stable while enforcing
server-side capability checks for internal-only service case actions.
"""

import frappe

from omc_app.api import mobile


@frappe.whitelist()
def get_service_cases():
    """Return service case list with backend-owned tracking metadata.

    Accept common backend response wrappers so Flutter receives consistent
    list items even when the lower-level mobile API returns cases under
    ``cases``, ``results``, ``records``, or ``data``.
    """

    response = mobile.get_service_cases()
    cases = _extract_service_case_list(response)

    if not isinstance(cases, list):
        return response

    can_access_internal_workspace = mobile._can_access_internal_workspace()

    for service_case in cases:
        if not isinstance(service_case, dict):
            continue

        _normalize_service_case_list_item(service_case, can_access_internal_workspace)

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


def _normalize_service_case_list_item(service_case, can_access_internal_workspace=False):
    capabilities = mobile.get_mobile_capabilities()
    case_id = service_case.get("name") or service_case.get("id") or service_case.get("case_id") or ""
    status = service_case.get("status") or ""
    progress = _service_case_progress(status)

    service_case["id"] = case_id
    service_case["reference"] = case_id
    service_case["case_reference"] = case_id
    service_case["progress"] = progress
    service_case["progress_percent"] = int(progress * 100)
    service_case["current_stage"] = status
    service_case["next_step"] = _service_case_next_step(status)
    service_case.setdefault("required_documents_count", 0)
    service_case.setdefault("submitted_documents_count", 0)
    service_case.setdefault("missing_documents_count", 0)
    service_case["customer_action_required"] = status.strip().lower() == "waiting for customer"
    service_case["can_update_status"] = capabilities["can_update_service_status"]
    service_case["can_review_documents"] = capabilities["can_review_documents"]
    service_case["can_view_internal_notes"] = can_access_internal_workspace


@frappe.whitelist()
def get_service_case(case_id=None, name=None, service_request=None, request_id=None):
    """Return service case detail with backend-owned customer/admin gates.

    The mobile app should prefer real OMC Service Timeline rows. When a case has
    no timeline rows yet, return deterministic backend-generated stages instead
    of letting the Flutter client invent production tracking steps locally.
    """

    resolved_case_id = case_id or name or service_request or request_id
    response = mobile.get_service_case(case_id=resolved_case_id)
    service_case = response.get("case") if isinstance(response, dict) else None

    if not isinstance(service_case, dict):
        return response

    _apply_service_case_capabilities(service_case)
    _normalize_service_case_documents(service_case)

    timeline = service_case.get("timeline")
    if isinstance(timeline, list) and timeline:
        _normalize_service_case_timeline(timeline)
        return response

    service_case["timeline"] = _fallback_service_case_timeline(service_case)
    _normalize_service_case_timeline(service_case["timeline"])
    return response


def _apply_service_case_capabilities(service_case):
    """Keep internal-only fields and controls backend-driven."""

    can_access_internal_workspace = mobile._can_access_internal_workspace()
    capabilities = mobile.get_mobile_capabilities()

    service_case["can_update_status"] = capabilities["can_update_service_status"]
    service_case["can_review_documents"] = capabilities["can_review_documents"]
    service_case["can_view_internal_notes"] = can_access_internal_workspace

    if not can_access_internal_workspace:
        service_case["remarks"] = ""


def _normalize_service_case_documents(service_case):
    service_request = (
        service_case.get("name")
        or service_case.get("id")
        or service_case.get("case_id")
        or service_case.get("reference")
    )
    service_name = service_case.get("service_id") or service_case.get("service")

    documents = []
    required_document_templates = []

    if service_request:
        try:
            documents = mobile._get_service_documents(service_request)
        except Exception:
            documents = service_case.get("submitted_documents") or service_case.get("documents") or []

    if service_name:
        try:
            required_document_templates = mobile._service_required_documents(service_name)
        except Exception:
            required_document_templates = service_case.get("required_documents") or []

    if not documents and isinstance(service_case.get("submitted_documents"), list):
        documents = service_case.get("submitted_documents") or []

    if not required_document_templates and isinstance(service_case.get("required_documents"), list):
        required_document_templates = service_case.get("required_documents") or []

    document_details = _merged_document_details(documents, required_document_templates)
    if not document_details:
        return

    required_documents = document_details
    submitted_documents = [doc for doc in document_details if _document_is_submitted(doc)]
    missing_documents = [doc for doc in document_details if _document_needs_upload(doc)]

    service_case["required_documents"] = required_documents
    service_case["document_details"] = document_details
    service_case["required_document_details"] = document_details
    service_case["submitted_documents"] = submitted_documents
    service_case["missing_documents"] = missing_documents
    service_case["attachments"] = submitted_documents
    service_case["required_documents_count"] = len(required_documents)
    service_case["submitted_documents_count"] = len(submitted_documents)
    service_case["missing_documents_count"] = len(missing_documents)
    service_case["customer_action_required"] = bool(missing_documents) or (
        (service_case.get("status") or "").strip().lower() == "waiting for customer"
    )
    service_case["next_step"] = _service_case_next_step(
        service_case.get("status"),
        missing_documents,
    )


def _merged_document_details(documents, required_document_templates=None):
    """Return one row per required document with its current upload/review status."""

    merged = []
    seen_keys = set()
    uploaded_by_key = {}

    for document in documents or []:
        if not isinstance(document, dict):
            continue

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
        if uploaded:
            merged.append(_document_detail_from_uploaded(uploaded, template))
        else:
            merged.append(_document_detail_from_template(template))

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
    template = template or {}
    title = document.get("title") or document.get("document_title") or template.get("title") or template.get("document_title") or ""
    doc_type = document.get("type") or document.get("document_type") or template.get("type") or template.get("document_type") or ""
    status = document.get("status") or "Uploaded"
    status_normalized = status.strip().lower()
    attachment = document.get("file_url") or document.get("attachment") or ""

    if status_normalized == "rejected":
        # Rejected documents must show their review status but remain available
        # in the customer upload modal for replacement.
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


def _document_is_submitted(document):
    status = (document.get("status") or "").strip().lower()
    has_file = bool(document.get("file_url") or document.get("attachment"))

    if status in {"rejected", "pending", "missing", "required", "expired"}:
        return False

    return has_file or status in {"uploaded", "approved", "submitted", "accepted", "verified", "under review"}


def _document_needs_upload(document):
    status = (document.get("status") or "").strip().lower()
    has_file = bool(document.get("file_url") or document.get("attachment"))

    if status in {"pending", "missing", "required", "rejected", "expired"}:
        return True

    return not has_file


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
        if "." in text:
            text = text.split(".", 1)[0]
        return text


def _service_case_progress(status):
    normalized = (status or "").strip().lower()
    mapping = {
        "open": 0.10,
        "waiting for customer": 0.35,
        "in progress": 0.60,
        "under review": 0.80,
        "completed": 1.00,
        "cancelled": 0.00,
    }
    return mapping.get(normalized, 0.10)


def _service_case_next_step(status, missing_documents=None):
    if missing_documents:
        return "Please upload the missing required document(s)."

    normalized = (status or "").strip().lower()
    if normalized == "open":
        return "OMC team will review your request shortly."
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
        {
            "title": "Request received",
            "subtitle": created_on or "Your request has been received by OMC.",
            "is_done": progress >= 0.05 or bool(created_on),
        },
        {
            "title": "Documents review",
            "subtitle": _documents_stage_subtitle(service_case, normalized_status),
            "is_done": progress >= 0.35,
        },
        {
            "title": "OMC processing",
            "subtitle": next_step,
            "is_done": progress >= 0.65,
        },
    ]

    if expected_completion:
        stages.append(
            {
                "title": "Expected completion",
                "subtitle": expected_completion,
                "is_done": normalized_status == "completed",
            }
        )

    stages.append(
        {
            "title": "Completed",
            "subtitle": "Service completed." if normalized_status == "completed" else "Pending completion.",
            "is_done": normalized_status == "completed" or progress >= 1,
        }
    )

    return stages


def _documents_stage_subtitle(service_case, normalized_status):
    missing_count = _int_number(service_case.get("missing_documents_count"))
    submitted_count = _int_number(service_case.get("submitted_documents_count"))

    if missing_count > 0:
        return f"{missing_count} document(s) still needed."

    if submitted_count > 0:
        return f"{submitted_count} document(s) submitted for review."

    if normalized_status == "waiting for customer":
        return "OMC is waiting for customer input."

    return "OMC will confirm document requirements."


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


@frappe.whitelist()
def update_service_case_status(
    case_id=None,
    name=None,
    service_request=None,
    request_id=None,
    status=None,
    note=None,
    expected_completion_date=None,
):
    """Allow only internal workspace users to update service case status."""

    mobile.require_omc_staff(
        mobile.SERVICE_STATUS_ROLES,
        "You do not have permission to update service case status.",
    )

    resolved_case_id = case_id or name or service_request or request_id

    return mobile.update_service_case_status(
        case_id=resolved_case_id,
        status=status,
        note=note,
        expected_completion_date=expected_completion_date,
    )


@frappe.whitelist()
def update_service_document_status(
    document_id=None,
    document=None,
    name=None,
    status=None,
    remarks=None,
):
    """Allow only internal workspace users to approve/reject documents."""

    mobile.require_omc_staff(
        mobile.DOCUMENT_REVIEW_ROLES,
        "You do not have permission to review service documents.",
    )

    resolved_document_id = document_id or document or name

    return mobile.update_service_document_status(
        document_id=resolved_document_id,
        status=status,
        remarks=remarks,
    )
