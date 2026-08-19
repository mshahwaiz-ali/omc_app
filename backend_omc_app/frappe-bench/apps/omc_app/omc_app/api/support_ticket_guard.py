from __future__ import annotations

import frappe

from omc_app.api import support_chat

TERMINAL_SUPPORT_STATUSES = {"Closed", "Cancelled"}


def _load_authorized_ticket(ticket_id):
    if not ticket_id or not frappe.db.exists("OMC Support Ticket", ticket_id):
        frappe.throw("Support ticket not found", frappe.DoesNotExistError)

    ticket = frappe.get_doc("OMC Support Ticket", ticket_id)
    user, _profile = support_chat._assert_support_ticket_access(ticket)
    if not support_chat._can_access_internal_workspace(user):
        frappe.throw(
            "You do not have permission to update support tickets.",
            frappe.PermissionError,
        )
    return ticket


def _same_text(current, requested):
    return requested is None or (current or "") == (requested or "")


@frappe.whitelist(methods=["POST"])
def update_support_ticket_status(ticket_id=None, status=None, remarks=None, **kwargs):
    resolved_id = ticket_id or kwargs.get("name")
    ticket = _load_authorized_ticket(resolved_id)
    support_chat._require_capability(
        "can_update_support_ticket_status",
        "You do not have permission to update support ticket status.",
    )

    if (ticket.status or "") == (status or "") and _same_text("", remarks):
        return {
            "updated": False,
            "old_status": ticket.status or "",
            "ticket": support_chat._support_ticket_to_dict(ticket),
            "message": "Support ticket already has this status.",
        }

    return support_chat.update_support_ticket_status(
        ticket_id=resolved_id,
        status=status,
        remarks=remarks,
    )


@frappe.whitelist(methods=["POST"])
def assign_support_ticket(ticket_id=None, assigned_to=None, **kwargs):
    resolved_id = ticket_id or kwargs.get("name")
    resolved_user = (assigned_to or kwargs.get("user") or "").strip()
    ticket = _load_authorized_ticket(resolved_id)
    support_chat._require_capability(
        "can_assign_support_tickets",
        "You do not have permission to assign support tickets.",
    )

    if (ticket.status or "") in TERMINAL_SUPPORT_STATUSES:
        frappe.throw(
            f"Support ticket {ticket.name} is {ticket.status} and cannot be assigned."
        )

    if resolved_user and (ticket.assigned_to or "") == resolved_user:
        return {
            "updated": False,
            "ticket": support_chat._support_ticket_to_dict(ticket),
            "message": f"Ticket is already assigned to {resolved_user}.",
        }

    return support_chat.assign_support_ticket(
        ticket_id=resolved_id,
        assigned_to=resolved_user,
    )
