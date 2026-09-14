from __future__ import annotations

import frappe
from frappe.utils import cint, get_datetime, now_datetime

from omc_app.api import mobile

REUSABLE_POLICIES = {"Reusable Until Replaced", "Reusable for N Days"}


def _text(value) -> str:
    return str(value or "").strip()


def _row_value(row, fieldname, default=None):
    if isinstance(row, dict):
        return row.get(fieldname, default)
    return getattr(row, fieldname, default)


def _document_payload(row) -> dict:
    return {
        "document_key": _row_value(row, "document_key", "") or "",
        "document_title": _row_value(row, "document_title", "") or "",
        "document_type": _row_value(row, "document_type", "") or "",
        "status": _row_value(row, "status", "") or "",
        "attachment": _row_value(row, "attachment", "") or "",
    }


def _document_fields() -> list[str]:
    fields = [
        "name",
        "service_request",
        "document_title",
        "document_type",
        "attachment",
        "status",
        "creation",
        "uploaded_on",
        "uploaded_by",
    ]
    for fieldname in (
        "document_key",
        "customer_profile",
        "source",
        "source_document",
        "quarantine_status",
        "is_archived",
        "archive_reason",
        "reviewed_by",
        "reviewed_on",
        "review_remarks",
        "visible_to_customer",
    ):
        if mobile._doctype_has_field("OMC Service Document", fieldname):
            fields.append(fieldname)
    return fields


def _reuse_policy(template: dict) -> str:
    return _text((template or {}).get("reuse_policy")) or "Always New"


def _source_within_validity(template: dict, source, *, reference_time=None) -> bool:
    policy = _reuse_policy(template)
    if policy == "Reusable Until Replaced":
        return True
    if policy != "Reusable for N Days":
        return False

    validity_days = cint((template or {}).get("reuse_validity_days") or 0)
    if validity_days <= 0:
        return False

    source_time = (
        _row_value(source, "reviewed_on")
        or _row_value(source, "uploaded_on")
        or _row_value(source, "creation")
    )
    if not source_time:
        return False

    try:
        source_dt = get_datetime(source_time)
        reference_dt = get_datetime(reference_time or now_datetime())
    except Exception:
        return False

    if source_dt > reference_dt:
        return False
    return (reference_dt - source_dt).total_seconds() <= validity_days * 86400


def _source_archive_is_eligible(source) -> bool:
    if not cint(_row_value(source, "is_archived", 0) or 0):
        return True
    return _text(_row_value(source, "archive_reason")) == "Service Completed"


def _current_request_documents(request) -> list:
    return frappe.get_all(
        "OMC Service Document",
        filters={
            "service_request": request.name,
            "visible_to_customer": 1,
        },
        fields=_document_fields(),
        order_by="creation desc, name desc",
        limit_page_length=1000,
    )


def _source_request_names(request) -> list[str]:
    if not _text(getattr(request, "customer_profile", None)) or not _text(
        getattr(request, "service", None)
    ):
        return []

    filters = {
        "name": ["!=", request.name],
        "service": request.service,
        "customer_profile": request.customer_profile,
        "status": ["!=", "Cancelled"],
        "request_state": ["not in", ["Cancelled", "Expired"]],
    }
    if getattr(request, "creation", None):
        filters["creation"] = ["<", request.creation]

    return frappe.get_all(
        "OMC Service Request",
        filters=filters,
        pluck="name",
        order_by="creation desc, name desc",
        limit_page_length=1000,
    )


def _source_documents(request) -> list:
    source_requests = _source_request_names(request)
    if not source_requests:
        return []

    rows = frappe.get_all(
        "OMC Service Document",
        filters={
            "service_request": ["in", source_requests],
            "status": "Approved",
            "visible_to_customer": 1,
        },
        fields=_document_fields(),
        order_by="reviewed_on desc, uploaded_on desc, creation desc, name desc",
        limit_page_length=1000,
    )

    result = []
    for row in rows:
        if not _text(_row_value(row, "attachment")):
            continue
        profile = _text(_row_value(row, "customer_profile"))
        if profile and profile != _text(request.customer_profile):
            continue
        if not _source_archive_is_eligible(row):
            continue
        result.append(row)
    return result


