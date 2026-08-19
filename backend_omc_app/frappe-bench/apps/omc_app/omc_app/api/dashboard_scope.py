from __future__ import annotations

import frappe

from omc_app import permissions
from omc_app.api import dashboard, service_case_contract


SERVICE_VIEW_CAPABILITIES = (
    "can_view_all_service_cases",
    "can_view_relevant_service_cases",
    "can_view_assigned_service_cases",
)
DOCUMENT_VIEW_CAPABILITIES = (
    "can_view_document_queue",
    "can_view_document_summaries",
    "can_view_document_attachments",
    "can_review_documents",
)
PAYMENT_VIEW_CAPABILITIES = (
    "can_view_payment_queue",
    "can_view_payment_summaries",
    "can_view_payment_receipts",
    "can_review_payments",
    "can_reconcile_settlement",
    "can_approve_post_paid",
)
SUPPORT_VIEW_CAPABILITIES = (
    "can_view_support_tickets",
    "can_reply_support_tickets",
    "can_update_support_ticket_status",
    "can_assign_support_tickets",
)
CUSTOMER_VIEW_CAPABILITIES = (
    "can_manage_customers",
    "can_view_all_customers",
    "can_view_relevant_customers",
)


def _has_any(capabilities, names):
    return any(bool(capabilities.get(name)) for name in names)


def _condition(query_fn, user):
    value = str(query_fn(user) or "").strip()
    return value or "1=1"


def _empty_lifecycle():
    return {
        "total": 0,
        "active": 0,
        "completed": 0,
        "cancelled": 0,
        "expired": 0,
        "waiting_customer": 0,
    }


def _empty_document_summary():
    return {
        "missing": 0,
        "pending": 0,
        "uploaded": 0,
        "under_review": 0,
        "approved": 0,
        "rejected": 0,
        "total": 0,
    }


def _empty_payment_summary():
    return {
        "pending": 0,
        "payments_due": 0,
        "receipt_submitted": 0,
        "under_review": 0,
        "receipt_under_review": 0,
        "paid": 0,
        "rejected": 0,
        "cancelled": 0,
        "total": 0,
    }


def _empty_support_summary():
    return {"open": 0, "waiting_customer": 0, "total": 0}


def _service_lifecycle(user, capabilities):
    if not _has_any(capabilities, SERVICE_VIEW_CAPABILITIES):
        return _empty_lifecycle()
    if not dashboard._doctype_exists("OMC Service Request"):
        return _empty_lifecycle()

    scope = _condition(permissions.service_request_query, user)
    rows = frappe.db.sql(
        f"""
        SELECT
            COUNT(*) AS total,
            SUM(CASE WHEN request_state = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
            SUM(CASE WHEN request_state = 'Expired' THEN 1 ELSE 0 END) AS expired,
            SUM(CASE WHEN request_state = 'Activated' AND status = 'Completed' THEN 1 ELSE 0 END) AS completed,
            SUM(
                CASE
                    WHEN status = 'Waiting for Customer'
                         AND ifnull(request_state, '') NOT IN ('Cancelled', 'Expired')
                    THEN 1 ELSE 0
                END
            ) AS waiting_customer
        FROM `tabOMC Service Request`
        WHERE ({scope})
        """,
        as_dict=True,
    )
    row = (rows or [{}])[0]
    total = int(row.get("total") or 0)
    cancelled = int(row.get("cancelled") or 0)
    expired = int(row.get("expired") or 0)
    completed = int(row.get("completed") or 0)
    return {
        "total": total,
        "active": max(total - cancelled - expired - completed, 0),
        "completed": completed,
        "cancelled": cancelled,
        "expired": expired,
        "waiting_customer": int(row.get("waiting_customer") or 0),
    }


def _document_summary(user, capabilities, service_request=None):
    if not _has_any(capabilities, DOCUMENT_VIEW_CAPABILITIES):
        return _empty_document_summary()
    if not dashboard._doctype_exists("OMC Service Document"):
        return _empty_document_summary()

    scope = _condition(permissions.service_document_query, user)
    clauses = [f"({scope})"]
    params = []
    if service_request:
        clauses.append("`tabOMC Service Document`.service_request = %s")
        params.append(service_request)
    try:
        meta = frappe.get_meta("OMC Service Document")
        if meta.has_field("is_archived"):
            clauses.append("ifnull(`tabOMC Service Document`.is_archived, 0) = 0")
    except Exception:
        pass

    rows = frappe.db.sql(
        f"""
        SELECT
            COUNT(*) AS total,
            SUM(CASE WHEN status = 'Pending' THEN 1 ELSE 0 END) AS pending,
            SUM(CASE WHEN status = 'Uploaded' THEN 1 ELSE 0 END) AS uploaded,
            SUM(CASE WHEN status = 'Approved' THEN 1 ELSE 0 END) AS approved,
            SUM(CASE WHEN status = 'Rejected' THEN 1 ELSE 0 END) AS rejected
        FROM `tabOMC Service Document`
        WHERE {' AND '.join(clauses)}
        """,
        tuple(params),
        as_dict=True,
    )
    row = (rows or [{}])[0]
    pending = int(row.get("pending") or 0)
    uploaded = int(row.get("uploaded") or 0)
    return {
        "missing": pending,
        "pending": pending,
        "uploaded": uploaded,
        "under_review": uploaded,
        "approved": int(row.get("approved") or 0),
        "rejected": int(row.get("rejected") or 0),
        "total": int(row.get("total") or 0),
    }


