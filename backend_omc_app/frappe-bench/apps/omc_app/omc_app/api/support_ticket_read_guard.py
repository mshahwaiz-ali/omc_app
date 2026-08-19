from __future__ import annotations

import frappe

from omc_app.api import support_chat


DEFAULT_PAGE_SIZE = 20
MAX_PAGE_SIZE = 100
TERMINAL_STATUSES = {"closed", "cancelled"}


def _ticket_not_found():
    frappe.throw("Support ticket not found", frappe.DoesNotExistError)


def _pagination(limit_start=0, limit_page_length=20) -> tuple[int, int]:
    try:
        start = max(int(limit_start or 0), 0)
        length = min(max(int(limit_page_length or DEFAULT_PAGE_SIZE), 1), MAX_PAGE_SIZE)
    except (TypeError, ValueError):
        frappe.throw("Invalid support pagination values.", frappe.ValidationError)
    return start, length


def _load_ticket(ticket_id):
    if not ticket_id or not frappe.db.exists("OMC Support Ticket", ticket_id):
        _ticket_not_found()
    return frappe.get_doc("OMC Support Ticket", ticket_id)


def _sanitize_ticket_payload(payload):
    if not isinstance(payload, dict):
        return payload

    service_request = (payload.get("reference_service_request") or "").strip()
    if service_request and not frappe.db.exists("OMC Service Request", service_request):
        payload["reference_service_request"] = ""

    # Customer support access is ownership-based. The canonical customer
    # capability contract intentionally has no internal support read/reply key;
    # creating support tickets is the customer-side support authority. Keep the
    # read projection aligned with that contract and never expose staff
    # assignment metadata to customers.
    if not support_chat._can_access_internal_workspace():
        capabilities = support_chat._capabilities()
        status = str(payload.get("status") or "").strip().lower()
        payload["can_reply"] = bool(
            status not in TERMINAL_STATUSES
            and capabilities.get("can_create_support_ticket")
        )
        payload["can_assign"] = False
        payload["assigned_to"] = ""

    return payload


def _safe_ticket_payload(ticket_name):
    try:
        ticket = _load_ticket(ticket_name)
        return _sanitize_ticket_payload(support_chat._support_ticket_to_dict(ticket))
    except frappe.DoesNotExistError:
        return None


@frappe.whitelist()
def get_support_tickets(limit_start=0, limit_page_length=20):
    user, _profile, filters = support_chat._support_ticket_filters_for_current_user()
    start, length = _pagination(limit_start, limit_page_length)
    if user == "Guest" or filters is None:
        return {
            "tickets": [],
            "limit_start": start,
            "limit_page_length": length,
            "next_start": None,
            "has_more": False,
        }

    ticket_names = frappe.get_all(
        "OMC Support Ticket",
        filters=filters,
        pluck="name",
        order_by="modified desc, name desc",
        limit_start=start,
        limit_page_length=length + 1,
    )
    has_more = len(ticket_names) > length
    ticket_names = ticket_names[:length]

    tickets = []
    for ticket_name in ticket_names:
        payload = _safe_ticket_payload(ticket_name)
        if payload:
            tickets.append(payload)
    return {
        "tickets": tickets,
        "limit_start": start,
        "limit_page_length": length,
        "next_start": start + len(ticket_names) if has_more else None,
        "has_more": has_more,
    }


@frappe.whitelist()
def get_support_ticket(ticket_id=None, name=None):
    resolved_id = ticket_id or name
    if not resolved_id:
        frappe.throw("ticket_id is required")

    ticket = _load_ticket(resolved_id)
    support_chat._assert_support_ticket_access(ticket)
    return {
        "ticket": _sanitize_ticket_payload(
            support_chat._support_ticket_to_dict(ticket)
        )
    }


@frappe.whitelist()
def get_active_support_ticket():
    user, _profile, filters = support_chat._support_ticket_filters_for_current_user()
    if user == "Guest" or filters is None:
        return {"ticket": None}

    active_filters = dict(filters)
    active_filters["status"] = ["not in", ["Closed", "Cancelled"]]
    ticket_names = frappe.get_all(
        "OMC Support Ticket",
        filters=active_filters,
        pluck="name",
        order_by="modified desc, name desc",
        limit_page_length=10,
    )

    for ticket_name in ticket_names:
        try:
            ticket = _load_ticket(ticket_name)
            support_chat._assert_support_ticket_access(ticket)
            return {
                "ticket": _sanitize_ticket_payload(
                    support_chat._support_ticket_to_dict(ticket)
                )
            }
        except frappe.DoesNotExistError:
            continue
    return {"ticket": None}