def _has_current_document(template: dict, current_documents: list) -> bool:
    for row in current_documents:
        if cint(_row_value(row, "is_archived", 0) or 0):
            continue
        if mobile._documents_match(template, _document_payload(row)):
            return True
    return False


def _find_reusable_source(template: dict, sources: list):
    if _reuse_policy(template) not in REUSABLE_POLICIES:
        return None

    for source in sources:
        if not mobile._documents_match(template, _document_payload(source)):
            continue
        if not _source_within_validity(template, source):
            continue
        return source
    return None


def _safe_user(value) -> str:
    user = _text(value)
    return user if user and frappe.db.exists("User", user) else ""


def _create_projection(request, template: dict, source):
    doc = frappe.new_doc("OMC Service Document")
    doc.service_request = request.name
    if doc.meta.has_field("customer_profile"):
        doc.customer_profile = request.customer_profile or ""
    if doc.meta.has_field("document_key"):
        doc.document_key = (
            template.get("document_key")
            or template.get("key")
            or _row_value(source, "document_key", "")
            or ""
        )
    doc.document_title = (
        template.get("document_title")
        or template.get("title")
        or _row_value(source, "document_title", "")
        or ""
    )
    doc.document_type = (
        template.get("document_type")
        or template.get("type")
        or _row_value(source, "document_type", "")
        or ""
    )
    doc.status = "Approved"
    if doc.meta.has_field("source"):
        doc.source = "Existing Document"
    if doc.meta.has_field("source_document"):
        doc.source_document = (
            _row_value(source, "source_document")
            or _row_value(source, "name")
            or ""
        )
    if doc.meta.has_field("quarantine_status"):
        doc.quarantine_status = _row_value(source, "quarantine_status") or "Not Required"
    if doc.meta.has_field("is_archived"):
        doc.is_archived = 0
    doc.visible_to_customer = 1
    doc.uploaded_by = _safe_user(_row_value(source, "uploaded_by")) or frappe.session.user
    doc.uploaded_on = _row_value(source, "uploaded_on") or _row_value(source, "creation")
    if doc.meta.has_field("reviewed_by"):
        doc.reviewed_by = _safe_user(_row_value(source, "reviewed_by"))
    if doc.meta.has_field("reviewed_on"):
        doc.reviewed_on = _row_value(source, "reviewed_on") or _row_value(source, "uploaded_on")
    if doc.meta.has_field("review_remarks"):
        doc.review_remarks = _row_value(source, "review_remarks") or ""
    doc.remarks = "Reused from an approved document already on file."
    doc.insert(ignore_permissions=True)

    attachment = _text(_row_value(source, "attachment"))
    frappe.db.set_value(
        "OMC Service Document",
        doc.name,
        "attachment",
        attachment,
        update_modified=False,
    )
    doc.attachment = attachment
    return doc


def ensure_reusable_documents(request_or_name) -> list[str]:
    """Materialize same-customer, same-service reusable evidence on a request.

    The request-local projection points to the approved earlier document. The
    source File and source document remain unchanged.
    """
    request = (
        frappe.get_doc("OMC Service Request", request_or_name)
        if isinstance(request_or_name, str)
        else request_or_name
    )
    if not request:
        return []
    if _text(getattr(request, "request_state", None)) in {"Cancelled", "Expired"}:
        return []
    if not _text(getattr(request, "service", None)) or not _text(
        getattr(request, "customer_profile", None)
    ):
        return []

    templates = mobile._service_required_documents(
        request.service,
        service_request=request,
    )
    reusable_templates = [
        template
        for template in templates
        if _reuse_policy(template) in REUSABLE_POLICIES
    ]
    if not reusable_templates:
        return []

    current_documents = _current_request_documents(request)
    sources = _source_documents(request)
    if not sources:
        return []

    created = []
    for template in reusable_templates:
        if _has_current_document(template, current_documents):
            continue
        source = _find_reusable_source(template, sources)
        if not source:
            continue
        projection = _create_projection(request, template, source)
        created.append(projection.name)
        current_documents.append(projection)
    return created
