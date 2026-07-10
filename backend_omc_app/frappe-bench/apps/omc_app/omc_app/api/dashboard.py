import frappe

from omc_app.api.mobile import (
    _assert_approved_customer,
    _can_access_internal_workspace,
    _current_user,
    _format_datetime,
    _get_mobile_capabilities,
)


OPEN_SERVICE_STATUSES = ["Open", "In Progress", "Waiting for Customer"]
CLOSED_SERVICE_STATUSES = ["Completed", "Cancelled"]
OPEN_SUPPORT_STATUSES = ["Open", "In Progress", "Waiting for Customer"]
PAYMENT_REVIEW_STATUSES = ["Receipt Submitted", "Under Review"]


def _doctype_exists(doctype):
    try:
        return bool(frappe.db.exists("DocType", doctype))
    except Exception:
        return False


def _count(doctype, filters=None):
    if not _doctype_exists(doctype):
        return 0
    try:
        return frappe.db.count(doctype, filters or {})
    except Exception:
        return 0


def _get_all(doctype, **kwargs):
    if not _doctype_exists(doctype):
        return []
    try:
        return frappe.get_all(doctype, **kwargs)
    except Exception:
        return []


def _status_count(doctype, base_filters, status):
    filters = dict(base_filters or {})
    filters["status"] = status
    return _count(doctype, filters)


def _service_scope(profile=None):
    filters = {}
    if profile:
        filters["customer_profile"] = profile.name
    return filters


def _related_filters(profile, doctype, service_names):
    filters = {}

    if doctype in {"OMC Service Document", "OMC Service Payment", "OMC Service Timeline"}:
        if _doctype_exists(doctype):
            meta = frappe.get_meta(doctype)
            if meta.has_field("visible_to_customer"):
                filters["visible_to_customer"] = 1
            if meta.has_field("is_archived"):
                filters["is_archived"] = 0

    if profile:
        if doctype == "OMC Support Ticket":
            filters["customer_profile"] = profile.name
        elif service_names:
            filters["service_request"] = ["in", service_names]
        else:
            filters["service_request"] = "__no_service_requests__"

    return filters


def _service_names(profile=None):
    filters = _service_scope(profile)
    return _get_all("OMC Service Request", filters=filters, pluck="name")


def _service_title(row):
    title = (getattr(row, "service_title", None) or "").strip()
    if title:
        return title
    title = (getattr(row, "title", None) or "").strip()
    if title:
        return title
    return "Service Request"


def _document_summary(filters):
    return {
        "missing": _status_count("OMC Service Document", filters, "Pending"),
        "pending": _status_count("OMC Service Document", filters, "Pending"),
        "uploaded": _status_count("OMC Service Document", filters, "Uploaded"),
        "under_review": _status_count("OMC Service Document", filters, "Uploaded"),
        "approved": _status_count("OMC Service Document", filters, "Approved"),
        "rejected": _status_count("OMC Service Document", filters, "Rejected"),
        "total": _count("OMC Service Document", filters),
    }


def _payment_summary(filters):
    pending = _status_count("OMC Service Payment", filters, "Pending")
    receipt_submitted = _status_count("OMC Service Payment", filters, "Receipt Submitted")
    under_review = _status_count("OMC Service Payment", filters, "Under Review")

    return {
        "pending": pending,
        "payments_due": pending,
        "receipt_submitted": receipt_submitted,
        "under_review": under_review,
        "receipt_under_review": receipt_submitted + under_review,
        "paid": _status_count("OMC Service Payment", filters, "Paid"),
        "rejected": _status_count("OMC Service Payment", filters, "Rejected"),
        "cancelled": _status_count("OMC Service Payment", filters, "Cancelled"),
        "total": _count("OMC Service Payment", filters),
    }


def _support_summary(profile=None):
    filters = {}
    if profile:
        filters["customer_profile"] = profile.name

    open_filters = dict(filters)
    open_filters["status"] = ["in", OPEN_SUPPORT_STATUSES]

    waiting_filters = dict(filters)
    waiting_filters["status"] = "Waiting for Customer"

    return {
        "open": _count("OMC Support Ticket", open_filters),
        "waiting_customer": _count("OMC Support Ticket", waiting_filters),
        "total": _count("OMC Support Ticket", filters),
    }


def _service_document_summary(service_name):
    filters = {"service_request": service_name}
    if _doctype_exists("OMC Service Document"):
        meta = frappe.get_meta("OMC Service Document")
        if meta.has_field("visible_to_customer"):
            filters["visible_to_customer"] = 1
        if meta.has_field("is_archived"):
            filters["is_archived"] = 0
    return _document_summary(filters)


