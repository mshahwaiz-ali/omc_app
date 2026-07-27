"""Internal mobile workspace APIs for staff service-case handling.

These endpoints keep customer screens isolated while giving OMC staff a case-first
review queue. They intentionally use OMC Service Request as the root object and
OMC Service Document as the child review object.
"""

import frappe

from omc_app.api import access, assisted_service, mobile


def _capabilities():
    return access.get_mobile_capabilities()


def _assigned_case_names(user=None):
    user = user or frappe.session.user
    if not user or user == "Guest":
        return []
    return frappe.get_all(
        "ToDo",
        filters={
            "reference_type": "OMC Service Request",
            "allocated_to": user,
            "status": ["!=", "Cancelled"],
        },
        pluck="reference_name",
    )


SERVICE_CASE_FIELDS = [
    "name",
    "title",
    "status",
    "priority",
    "service",
    "service_title",
    "customer_profile",
    "customer_mode",
    "submission_mode",
    "created_on_behalf",
    "submitted_by_internal_user",
    "referral_owner",
    "customer_name",
    "contact_email",
    "contact_phone",
    "description",
    "creation",
    "modified",
    "expected_completion_date",
]


@frappe.whitelist()
def get_service_cases(
    search=None,
    customer=None,
    case_id=None,
    status=None,
    service=None,
    document_status=None,
    limit_start=0,
    limit_page_length=100,
):
    """Return a staff-safe service-case queue with document summaries."""

    user = mobile._assert_internal_workspace_access()
    capabilities = _capabilities()
    if not any(
        capabilities.get(name)
        for name in (
            "can_view_all_service_cases",
            "can_view_relevant_service_cases",
            "can_view_assigned_service_cases",
        )
    ):
        frappe.throw(
            "You do not have permission to view internal service cases.",
            frappe.PermissionError,
        )

    filters = {}
    if not capabilities.get("can_view_all_service_cases"):
        assigned_names = _assigned_case_names(user)
        if not assigned_names:
            return {
                "cases": [],
                "summary": _queue_summary([]),
                "capabilities": capabilities,
            }
        filters["name"] = ["in", assigned_names]
    if case_id:
        filters["name"] = case_id
    if status:
        filters["status"] = status
    if service:
        filters["service"] = service
    if customer:
        filters["customer_profile"] = customer

    rows = frappe.get_all(
        "OMC Service Request",
        filters=filters,
        fields=SERVICE_CASE_FIELDS,
        order_by="modified desc",
        limit_start=_int_value(limit_start),
        limit_page_length=min(max(_int_value(limit_page_length) or 100, 1), 200),
    )

    cases = [_case_to_queue_item(row) for row in rows]
    cases = _filter_cases(cases, search=search, document_status=document_status)

    return {
        "cases": cases,
        "summary": _queue_summary(cases),
        "capabilities": capabilities,
    }


@frappe.whitelist()
def create_service_request_for_customer(**kwargs):
    """Create an assisted service request using the canonical authority."""
    if not kwargs.get("customer_mode"):
        kwargs["customer_mode"] = "Existing Customer"
    return assisted_service.create_request(**kwargs)


def _case_to_queue_item(row):
    capabilities = _capabilities()
    case_id = row.name
    docs = _service_documents(case_id)
    required_templates = mobile._service_required_documents(row.service)
    doc_summary = _document_summary(docs, required_templates)

    return {
        "name": case_id,
        "id": case_id,
        "reference": case_id,
        "case_id": case_id,
        "title": row.title or row.service_title or "Service Request",
        "service": row.service or "",
        "service_title": row.service_title or "",
        "status": row.status or "",
        "priority": row.priority or "",
        "customer_profile": row.customer_profile or "",
        "customer_mode": row.customer_mode or "",
        "submission_mode": row.submission_mode or "",
        "created_on_behalf": int(row.created_on_behalf or 0),
        "submitted_by_internal_user": row.submitted_by_internal_user or "",
        "referral_owner": row.referral_owner or "",
        "customer_name": row.customer_name or _customer_name(row.customer_profile),
        "contact_email": row.contact_email or "",
        "contact_phone": row.contact_phone or "",
        "description": row.description or "",
        "created_at": _format_datetime(row.creation),
        "updated_at": _format_datetime(row.modified),
        "expected_completion_date": str(row.expected_completion_date) if row.expected_completion_date else "",
        "required_documents_count": doc_summary["required"],
        "submitted_documents_count": doc_summary["uploaded"] + doc_summary["approved"],
        "missing_documents_count": doc_summary["pending"] + doc_summary["rejected"],
        "document_summary": doc_summary,
        "document_summary_label": _document_summary_label(doc_summary),
        "can_review_documents": bool(
            capabilities.get("can_review_documents")
        ),
        "can_update_status": bool(
            capabilities.get("can_update_service_status")
            or capabilities.get("can_update_assigned_service_status")
        ),
    }


