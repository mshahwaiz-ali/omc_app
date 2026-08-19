from __future__ import annotations

import frappe

from omc_app import permissions
from omc_app.api import access, internal_workspace, mobile, service_case_contract


DEFAULT_PAGE_SIZE = 50
MAX_PAGE_SIZE = 100
SERVICE_CASE_CAPABILITIES = (
    "can_view_all_service_cases",
    "can_view_relevant_service_cases",
    "can_view_assigned_service_cases",
)


def _pagination(limit_start=0, limit_page_length=50) -> tuple[int, int]:
    try:
        start = max(int(limit_start or 0), 0)
        length = min(
            max(int(limit_page_length or DEFAULT_PAGE_SIZE), 1),
            MAX_PAGE_SIZE,
        )
    except (TypeError, ValueError):
        frappe.throw("Invalid service case pagination values.", frappe.ValidationError)
    return start, length


def _text(value) -> str:
    return str(value or "").strip()


def _document_status_clause(value, params):
    status = _text(value).lower()
    if not status:
        return ""

    status_map = {
        "needs_review": "Uploaded",
        "review": "Uploaded",
        "uploaded": "Uploaded",
        "pending": "Pending",
        "missing": "Pending",
        "approved": "Approved",
        "rejected": "Rejected",
    }
    resolved = status_map.get(status, _text(value))
    if not resolved:
        return ""

    params.append(resolved)
    return (
        "exists (select 1 from `tabOMC Service Document` scoped_document "
        "where scoped_document.service_request = `tabOMC Service Request`.name "
        "and scoped_document.status = %s)"
    )


def _where_clause(
    user,
    *,
    search=None,
    customer=None,
    case_id=None,
    status=None,
    service=None,
    document_status=None,
):
    scope = str(permissions.service_request_query(user) or "").strip()
    clauses = [f"({scope})"] if scope else []
    params = []

    case_id = _text(case_id)
    if case_id:
        clauses.append("`tabOMC Service Request`.name = %s")
        params.append(case_id)

    customer = _text(customer)
    if customer:
        clauses.append("`tabOMC Service Request`.customer_profile = %s")
        params.append(customer)

    status = _text(status)
    if status:
        clauses.append("`tabOMC Service Request`.status = %s")
        params.append(status)

    service = _text(service)
    if service:
        clauses.append("`tabOMC Service Request`.service = %s")
        params.append(service)

    search = _text(search)
    if search:
        like = f"%{search}%"
        searchable_fields = (
            "name",
            "title",
            "service_title",
            "customer_name",
            "customer_profile",
            "status",
            "request_state",
            "priority",
        )
        clauses.append(
            "(" + " OR ".join(
                f"ifnull(`tabOMC Service Request`.{field}, '') like %s"
                for field in searchable_fields
            ) + ")"
        )
        params.extend([like] * len(searchable_fields))

    document_clause = _document_status_clause(document_status, params)
    if document_clause:
        clauses.append(document_clause)

    return " AND ".join(clauses) if clauses else "1=1", params


def _case_names(where, params, *, start, length):
    query_params = [*params, length + 1, start]
    return frappe.db.sql(
        f"""
        SELECT `tabOMC Service Request`.name
        FROM `tabOMC Service Request`
        WHERE {where}
        ORDER BY `tabOMC Service Request`.modified DESC,
                 `tabOMC Service Request`.name DESC
        LIMIT %s OFFSET %s
        """,
        tuple(query_params),
        pluck=True,
    )


def _total_count(where, params):
    rows = frappe.db.sql(
        f"""
        SELECT COUNT(*)
        FROM `tabOMC Service Request`
        WHERE {where}
        """,
        tuple(params),
    )
    return int(rows[0][0] if rows else 0)


def _rows_for_names(names):
    if not names:
        return []
    rows = frappe.get_all(
        "OMC Service Request",
        filters={"name": ["in", names]},
        fields=internal_workspace.SERVICE_CASE_FIELDS,
        limit_page_length=len(names),
    )
    by_name = {row.name: row for row in rows}
    return [by_name[name] for name in names if name in by_name]


@frappe.whitelist()
def get_service_cases(
    search=None,
    customer=None,
    case_id=None,
    status=None,
    service=None,
    document_status=None,
    limit_start=0,
    limit_page_length=50,
):
    """Return a capability-scoped, server-paginated internal case queue."""
    user = mobile._assert_internal_workspace_access()
    capabilities = access.get_mobile_capabilities(user=user)
    if not any(capabilities.get(key) for key in SERVICE_CASE_CAPABILITIES):
        frappe.throw(
            "You do not have permission to view internal service cases.",
            frappe.PermissionError,
        )

    start, length = _pagination(limit_start, limit_page_length)
    where, params = _where_clause(
        user,
        search=search,
        customer=customer,
        case_id=case_id,
        status=status,
        service=service,
        document_status=document_status,
    )
    names = _case_names(where, params, start=start, length=length)
    has_more = len(names) > length
    names = names[:length]
    rows = _rows_for_names(names)
    contracts = service_case_contract._bulk_contract([row.name for row in rows])
    cases = [
        internal_workspace._case_to_queue_item(
            row,
            contract=contracts.get(row.name),
        )
        for row in rows
    ]

    return {
        "cases": cases,
        "summary": internal_workspace._queue_summary(cases),
        "capabilities": capabilities,
        "limit_start": start,
        "limit_page_length": length,
        "next_start": start + len(names) if has_more else None,
        "has_more": has_more,
        "total_count": _total_count(where, params),
    }
