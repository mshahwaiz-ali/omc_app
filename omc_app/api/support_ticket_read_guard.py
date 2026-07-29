from __future__ import annotations

import frappe

from omc_app.api import support_chat


def _ticket_not_found():
    frappe.throw("Support ticket not found", frappe.DoesNotExistError)


def _load_ticket(ticket_id):
    if not ticket_id or not frappe.db.exists("OMC Support Ticket", ticket_id):
        _ticket_not_found()
    return frappe.get_doc("OMC Support Ticket", ticket_id)


def _sanitize_ticket_payload(payload