def _payment_summary(user, capabilities, service_request=None):
    if not _has_any(capabilities, PAYMENT_VIEW_CAPABILITIES):
        return _empty_payment_summary()
    if not dashboard._doctype_exists("OMC Service Payment"):
        return _empty_payment_summary()

    scope = _condition(permissions.service_payment_query, user)
    clauses = [f"({scope})"]
    params = []
    if service_request:
        clauses.append("`tabOMC Service Payment`.service_request = %s")
        params.append(service_request)

    rows = frappe.db.sql(
        f"""
        SELECT
            COUNT(*) AS total,
            SUM(CASE WHEN status = 'Pending' THEN 1 ELSE 0 END) AS pending,
            SUM(CASE WHEN status = 'Receipt Submitted' THEN 1 ELSE 0 END) AS receipt_submitted,
            SUM(CASE WHEN status = 'Under Review' THEN 1 ELSE 0 END) AS under_review,
            SUM(CASE WHEN status = 'Paid' THEN 1 ELSE 0 END) AS paid,
            SUM(CASE WHEN status = 'Rejected' THEN 1 ELSE 0 END) AS rejected,
            SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled
        FROM `tabOMC Service Payment`
        WHERE {' AND '.join(clauses)}
        """,
        tuple(params),
        as_dict=True,
    )
    row = (rows or [{}])[0]
    pending = int(row.get("pending") or 0)
    receipt_submitted = int(row.get("receipt_submitted") or 0)
    under_review = int(row.get("under_review") or 0)
    return {
        "pending": pending,
        "payments_due": pending,
        "receipt_submitted": receipt_submitted,
        "under_review": under_review,
        "receipt_under_review": receipt_submitted + under_review,
        "paid": int(row.get("paid") or 0),
        "rejected": int(row.get("rejected") or 0),
        "cancelled": int(row.get("cancelled") or 0),
        "total": int(row.get("total") or 0),
    }


def _support_summary(user, capabilities):
    if not _has_any(capabilities, SUPPORT_VIEW_CAPABILITIES):
        return _empty_support_summary()
    if not dashboard._doctype_exists("OMC Support Ticket"):
        return _empty_support_summary()

    scope = _condition(permissions.support_ticket_query, user)
    rows = frappe.db.sql(
        f"""
        SELECT
            COUNT(*) AS total,
            SUM(CASE WHEN status IN ('Open', 'In Progress', 'Waiting for Customer') THEN 1 ELSE 0 END) AS open_count,
            SUM(CASE WHEN status = 'Waiting for Customer' THEN 1 ELSE 0 END) AS waiting_customer
        FROM `tabOMC Support Ticket`
        WHERE ({scope})
        """,
        as_dict=True,
    )
    row = (rows or [{}])[0]
    return {
        "open": int(row.get("open_count") or 0),
        "waiting_customer": int(row.get("waiting_customer") or 0),
        "total": int(row.get("total") or 0),
    }


def _active_request_rows(user, capabilities, limit=3):
    if not _has_any(capabilities, SERVICE_VIEW_CAPABILITIES):
        return []
    if not dashboard._doctype_exists("OMC Service Request"):
        return []

    scope = _condition(permissions.service_request_query, user)
    names = frappe.db.sql(
        f"""
        SELECT name
        FROM `tabOMC Service Request`
        WHERE ({scope})
          AND ifnull(request_state, '') NOT IN ('Cancelled', 'Expired')
          AND ifnull(status, '') != 'Completed'
        ORDER BY modified DESC, creation DESC
        LIMIT %s
        """,
        (max(int(limit or 3), 1),),
        pluck=True,
    )
    if not names:
        return []

    rows = frappe.get_all(
        "OMC Service Request",
        filters={"name": ["in", names]},
        fields=[
            "name",
            "service",
            "title",
            "service_title",
            "status",
            "request_state",
            "priority",
            "customer_profile",
            "customer_name",
            "modified",
            "creation",
        ],
        limit_page_length=len(names),
    )
    by_name = {row.name: row for row in rows}
    return [by_name[name] for name in names if name in by_name]


