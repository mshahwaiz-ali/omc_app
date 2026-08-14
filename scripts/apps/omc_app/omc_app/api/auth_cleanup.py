from __future__ import annotations

from datetime import timedelta

import frappe
from frappe.utils import get_datetime, now_datetime

from omc_app.api import pending_registration


BATCH_SIZE = 200
VERIFIED_RECOVERY_HOURS = 2


def _documents(filters: dict):
    names = frappe.get_all(
        pending_registration.PENDING_REGISTRATION_DOCTYPE,
        filters=filters,
        pluck="name",
        order_by="modified asc",
        limit=BATCH_SIZE,
    )
    return [
        frappe.get_doc(pending_registration.PENDING_REGISTRATION_DOCTYPE, name)
        for name in names
    ]


def _has_secret(doc) -> bool:
    return bool(doc.get_password("password_secret", raise_exception=False))


def cleanup_pending_registrations() -> dict[str, int]:
    """Sanitize expired and historical pending-registration secrets.

    Recent Verified rows are retained briefly so a failed activation can be retried.
    The job is bounded and idempotent for safe hourly execution.
    """
    now = now_datetime()
    counts = {"expired": 0, "finalized": 0, "sanitized": 0}

    for doc in _documents(
        {"status": "Pending", "expires_at": ["<=", now]}
    ):
        pending_registration.sanitize_registration(doc, status="Expired")
        doc.save(ignore_permissions=True)
        counts["expired"] += 1

    recovery_cutoff = now - timedelta(hours=VERIFIED_RECOVERY_HOURS)
    for doc in _documents(
        {"status": "Verified", "verified_at": ["<=", recovery_cutoff]}
    ):
        user_exists = frappe.db.exists("User", doc.email)
        profile_exists = frappe.db.exists(
            "OMC Customer Profile", {"email": doc.email}
        )
        if user_exists and profile_exists:
            doc.activated_user = doc.email
            pending_registration.sanitize_registration(doc, status="Activated")
            counts["finalized"] += 1
        else:
            pending_registration.sanitize_registration(doc, status="Expired")
            counts["expired"] += 1
        doc.save(ignore_permissions=True)

    for doc in _documents(
        {"status": ["in", list(pending_registration.TERMINAL_STATUSES)]}
    ):
        if _has_secret(doc) or doc.payload_json != pending_registration._sanitized_payload(doc):
            pending_registration.sanitize_registration(doc)
            doc.save(ignore_permissions=True)
            counts["sanitized"] += 1

    frappe.db.commit()
    return counts
