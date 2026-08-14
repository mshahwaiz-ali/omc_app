from __future__ import annotations

import frappe

from omc_app.api import support_chat


def _ticket_not_found():
    frappe.throw("Support ticket not found", frappe.DoesNotExistError)


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
    return payload


def _safe_ticket_payload(ticket_name):
    try:
        ticket = _load_ticket(ticket_name)
        return _sanitize_ticket_payload(support_chat._support_ticket_to_dict(ticket))
    except frappe.DoesNotExistError:
        return None


@frappe.whitelist()
def get_support_tickets():
    user, _profile, filters = support_chat._support_ticket_filters_for_current_user()
    if user == "Guest" or filters is None:
        return {"tickets": []}

    ticket_names = frappe.get_all(
        "OMC Support Ticket",
        filters=filters,
        pluck="name",
        order_by="modified desc",
        limit_page_length=50,
    )

    tickets = []
    for ticket_name in ticket_names:
        payload = _safe_ticket_payload(ticket_name)
        if payload:
            tickets.append(payload)
    return {"tickets": tickets}


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
        order_by="modified desc",
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