def _service_snapshots(user, capabilities, limit=3):
    rows = _active_request_rows(user, capabilities, limit=limit)
    contracts = service_case_contract._bulk_contract([row.name for row in rows])
    include_documents = _has_any(capabilities, DOCUMENT_VIEW_CAPABILITIES)
    include_payments = _has_any(capabilities, PAYMENT_VIEW_CAPABILITIES)

    snapshots = []
    for row in rows:
        contract = contracts.get(row.name) or {}
        request_state = (
            str(contract.get("request_state") or "").strip()
            or str(row.request_state or "").strip()
            or "Draft"
        )
        operational_status = (
            str(
                contract.get("operational_status")
                or contract.get("status")
                or ""
            ).strip()
            or str(row.status or "").strip()
            or "Open"
        )
        documents = (
            _document_summary(user, capabilities, row.name)
            if include_documents
            else _empty_document_summary()
        )
        payments = (
            _payment_summary(user, capabilities, row.name)
            if include_payments
            else _empty_payment_summary()
        )
        total_docs = int(documents.get("total") or 0)
        approved_docs = int(documents.get("approved") or 0)
        progress = (
            min(1.0, max(0.0, approved_docs / total_docs))
            if total_docs
            else 0.35
        )

        snapshots.append(
            {
                "id": row.name,
                "name": row.name,
                "title": dashboard._service_title(row),
                "request_state": request_state,
                "status": operational_status,
                "operational_status": operational_status,
                "display_status": (
                    contract.get("display_status")
                    or service_case_contract._display_status(
                        request_state,
                        operational_status,
                    )
                ),
                "receipt": contract.get("receipt") or {} if include_payments else {},
                "settlement": contract.get("settlement") or {} if include_payments else {},
                "activation": contract.get("activation") or {},
                "hold": contract.get("hold") or {} if include_payments else {},
                "priority": row.priority or "Medium",
                "customer_profile": row.customer_profile or "",
                "customer_name": row.customer_name or "",
                "service": row.service or "",
                "color_family": dashboard._service_color_family(row.service),
                "documents": documents,
                "payments": payments,
                "document_summary": documents,
                "payment_summary": payments,
                "progress": progress,
                "progress_percent": int(round(progress * 100)),
                "modified": dashboard._format_datetime(row.modified),
                "created_at": dashboard._format_datetime(row.creation),
            }
        )
    return snapshots


def _recent_activity(user, capabilities):
    if not _has_any(capabilities, SERVICE_VIEW_CAPABILITIES):
        return []
    if not dashboard._doctype_exists("OMC Service Timeline"):
        return []

    scope = _condition(permissions.service_request_query, user)
    rows = frappe.db.sql(
        f"""
        SELECT
            timeline.name,
            timeline.service_request,
            timeline.event_type,
            timeline.title,
            timeline.description,
            timeline.event_time,
            timeline.created_by
        FROM `tabOMC Service Timeline` timeline
        INNER JOIN `tabOMC Service Request`
            ON `tabOMC Service Request`.name = timeline.service_request
        WHERE ({scope})
        ORDER BY timeline.event_time DESC, timeline.creation DESC
        LIMIT 10
        """,
        as_dict=True,
    )
    return [
        {
            "id": row.name,
            "service_request": row.service_request or "",
            "event_type": row.event_type or "",
            "title": row.title or row.event_type or "Update",
            "subtitle": row.description or "",
            "description": row.description or "",
            "created_at_label": dashboard._format_datetime(row.event_time),
            "event_time": dashboard._format_datetime(row.event_time),
            "created_by": row.created_by or "",
            "color_family": dashboard._activity_color_family(row),
        }
        for row in rows
    ]


def _active_customer_count(user, capabilities):
    if not _has_any(capabilities, CUSTOMER_VIEW_CAPABILITIES):
        return 0
    if not dashboard._doctype_exists("OMC Customer Profile"):
        return 0
    scope = _condition(permissions.customer_profile_query, user)
    rows = frappe.db.sql(
        f"""
        SELECT COUNT(*)
        FROM `tabOMC Customer Profile`
        WHERE ({scope}) AND customer_status = 'Active'
        """
    )
    return int(rows[0][0] if rows else 0)


