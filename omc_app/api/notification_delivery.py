"""Push delivery boundary for durable OMC notifications.

The inbox row is always the source of truth. Push is an optional, after-commit
delivery channel supplied by a site-configured adapter; this app contains no
provider credentials.
"""
from __future__ import annotations

from dataclasses import dataclass

import frappe

MAX_ATTEMPTS = 3


@dataclass(frozen=True)
class PushProviderStatus:
    configured: bool
    operational: bool
    reason: str = ""


def provider_status() -> PushProviderStatus:
    adapter = str(frappe.conf.get("omc_push_provider") or "").strip()
    if not adapter:
        return PushProviderStatus(False, False, "No push provider is configured.")
    return PushProviderStatus(True, True)


def enqueue_notification(notification_name: str) -> bool:
    if not provider_status().operational:
        return False
    frappe.enqueue(
        "omc_app.api.notification_delivery.dispatch_notification",
        notification_name=notification_name,
        attempt=1,
        queue="short",
        enqueue_after_commit=True,
    )
    return True


def dispatch_notification(notification_name: str, attempt: int = 1):
    """Deliver one persisted notification through the configured adapter.

    Adapter result may include ``invalid_tokens``. Transient failures retry a
    bounded number of times; the durable in-app row is never removed.
    """
    if not frappe.db.exists("OMC Notification", notification_name):
        return {"delivered": 0, "reason": "notification-not-found"}
    status = provider_status()
    if not status.operational:
        return {"delivered": 0, "reason": status.reason}

    from omc_app.api import mobile

    notification = frappe.get_doc("OMC Notification", notification_name)
    tokens = mobile._active_push_tokens_for_notification(
        notification.notification_type,
        customer_profile=notification.customer_profile,
        user=notification.recipient_user,
    )
    if not tokens:
        return {"delivered": 0, "reason": "no-active-tokens"}

    adapter = frappe.get_attr(str(frappe.conf.get("omc_push_provider")))
    payload = {
        "title": notification.title,
        "body": notification.message or "",
        "route": notification.mobile_route or "",
        "notification_id": notification.name,
        "reference_doctype": notification.reference_doctype or "",
        "reference_name": notification.reference_name or "",
    }
    try:
        result = adapter(tokens=[row.token for row in tokens], payload=payload) or {}
    except Exception:
        if int(attempt) < MAX_ATTEMPTS:
            frappe.enqueue(
                "omc_app.api.notification_delivery.dispatch_notification",
                notification_name=notification_name,
                attempt=int(attempt) + 1,
                queue="short",
            )
        frappe.log_error(frappe.get_traceback(), "OMC push delivery failed")
        return {"delivered": 0, "retry_scheduled": int(attempt) < MAX_ATTEMPTS}

    invalid = set(result.get("invalid_tokens") or [])
    if invalid:
        for row in tokens:
            if row.token in invalid:
                frappe.db.set_value(
                    "OMC Push Token", row.name, "is_active", 0, update_modified=False
                )
    return {
        "delivered": int(result.get("delivered") or 0),
        "invalid_tokens": len(invalid),
    }
