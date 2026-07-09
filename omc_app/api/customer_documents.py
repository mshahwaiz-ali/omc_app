import frappe

from omc_app.api.mobile import (
    _assert_approved_customer,
    _can_access_internal_workspace,
    _format_datetime,
    _get_mobile_capabilities,
    require_omc_staff,
    DOCUMENT_REVIEW_ROLES,
)

ARCHIVE_SERVICE_STATUSES = {
    "Completed": "Service Completed",
    "Cancelled": "Service Cancelled",
}


def _has_field(doctype, fieldname):
    try:
        return frappe.get_meta(doctype).has_field(fieldname)
    except Exception:
        return False


def _set_value_if_field(doctype, name, fieldname, value):
    if _has_field(doctype, fieldname):
        frappe.db.set_value(doctype, name, fieldname, value, update_modified=False)


def _document_fields():
    fields = [
        "name",
        "service_request",
        "document_title",
        "document_type",
        "attachment",
        "status",
        "uploaded_on",
        "uploaded_by",
        "remarks",
    ]

    optional_fields = [
        "customer_profile",
        "source",
        "is_archived",
        "archived_on",
        "archive_reason",
        "reviewed_by",
        "reviewed_on",
        "review_remarks",
        "visible_to_customer",
    ]

    for fieldname in optional_fields:
        if _has_field("OMC Service Document", fieldname):
            fields.append(fieldname)

    return fields


def _service_case_map(service_request_names):
    if not service_request_names:
        return {}

    rows = frappe.get_all(
        "OMC Service Request",
        filters={"name": ["in", service_request_names]},
        fields=[
            "name",
            "status",
            "service_title",
            "service",
            "customer_profile",
        ],
    )

    return {row.name: row for row in rows}


def _document_dict(doc, service_case=None, capabilities=None):
    service_status = (getattr(service_case, "status", None) or "").strip()
    derived_archive_reason = ARCHIVE_SERVICE_STATUSES.get(service_status, "")
    is_archived = int(getattr(doc, "is_archived", 0) or 0)

    if not is_archived and derived_archive_reason:
        is_archived = 1

    archive_reason = getattr(doc, "archive_reason", None) or derived_archive_reason or ""
    service_title = (
        getattr(service_case, "service_title", None)
        or getattr(service_case, "service", None)
        or ""
    )

    review_remarks = getattr(doc, "review_remarks", None) or ""
    remarks = review_remarks or getattr(doc, "remarks", None) or ""

    return {
        "id": doc.name,
        "name": doc.name,
        "case_id": doc.service_request,
        "service_reference": doc.service_request,
        "service_title": service_title,
        "service_status": service_status,
        "title": doc.document_title or "",
        "document_title": doc.document_title or "",
        "type": doc.document_type or "",
        "document_type": doc.document_type or "",
        "status": doc.status or "",
        "source": getattr(doc, "source", None) or "Service Upload",
        "file_url": doc.attachment or "",
        "attachment": doc.attachment or "",
        "created_at": _format_datetime(doc.uploaded_on),
        "uploaded_on": _format_datetime(doc.uploaded_on),
        "uploaded_by": doc.uploaded_by or "",
        "remarks": remarks,
        "review_remarks": review_remarks,
        "reviewed_by": getattr(doc, "reviewed_by", None) or "",
        "reviewed_on": _format_datetime(getattr(doc, "reviewed_on", None)),
        "is_archived": is_archived,
        "archived": is_archived,
        "archived_on": _format_datetime(getattr(doc, "archived_on", None)),
        "archive_reason": archive_reason,
        "visible_to_customer": int(getattr(doc, "visible_to_customer", 1) or 0),
        "can_review_documents": bool((capabilities or {}).get("can_review_documents")),
    }


def archive_service_documents_for_status(service_request, status=None):
    """Hide completed/cancelled service documents from the customer default view.

    Files and records remain in Desk/admin review history.
    """

    if not service_request:
        return 0

    status = (status or frappe.db.get_value("OMC Service Request", service_request, "status") or "").strip()
    archive_reason = ARCHIVE_SERVICE_STATUSES.get(status)
    if not archive_reason:
        return 0

    docs = frappe.get_all(
        "OMC Service Document",
        filters={"service_request": service_request},
        fields=["name"],
    )

    archived_count = 0
    for row in docs:
        _set_value_if_field("OMC Service Document", row.name, "is_archived", 1)
        _set_value_if_field("OMC Service Document", row.name, "archived_on", frappe.utils.now_datetime())
        _set_value_if_field("OMC Service Document", row.name, "archive_reason", archive_reason)
        archived_count += 1

    return archived_count


def sync_service_document_customer_profile(service_request=None):
    filters = {}
    if service_request:
        filters["service_request"] = service_request

    if not _has_field("OMC Service Document", "customer_profile"):
        return 0

    docs = frappe.get_all(
        "OMC Service Document",
        filters=filters,
        fields=["name", "service_request", "customer_profile"],
    )

    updated = 0
    for doc in docs:
        if doc.customer_profile:
            continue

        customer_profile = frappe.db.get_value(
            "OMC Service Request",
            doc.service_request,
            "customer_profile",
        )
        if not customer_profile:
            continue

        frappe.db.set_value(
            "OMC Service Document",
            doc.name,
            "customer_profile",
            customer_profile,
            update_modified=False,
        )
        updated += 1

    return updated