def _pending_task_count(user, capabilities):
    if capabilities.get("can_manage_tasks"):
        return dashboard._pending_erp_task_count()
    if not capabilities.get("can_manage_assigned_tasks"):
        return 0
    if not dashboard._doctype_exists("Task") or not dashboard._doctype_exists("OMC Service Request"):
        return 0

    rows = frappe.db.sql(
        """
        SELECT COUNT(DISTINCT service_request.erp_task)
        FROM `tabOMC Service Request` service_request
        INNER JOIN `tabTask` task ON task.name = service_request.erp_task
        INNER JOIN `tabToDo` todo
            ON todo.reference_type = 'OMC Service Request'
           AND todo.reference_name = service_request.name
        WHERE todo.allocated_to = %s
          AND ifnull(todo.status, '') NOT IN ('Cancelled', 'Closed')
          AND ifnull(task.status, '') NOT IN ('Completed', 'Cancelled')
        """,
        (user,),
    )
    return int(rows[0][0] if rows else 0)


def _operations_summary(user, capabilities, lifecycle, documents, payments):
    open_leads = 0
    if capabilities.get("can_manage_leads"):
        open_leads = dashboard._count(
            "Lead",
            {
                "status": [
                    "not in",
                    ["Converted", "Do Not Contact", "Lost Quotation"],
                ]
            },
        )

    return {
        "open_leads": open_leads,
        "active_customers": _active_customer_count(user, capabilities),
        "pending_tasks": _pending_task_count(user, capabilities),
        "pending_payments": (
            int(payments.get("receipt_under_review") or 0)
            if (
                capabilities.get("can_view_payment_queue")
                or capabilities.get("can_review_payments")
            )
            else 0
        ),
        "documents_waiting_review": (
            int(documents.get("uploaded") or 0)
            if (
                capabilities.get("can_view_document_queue")
                or capabilities.get("can_review_documents")
            )
            else 0
        ),
        "active_services": int(lifecycle.get("active") or 0),
        "waiting_customer": int(lifecycle.get("waiting_customer") or 0),
    }


def _next_action(capabilities, operations, support):
    if (
        operations.get("documents_waiting_review", 0) > 0
        and capabilities.get("can_review_documents")
    ):
        count = operations["documents_waiting_review"]
        return {
            "type": "document_review",
            "title": f"{count} service documents need review",
            "subtitle": "Open the document review queue and clear uploaded customer documents.",
            "route": "/internal-workspace/documents",
            "button_label": "Open review queue",
        }
    if (
        operations.get("pending_payments", 0) > 0
        and capabilities.get("can_review_payments")
    ):
        count = operations["pending_payments"]
        return {
            "type": "payment_review",
            "title": f"{count} payments need review",
            "subtitle": "Review uploaded receipts or pending payment actions.",
            "route": "/internal-workspace/payments",
            "button_label": "Review payments",
        }
    if (
        support.get("open", 0) > 0
        and capabilities.get("can_view_support_tickets")
    ):
        count = support["open"]
        return {
            "type": "support",
            "title": f"{count} support tickets are active",
            "subtitle": "Open the support queue and continue customer conversations.",
            "route": "/support",
            "button_label": "Open support",
        }
    if operations.get("pending_tasks", 0) > 0 and (
        capabilities.get("can_manage_tasks")
        or capabilities.get("can_manage_assigned_tasks")
    ):
        count = operations["pending_tasks"]
        return {
            "type": "tasks",
            "title": f"{count} tasks need attention",
            "subtitle": "Open your work queue and continue assigned service work.",
            "route": "/tasks",
            "button_label": "Open tasks",
        }
    return {
        "type": "operations",
        "title": "Your work queue is clear",
        "subtitle": "No urgent item within your access scope needs attention right now.",
        "route": "/internal-workspace",
        "button_label": "Open workspace",
    }


def get_internal_dashboard_data(user):
    capabilities = dashboard._get_mobile_capabilities(user=user, profile=None)
    lifecycle = _service_lifecycle(user, capabilities)
    documents = _document_summary(user, capabilities)
    payments = _payment_summary(user, capabilities)
    support = _support_summary(user, capabilities)
    snapshots = _service_snapshots(user, capabilities, limit=3)
    operations = _operations_summary(
        user,
        capabilities,
        lifecycle,
        documents,
        payments,
    )

    return {
        "access_state": "internal",
        "is_internal": True,
        "capabilities": capabilities,
        "open_services": lifecycle["active"],
        "active_cases": lifecycle["active"],
        "completed_services": lifecycle["completed"],
        "completed_cases": lifecycle["completed"],
        "documents": documents.get("total", 0),
        "pending_documents": documents.get("missing", 0),
        "payments_due": payments.get("payments_due", 0),
        # Internal notifications have no canonical capability contract yet. Fail closed.
        "notifications": 0,
        "document_summary": documents,
        "payment_summary": payments,
        "support_summary": support,
        "active_services": snapshots,
        "service_snapshots": snapshots,
        "recent_activity": _recent_activity(user, capabilities),
        "operations_summary": operations,
        "next_action": _next_action(capabilities, operations, support),
    }
