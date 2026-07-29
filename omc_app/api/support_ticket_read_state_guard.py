from __future__ import annotations

import frappe

from omc_app.api import support_chat


def _ticket_not_found():
    frappe.throw("Support ticket not found", frappe.DoesNotExistError)


def _load_accessible_ticket(ticket_id):
    if not ticket_id or not frappe.db.exists("OMC Support Ticket", ticket_id):
        _ticket_not_found()

    ticket = frappe.get_doc("OMC Support Ticket", ticket_id)
    user, profile = support_chat._assert_support_ticket_access(ticket)
    return ticket, user, profile


@frappe.whitelist()
def get_support_unread_count():
    return support_chat.get_support_unread_count()


@frappe.whitelist()
def mark_support_ticket_read(ticket_id=None, name=None):
    resolved_id = ticket_id or name
    if not resolved_id:
        frappe.throw("ticket_id is required")

    ticket, user, profile = _load_accessible_ticket(resolved_id)
    support_chat._ensure_initial_message_record(ticket)

    message_filters = support_chat._support_message_read_filters(user, profile)
    if not message_filters:
        return {"updated": 0}

    message_filters["support_ticket"] = ticket.name
    message_names = frappe.get_all(
        support_chat.SUPPORT_MESSAGE_DOCTYPE,
        filters=message_filters,
        pluck="name",
    )
    if not message_names:
        return {"updated": 0}

    read_field = (
        "read_by_staff"
        if support_chat._can_access_internal_workspace(user)
        else "read_by_customer"
    )

    updated = 0
    for message_name in message_names:
        if not frappe.db.exists(support_chat.SUPPORT_MESSAGE_DOCTYPE, message_name):
            continue
        frappe.db.set_value(
            support_chat.SUPPORT_MESSAGE_DOCTYPE,
            message_name,
            read_field,
            1,
            update_modified=False,
        )
        updated += 1

    if updated:
        frappe.db.commit()
    return {"updated": updated}
