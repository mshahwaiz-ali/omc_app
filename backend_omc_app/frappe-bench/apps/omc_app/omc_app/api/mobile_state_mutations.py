from __future__ import annotations

import frappe

from omc_app.api import mobile, payment_mutation_guard, security


def _actor() -> str:
    return str(getattr(getattr(frappe, "session", None), "user", None) or "Guest").strip()


def _limit() -> None:
    security.enforce_rate_limit("customer_mutation", actor=_actor())


@frappe.whitelist(methods=["POST"])
def mark_notification_read(notification_id=None, name=None):
    _limit()
    return mobile.mark_notification_read(notification_id=notification_id, name=name)


@frappe.whitelist(methods=["POST"])
def mark_notification_unread(notification_id=None, name=None):
    _limit()
    return mobile.mark_notification_unread(notification_id=notification_id, name=name)


@frappe.whitelist(methods=["POST"])
def mark_all_notifications_read():
    _limit()
    return mobile.mark_all_notifications_read()


@frappe.whitelist(methods=["POST"])
def dismiss_notification(notification_id=None, name=None):
    _limit()
    return mobile.dismiss_notification(notification_id=notification_id, name=name)


@frappe.whitelist(methods=["POST"])
def restore_notification(notification_id=None, name=None):
    _limit()
    return mobile.restore_notification(notification_id=notification_id, name=name)


@frappe.whitelist(methods=["POST"])
def register_push_token(**kwargs):
    _limit()
    return mobile.register_push_token(**kwargs)


@frappe.whitelist(methods=["POST"])
def unregister_push_token(**kwargs):
    _limit()
    return mobile.unregister_push_token(**kwargs)


@frappe.whitelist(methods=["POST"])
def update_settings_preferences(**kwargs):
    _limit()
    return mobile.update_settings_preferences(**kwargs)


@frappe.whitelist(methods=["POST"])
def upload_payment_receipt(**kwargs):
    """Retain the legacy method name without accepting unverified file URLs."""
    _limit()
    payment_id = kwargs.get("payment_id") or kwargs.get("name")
    file_name = kwargs.get("file_name")
    content_base64 = kwargs.get("content_base64")
    if not file_name or not content_base64:
        frappe.throw(
            "Direct receipt file references are retired. Upload receipt bytes through the secure payment upload endpoint.",
            frappe.ValidationError,
        )
    return payment_mutation_guard.upload_payment_receipt_file(
        payment_id=payment_id,
        name=kwargs.get("name"),
        file_name=file_name,
        content_base64=content_base64,
        payment_reference=kwargs.get("payment_reference"),
        remarks=kwargs.get("remarks"),
        idempotency_key=kwargs.get("idempotency_key"),
    )