def _service_payment_summary(service_name):
    filters = {"service_request": service_name}
    if _doctype_exists("OMC Service Payment"):
        meta = frappe.get_meta("OMC Service Payment")
        if meta.has_field("visible_to_customer"):
            filters["visible_to_customer"] = 1
    return _payment_summary(filters)


def _family_from_text(text):
    normalized = (text or "").strip().lower()
    if any(token in normalized for token in ("payment", "receipt", "invoice", "bill")):
        return "Payments"
    if any(token in normalized for token in ("document", "docs", "uploaded", "upload")):
        return "Documents"
    if any(token in normalized for token in ("track", "review", "progress", "status")):
        return "Track"
    if "lead" in normalized:
        return "Leads"
    if any(token in normalized for token in ("task", "todo", "action needed")):
        return "Tasks"
    if any(token in normalized for token in ("notification", "alert", "message")):
        return "Notifications"
    if any(token in normalized for token in ("tax", "gst", "ntn", "calculator")):
        return "Tax"
    return "Services"


def _service_color_family(service_name):
    if not service_name or not _doctype_exists("OMC Service"):
        return ""

    try:
        service = frappe.db.get_value(
            "OMC Service",
            service_name,
            ["color_family", "wizard_type", "title"],
            as_dict=True,
        )
    except Exception:
        service = None

    if not service:
        return ""

    color_family = (service.get("color_family") or "").strip()
    if color_family:
        return color_family

    wizard_type = (service.get("wizard_type") or "").strip()
    if wizard_type:
        return _family_from_text(wizard_type)

    return _family_from_text(service.get("title") or service_name)


def _activity_color_family(row):
    raw_text = " ".join([
        row.event_type or "",
        row.title or "",
        row.description or "",
    ])
    family = _family_from_text(raw_text)
    if family != "Services":
        return family

    service_family = _service_color_family(row.service_request)
    return service_family or family


def _service_snapshots(profile=None, limit=3):
    filters = _service_scope(profile)
    filters["status"] = ["not in", CLOSED_SERVICE_STATUSES]

    rows = _get_all(
        "OMC Service Request",
        filters=filters,
        fields=[
            "name",
            "service",
            "title",
            "service_title",
            "status",
            "priority",
            "customer_profile",
            "customer_name",
            "modified",
            "creation",
        ],
        order_by="modified desc, creation desc",
        limit_page_length=limit,
    )

    snapshots = []
    for row in rows:
        docs = _service_document_summary(row.name)
        payments = _service_payment_summary(row.name)
        total_docs = docs.get("total") or 0
        approved_docs = docs.get("approved") or 0
        progress = 0.0
        if total_docs:
            progress = min(1.0, max(0.0, approved_docs / total_docs))
        elif (row.status or "") == "Completed":
            progress = 1.0
        else:
            progress = 0.35

        snapshots.append(
            {
                "id": row.name,
                "name": row.name,
                "title": _service_title(row),
                "status": row.status or "Open",
                "priority": row.priority or "Medium",
                "customer_profile": row.customer_profile or "",
                "customer_name": row.customer_name or "",
                "service": row.service or "",
                "color_family": _service_color_family(row.service),
                "documents": docs,
                "payments": payments,
                "document_summary": docs,
                "payment_summary": payments,
                "progress": progress,
                "progress_percent": int(round(progress * 100)),
                "modified": _format_datetime(row.modified),
                "created_at": _format_datetime(row.creation),
            }
        )

    return snapshots


def _recent_activity(filters):
    rows = _get_all(
        "OMC Service Timeline",
        filters=filters,
        fields=[
            "name",
            "service_request",
            "event_type",
            "title",
            "description",
            "event_time",
            "created_by",
        ],
        order_by="event_time desc, creation desc",
        limit_page_length=10,
    )

    return [
        {
            "id": row.name,
            "service_request": row.service_request or "",
            "event_type": row.event_type or "",
            "title": row.title or row.event_type or "Update",
            "subtitle": row.description or "",
            "description": row.description or "",
            "created_at_label": _format_datetime(row.event_time),
            "event_time": _format_datetime(row.event_time),
            "created_by": row.created_by or "",
            "color_family": _activity_color_family(row),
        }
        for row in rows
    ]