@frappe.whitelist()
def get_documents(show_archived=None, queue=None, customer=None, service_request=None, status=None):
    is_internal = _can_access_internal_workspace()
    profile = None if is_internal else _assert_approved_customer()
    capabilities = _get_mobile_capabilities(profile=profile)

    service_filters = {}
    if profile:
        service_filters["customer_profile"] = profile.name
    elif customer:
        service_filters["customer_profile"] = customer

    if service_request:
        service_filters["name"] = service_request

    service_request_names = frappe.get_all(
        "OMC Service Request",
        filters=service_filters,
        pluck="name",
    )

    if not service_request_names:
        return {"documents": []}

    filters = {
        "service_request": ["in", service_request_names],
    }

    # Customer app view must never expose internal-only rows. Admin/review center
    # intentionally sees every service document, including archived/history rows.
    if not is_internal:
        filters["visible_to_customer"] = 1

    if status:
        filters["status"] = status

    if _has_field("OMC Service Document", "is_archived"):
        if show_archived in ("1", 1, True, "true", "True"):
            filters["is_archived"] = 1
        elif show_archived in ("0", 0, False, "false", "False"):
            filters["is_archived"] = 0

    queue_key = (queue or "").strip().lower()
    if queue_key in {"needs_review", "review"}:
        filters["status"] = ["in", ["Pending", "Uploaded"]]
        if _has_field("OMC Service Document", "is_archived"):
            filters["is_archived"] = 0
    elif queue_key == "rejected":
        filters["status"] = "Rejected"
    elif queue_key == "approved":
        filters["status"] = "Approved"
    elif queue_key == "missing":
        filters["status"] = "Pending"
    elif queue_key == "archived" and _has_field("OMC Service Document", "is_archived"):
        filters["is_archived"] = 1

    docs = frappe.get_all(
        "OMC Service Document",
        filters=filters,
        fields=_document_fields(),
        order_by="uploaded_on desc, creation desc",
    )

    service_cases = _service_case_map({doc.service_request for doc in docs})

    return {
        "documents": [
            _document_dict(
                doc,
                service_case=service_cases.get(doc.service_request),
                capabilities=capabilities,
            )
            for doc in docs
        ]
    }


@frappe.whitelist()
def get_document(document_id=None):
    if not document_id:
        frappe.throw("document_id is required")

    if not frappe.db.exists("OMC Service Document", document_id):
        frappe.throw("Document not found", frappe.DoesNotExistError)

    doc = frappe.get_doc("OMC Service Document", document_id)
    is_internal = _can_access_internal_workspace()

    if not is_internal and not doc.visible_to_customer:
        frappe.throw("Document not found", frappe.DoesNotExistError)

    profile = None if is_internal else _assert_approved_customer()
    capabilities = _get_mobile_capabilities(profile=profile)
    service_case = frappe.get_doc("OMC Service Request", doc.service_request)

    if profile and service_case.customer_profile and service_case.customer_profile != profile.name:
        frappe.throw("You do not have permission to access this document", frappe.PermissionError)

    return _document_dict(doc, service_case=service_case, capabilities=capabilities)


@frappe.whitelist()
def update_service_document_status(document_id=None, status=None, remarks=None):
    require_omc_staff(DOCUMENT_REVIEW_ROLES, "You do not have permission to review service documents.")

    if not document_id:
        frappe.throw("document_id is required")
    if not status:
        frappe.throw("status is required")

    allowed_statuses = ["Pending", "Uploaded", "Approved", "Rejected"]
    if status not in allowed_statuses:
        frappe.throw("Invalid document status")

    if not frappe.db.exists("OMC Service Document", document_id):
        frappe.throw("Service document not found", frappe.DoesNotExistError)

    doc = frappe.get_doc("OMC Service Document", document_id)
    old_status = doc.status or ""
    doc.status = status

    if remarks is not None:
        if _has_field("OMC Service Document", "review_remarks"):
            doc.review_remarks = remarks or ""
        doc.remarks = remarks or ""

    if status in {"Approved", "Rejected"}:
        if _has_field("OMC Service Document", "reviewed_by"):
            doc.reviewed_by = frappe.session.user
        if _has_field("OMC Service Document", "reviewed_on"):
            doc.reviewed_on = frappe.utils.now_datetime()

    doc.save(ignore_permissions=True)

    if old_status != status:
        from omc_app.api.mobile import _create_service_timeline_entry

        _create_service_timeline_entry(
            service_request=doc.service_request,
            event_type="Update",
            title=f"Document {status}",
            description=remarks or f"{doc.document_title or 'Document'} marked as {status}.",
            visible_to_customer=1,
        )

    frappe.db.commit()

    return {
        "name": doc.name,
        "case_id": doc.service_request,
        "status": doc.status,
        "updated": True,
        "message": "Service document updated.",
    }
