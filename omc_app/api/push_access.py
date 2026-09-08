"""Bound push reads reuse existing notification and referenced-record authority."""
import re

import frappe


def assert_bound_push_access(notification, binding_id):
    user = frappe.session.user
    if user == "Guest" or not re.fullmatch(r"[a-f0-9]{32}", str(binding_id or "")):
        frappe.throw("Notification is no longer available", frappe.PermissionError)
    active_binding = frappe.db.exists("OMC Push Token", {
        "user": user, "binding_id": binding_id, "is_active": 1, "platform": "android",
    })
    if not active_binding:
        frappe.throw("Notification is no longer available", frappe.PermissionError)
    if notification.get("expires_on") and (
        frappe.utils.get_datetime(notification.expires_on) <= frappe.utils.now_datetime()
    ):
        frappe.throw("Notification is no longer available", frappe.DoesNotExistError)
    # No in-app eligibility filter: push-only records must remain resolvable.
    # This helper reuses the same canonical target getters as the dispatcher.
    from omc_app.api.push_delivery import _authorized
    if not _authorized(notification, user):
        frappe.throw("Notification is no longer available", frappe.PermissionError)