def _internal_operations_summary(customer_summary):
    open_leads = _count("OMC Lead", {"status": ["not in", ["Closed", "Converted", "Lost"]]})
    active_customers = _count("OMC Customer Profile", {"customer_status": "Active"})
    pending_tasks = _count("OMC Task", {"status": ["not in", ["Completed", "Cancelled"]]})
    payment_review_filters = {"status": ["in", PAYMENT_REVIEW_STATUSES]}

    return {
        "open_leads": open_leads,
        "active_customers": active_customers,
        "pending_tasks": pending_tasks,
        "pending_payments": _count("OMC Service Payment", payment_review_filters),
        "documents_waiting_review": customer_summary["document_summary"].get("uploaded", 0),
        "active_services": customer_summary.get("open_services", 0),
        "waiting_customer": _count("OMC Service Request", {"status": "Waiting for Customer"}),
    }


def _next_action(summary, is_internal=False):
    if is_internal:
        operations = summary.get("operations_summary") or {}
        if operations.get("documents_waiting_review", 0) > 0:
            return {
                "type": "document_review",
                "title": f"{operations['documents_waiting_review']} service documents need review",
                "subtitle": "Open the document review queue and clear uploaded customer documents.",
                "route": "/internal-workspace/documents",
                "button_label": "Open review queue",
            }
        if operations.get("pending_payments", 0) > 0:
            return {
                "type": "payment_review",
                "title": f"{operations['pending_payments']} payments need review",
                "subtitle": "Review uploaded receipts or pending payment actions.",
                "route": "/internal-workspace/payments",
                "button_label": "Review payments",
            }
        return {
            "type": "operations",
            "title": "Operations queue is clear",
            "subtitle": "No urgent internal queue item is visible right now.",
            "route": "/internal-workspace",
            "button_label": "Open workspace",
        }

    if summary.get("pending_documents", 0) > 0:
        return {
            "type": "upload_documents",
            "title": f"Upload {summary['pending_documents']} pending documents",
            "subtitle": "Complete the required document checklist to keep your service moving.",
            "route": "/documents",
            "button_label": "Upload now",
        }
    if summary.get("payments_due", 0) > 0:
        return {
            "type": "payment",
            "title": f"{summary['payments_due']} payments need attention",
            "subtitle": "Review dues or upload receipts so OMC can continue processing.",
            "route": "/payments",
            "button_label": "View payment",
        }
    if summary.get("open_services", 0) > 0:
        return {
            "type": "track_services",
            "title": "Your active services are in progress",
            "subtitle": "Open your workspace to review service status and updates.",
            "route": "/my-services",
            "button_label": "Track services",
        }
    return {
        "type": "browse_services",
        "title": "No action needed right now",
        "subtitle": "Your OMC workspace is clear.",
        "route": "/services",
        "button_label": "Browse services",
    }


@frappe.whitelist()
def get_dashboard_data():
    user = _current_user()
    is_internal = _can_access_internal_workspace(user)
    profile = None if is_internal else _assert_approved_customer()

    service_names = _service_names(profile)
    service_filters = _service_scope(profile)
    document_filters = _related_filters(profile, "OMC Service Document", service_names)
    payment_filters = _related_filters(profile, "OMC Service Payment", service_names)
    timeline_filters = _related_filters(profile, "OMC Service Timeline", service_names)

    open_service_filters = dict(service_filters)
    open_service_filters["status"] = ["not in", CLOSED_SERVICE_STATUSES]
    completed_service_filters = dict(service_filters)
    completed_service_filters["status"] = "Completed"

    document_summary = _document_summary(document_filters)
    payment_summary = _payment_summary(payment_filters)

    summary = {
        "access_state": "internal" if is_internal else "approved",
        "is_internal": is_internal,
        "capabilities": _get_mobile_capabilities(user=user, profile=profile),
        "open_services": _count("OMC Service Request", open_service_filters),
        "active_cases": _count("OMC Service Request", open_service_filters),
        "completed_services": _count("OMC Service Request", completed_service_filters),
        "completed_cases": _count("OMC Service Request", completed_service_filters),
        "documents": document_summary.get("missing", 0),
        "pending_documents": document_summary.get("missing", 0),
        "payments_due": payment_summary.get("payments_due", 0),
        "notifications": _count(
            "OMC Notification",
            {
                **({"customer_profile": profile.name} if profile else {}),
                "visible_to_customer": 1,
                "is_read": 0,
            },
        ),
        "document_summary": document_summary,
        "payment_summary": payment_summary,
        "support_summary": _support_summary(profile),
        "active_services": _service_snapshots(profile=profile, limit=3),
        "service_snapshots": _service_snapshots(profile=profile, limit=3),
        "recent_activity": _recent_activity(timeline_filters),
        "next_action": None,
    }

    if is_internal:
        summary["operations_summary"] = _internal_operations_summary(summary)
        summary["next_action"] = _next_action(summary, is_internal=True)
    else:
        summary["next_action"] = _next_action(summary, is_internal=False)

    return {"message": summary}
