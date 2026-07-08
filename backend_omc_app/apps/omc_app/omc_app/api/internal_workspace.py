"""Internal mobile workspace APIs for staff service-case handling.

These endpoints keep customer screens isolated while giving OMC staff a case-first
review queue. They intentionally use OMC Service Request as the root object and
OMC Service Document as the child review object.
"""

import frappe

from omc_app.api import mobile


SERVICE_CASE_FIELDS = [
    "name",
    "title",
    "status",
    "priority",
    "service",
    "service_title",
    "customer_profile",
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

    mobile._assert_internal_workspace_access()

    filters = {}
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
        "capabilities": mobile.get_mobile_capabilities(),
    }


@frappe.whitelist()
def create_service_request_for_customer(**kwargs):
    """Create an OMC Service Request on behalf of a customer/profile.

    This is internal-only and does not bypass backend permission checks for who
    may create staff records. Customer users still use mobile.create_service.
    """

    mobile.require_omc_staff(
        mobile.SYSTEM_OVERRIDE_ROLES | mobile.OMC_ADMIN_ROLES | mobile.OMC_SUPPORT_ROLES,
        "You do not have permission to create service requests for customers.",
    )

    customer_profile = (kwargs.get("customer_profile") or kwargs.get("customer_id") or "").strip()
    service_id = (kwargs.get("service_id") or kwargs.get("service") or "").strip()

    if not customer_profile:
        frappe.throw("customer_profile is required")
    if not frappe.db.exists("OMC Customer Profile", customer_profile):
        frappe.throw("Customer profile not found", frappe.DoesNotExistError)
    if not service_id:
        frappe.throw("service_id is required")

    service_name = frappe.db.get_value("OMC Service", {"service_id": service_id}, "name") or service_id
    if not frappe.db.exists("OMC Service", service_name):
        frappe.throw("Service not found", frappe.DoesNotExistError)

    profile = frappe.get_doc("OMC Customer Profile", customer_profile)
    service_doc = frappe.get_doc("OMC Service", service_name)

    doc = frappe.new_doc("OMC Service Request")
    doc.service = service_name
    doc.service_title = service_doc.title or ""
    doc.title = (kwargs.get("title") or service_doc.title or "Service Request").strip()
    doc.description = kwargs.get("description") or ""
    doc.priority = kwargs.get("priority") or "Medium"
    doc.status = kwargs.get("status") or "Open"
    doc.customer_profile = profile.name
    doc.customer_name = profile.full_name or ""
    doc.contact_email = kwargs.get("contact_email") or profile.email or ""
    doc.contact_phone = kwargs.get("contact_phone") or profile.phone or ""
    doc.insert(ignore_permissions=True)

    mobile._create_service_timeline_entry(
        service_request=doc.name,
        event_type="Request Created",
        title="Request Created by OMC",
        description=kwargs.get("note") or "OMC team created this service request.",
        visible_to_customer=1,
    )

    frappe.db.commit()
    return {"created": True, "case": _case_to_queue_item(doc)}


def _case_to_queue_item(row):
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
        "customer_name": row.customer_name or _customer_name(row.customer_profile),
        "contact_email": row.contact_email or "",
        "contact_phone": row.contact_phone or "",
        "description": row.description or "",
        "created_at": mobile._format_mobile_datetime(row.creation),
        "updated_at": mobile._format_mobile_datetime(row.modified),
        "expected_completion_date": str(row.expected_completion_date) if row.expected_completion_date else "",
        "required_documents_count": doc_summary["required"],
        "submitted_documents_count": doc_summary["uploaded"] + doc_summary["approved"],
        "missing_documents_count": doc_summary["pending"] + doc_summary["rejected"],
        "document_summary": doc_summary,
        "document_summary_label": _document_summary_label(doc_summary),
        "can_review_documents": mobile._has_any_role(roles=mobile.DOCUMENT_REVIEW_ROLES),
        "can_update_status": mobile._has_any_role(roles=mobile.SERVICE_STATUS_ROLES),
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


def _int_value(value):
    try:
        return int(value or 0)
    except Exception:
        return 0
