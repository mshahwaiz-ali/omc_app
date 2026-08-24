from __future__ import annotations

import frappe

from omc_app import permissions
from omc_app.api import access, customer_documents, identity


DEFAULT_PAGE_SIZE = 20
MAX_PAGE_SIZE = 100


def _text(value) -> str:
    return str(value or "").strip()


def _pagination(limit_start=0, limit_page_length=20) -> tuple[int, int]:
    try:
        start = max(int(limit_start or 0), 0)
        length = min(max(int(limit_page_length or DEFAULT_PAGE_SIZE), 1), MAX_PAGE_SIZE)
    except (TypeError, ValueError):
        frappe.throw("Invalid document pagination values.", frappe.ValidationError)
    return start, length


def _archive_filter(show_archived):
    if not customer_documents._has_field("OMC Service Document", "is_archived"):
        return None
    if show_archived in ("1", 1, True, "true", "True"):
        return 1
    if show_archived in ("0", 0, False, "false", "False"):
        return 0
    return None


def _queue_status(queue, status):
    queue_key = _text(queue).lower()
    if queue_key in {"needs_review", "review"}:
        return ["Pending", "Uploaded"], 0
    if queue_key == "rejected":
        return ["Rejected"], None
    if queue_key == "approved":
        return ["Approved"], None
    if queue_key == "missing":
        return ["Pending"], None
    if queue_key == "archived":
        return [], 1
    status = _text(status)
    return ([status] if status else []), None


def _authorized_context(user: str):
    internal = access.is_internal_user(user)
    capabilities = access.get_mobile_capabilities(user=user)
    if internal:
        customer_documents._require_document_read_access(capabilities)
    else:
        identity.require_customer_context()
    return internal, capabilities


def _document_names(
    user: str,
    *,
    internal: bool,
    start: int,
    length: int,
    show_archived=None,
    queue=None,
    customer=None,
    service_request=None,
    status=None,
):
    scope = permissions.service_document_query(user)
    clauses = [f"({scope})"] if scope else []
    params: list[object] = []

    if not internal:
        clauses.append("ifnull(`tabOMC Service Document`.visible_to_customer, 1) = 1")

    service_request = _text(service_request)
    if service_request:
        clauses.append("`tabOMC Service Document`.service_request = %s")
        params.append(service_request)

    customer = _text(customer)
    if customer:
        clauses.append(
            "exists (select 1 from `tabOMC Service Request` sr_customer "
            "where sr_customer.name = `tabOMC Service Document`.service_request "
            "and sr_customer.customer_profile = %s)"
        )
        params.append(customer)

    statuses, queue_archive = _queue_status(queue, status)
    if statuses:
        placeholders = ", ".join(["%s"] * len(statuses))
        clauses.append(f"`tabOMC Service Document`.status in ({placeholders})")
        params.extend(statuses)

    archive_value = queue_archive if queue_archive is not None else _archive_filter(show_archived)
    if archive_value is not None and customer_documents._has_field(
        "OMC Service Document", "is_archived"
    ):
        clauses.append("ifnull(`tabOMC Service Document`.is_archived, 0) = %s")
        params.append(int(archive_value))

    where = " AND ".join(clauses) if clauses else "1=1"
    params.extend([length + 1, start])
    return frappe.db.sql(
        f"""
        SELECT `tabOMC Service Document`.name
        FROM `tabOMC Service Document`
        WHERE {where}
        ORDER BY `tabOMC Service Document`.uploaded_on DESC,
                 `tabOMC Service Document`.creation DESC,
                 `tabOMC Service Document`.name DESC
        LIMIT %s OFFSET %s
        """,
        tuple(params),
        pluck=True,
    )


@frappe.whitelist()
def get_documents(
    show_archived=None,
    queue=None,
    customer=None,
    service_request=None,
    status=None,
    limit_start=0,
    limit_page_length=20,
):
    """Pure scope-aware document list with bounded server-side pagination."""
    user = _text(getattr(frappe.session, "user", None) or "Guest")
    if user == "Guest":
        frappe.throw("Login is required.", frappe.PermissionError)
    start, length = _pagination(limit_start, limit_page_length)
    internal, capabilities = _authorized_context(user)
    names = _document_names(
        user,
        internal=internal,
        start=start,
        length=length,
        show_archived=show_archived,
        queue=queue,
        customer=customer,
        service_request=service_request,
        status=status,
    )
    has_more = len(names) > length
    names = names[:length]
    if not names:
        return {
            "documents": [],
            "limit_start": start,
            "limit_page_length": length,
            "next_start": None,
            "has_more": False,
        }

    rows_by_name = {
        row.name: row
        for row in frappe.get_all(
            "OMC Service Document",
            filters={"name": ["in", names]},
            fields=customer_documents._document_fields(),
            limit_page_length=length,
        )
    }
    docs = [rows_by_name[name] for name in names if name in rows_by_name]
    cases = customer_documents._service_case_map({doc.service_request for doc in docs})
    profiles = customer_documents._customer_profile_map(
        {
            getattr(doc, "customer_profile", None)
            or getattr(cases.get(doc.service_request), "customer_profile", None)
            for doc in docs
        }
    )
    payload = [
        customer_documents._document_dict(
            doc,
            service_case=cases.get(doc.service_request),
            customer_profile=profiles.get(
                getattr(doc, "customer_profile", None)
                or getattr(cases.get(doc.service_request), "customer_profile", None)
            ),
            capabilities=capabilities,
        )
        for doc in docs
    ]
    return {
        "documents": payload,
        "limit_start": start,
        "limit_page_length": length,
        "next_start": start + len(names) if has_more else None,
        "has_more": has_more,
    }
