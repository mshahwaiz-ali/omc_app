from __future__ import annotations

import frappe

from omc_app import permissions
from omc_app.api import access, identity, secured_mobile


MAX_PAGE_SIZE = 100
DEFAULT_PAGE_SIZE = 20


def _pagination(start=0, limit=20, limit_start=None, limit_page_length=None) -> tuple[int, int]:
    raw_start = limit_start if limit_start is not None else start
    raw_limit = limit_page_length if limit_page_length is not None else limit
    try:
        offset = max(int(raw_start or 0), 0)
        length = min(max(int(raw_limit or DEFAULT_PAGE_SIZE), 1), MAX_PAGE_SIZE)
    except (TypeError, ValueError):
        frappe.throw("Invalid pagination values.", frappe.ValidationError)
    return offset, length


def _authorize(user: str) -> None:
    if access.is_internal_user(user):
        values = access.get_mobile_capabilities(user=user)
        if not any(
            values.get(key)
            for key in (
                "can_view_all_service_cases",
                "can_view_relevant_service_cases",
                "can_view_assigned_service_cases",
            )
        ):
            frappe.throw(
                "You do not have permission to view service cases.",
                frappe.PermissionError,
            )
        return
    identity.require_customer_context()


def _rows(user: str, *, offset: int, length: int):
    condition = permissions.service_request_query(user)
    where = f"WHERE ({condition})" if condition else ""
    return frappe.db.sql(
        f"""
        SELECT
            name, title, status, request_state, priority, service, service_title,
            description, customer_mode, submission_mode, created_on_behalf,
            creation, modified, expected_completion_date
        FROM `tabOMC Service Request`
        {where}
        ORDER BY modified DESC, name DESC
        LIMIT %s OFFSET %s
        """,
        (length + 1, offset),
        as_dict=True,
    )


@frappe.whitelist()
def get_service_cases(start=0, limit=20, limit_start=None, limit_page_length=None):
    """Pure, scope-aware, paginated service-request list for mobile and Desk."""
    user = str(getattr(frappe.session, "user", None) or "Guest").strip()
    if user == "Guest":
        frappe.throw("Login is required.", frappe.PermissionError)
    _authorize(user)
    offset, length = _pagination(start, limit, limit_start, limit_page_length)
    rows = _rows(user, offset=offset, length=length)
    has_more = len(rows) > length
    rows = rows[:length]

    cases = []
    internal = access.is_internal_user(user)
    for row in rows:
        payload = {
            "name": row.name,
            "id": row.name,
            "reference": row.name,
            "case_reference": row.name,
            "title": row.title or row.service_title or "Service Request",
            "status": row.status or "",
            "request_state": row.request_state or "",
            "priority": row.priority or "",
            "service": row.service_title or row.service or "",
            "service_id": row.service or "",
            "service_title": row.service_title or "",
            "description": row.description or "",
            "customer_mode": row.customer_mode or "",
            "submission_mode": row.submission_mode or "",
            "created_on_behalf": int(row.created_on_behalf or 0),
            "created_at": str(row.creation.date()) if row.creation else "",
            "updated_at": str(row.modified.date()) if row.modified else "",
            "expected_completion_date": str(row.expected_completion_date or ""),
        }
        secured_mobile._normalize_service_case(
            payload,
            can_access_internal_workspace=internal,
        )
        cases.append(payload)

    return {
        "cases": cases,
        "limit_start": offset,
        "limit_page_length": length,
        "next_start": offset + len(cases) if has_more else None,
        "has_more": has_more,
    }