def _service_documents(service_request):
    return frappe.get_all(
        "OMC Service Document",
        filters={"service_request": service_request, "visible_to_customer": 1},
        fields=["name", "document_title", "document_type", "status", "attachment", "uploaded_on"],
        order_by="uploaded_on asc, creation asc",
    )


def _document_summary(documents, required_templates):
    counts = {"pending": 0, "uploaded": 0, "approved": 0, "rejected": 0, "other": 0, "required": 0, "total": 0}
    required_keys = {_document_key(item) for item in required_templates or [] if _document_key(item)}
    uploaded_keys = set()

    counts["required"] = len(required_keys)

    for document in documents or []:
        key = _document_key(document)
        if key:
            uploaded_keys.add(key)
        status = (document.status or "Uploaded").strip().lower()
        if status == "approved":
            counts["approved"] += 1
        elif status == "rejected":
            counts["rejected"] += 1
        elif status == "uploaded":
            counts["uploaded"] += 1
        elif status in {"pending", "missing", "required"}:
            counts["pending"] += 1
        else:
            counts["other"] += 1

    missing_required = required_keys - uploaded_keys
    counts["pending"] += len(missing_required)
    counts["total"] = counts["pending"] + counts["uploaded"] + counts["approved"] + counts["rejected"] + counts["other"]
    return counts


def _document_key(item):
    title = (item.get("document_title") or item.get("title") or "").strip().lower()
    doc_type = (item.get("document_type") or item.get("type") or "").strip().lower()
    return title or doc_type


def _document_summary_label(summary):
    parts = []
    labels = [
        ("uploaded", "Uploaded"),
        ("pending", "Pending"),
        ("approved", "Approved"),
        ("rejected", "Rejected"),
    ]
    for key, label in labels:
        value = int(summary.get(key) or 0)
        if value:
            parts.append(f"{value} {label}")
    return ", ".join(parts) if parts else "No documents yet"


def _filter_cases(cases, search=None, document_status=None):
    search_text = (search or "").strip().lower()
    document_filter = (document_status or "").strip().lower()

    filtered = []
    for item in cases:
        if search_text:
            haystack = " ".join(
                [
                    item.get("name") or "",
                    item.get("customer_name") or "",
                    item.get("customer_profile") or "",
                    item.get("service_title") or "",
                    item.get("status") or "",
                ]
            ).lower()
            if search_text not in haystack:
                continue

        if document_filter:
            summary = item.get("document_summary") or {}
            if int(summary.get(document_filter) or 0) <= 0:
                continue

        filtered.append(item)

    return filtered


def _queue_summary(cases):
    summary = {
        "total": len(cases),
        "open": 0,
        "waiting_for_customer": 0,
        "in_progress": 0,
        "completed": 0,
        "pending_documents": 0,
        "uploaded_documents": 0,
    }
    for item in cases:
        status = (item.get("status") or "").strip().lower()
        if status == "open":
            summary["open"] += 1
        elif status == "waiting for customer":
            summary["waiting_for_customer"] += 1
        elif status == "in progress":
            summary["in_progress"] += 1
        elif status == "completed":
            summary["completed"] += 1
        doc_summary = item.get("document_summary") or {}
        summary["pending_documents"] += int(doc_summary.get("pending") or 0)
        summary["uploaded_documents"] += int(doc_summary.get("uploaded") or 0)
    return summary


def _customer_name(customer_profile):
    if not customer_profile:
        return ""
    return frappe.db.get_value("OMC Customer Profile", customer_profile, "full_name") or ""


def _format_datetime(value):
    if not value:
        return ""

    try:
        return frappe.utils.format_datetime(value, "dd MMM yyyy, h:mm a")
    except Exception:
        text = str(value).strip()
        if "." in text:
            text = text.split(".", 1)[0]
        return text


def _int_value(value):
    try:
        return int(value or 0)
    except Exception:
        return 0
