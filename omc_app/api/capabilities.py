from __future__ import annotations

import frappe
from frappe.utils import get_datetime, now_datetime

from omc_app.api import identity


INTERNAL_CAPABILITY_KEYS = (
    "can_access_internal_workspace", "can_manage_customers", "can_view_all_customers",
    "can_view_relevant_customers", "can_manage_leads", "can_manage_tasks",
    "can_manage_assigned_tasks", "can_view_all_service_cases",
    "can_view_relevant_service_cases", "can_view_assigned_service_cases",
    "can_create_service_for_customer", "can_update_service_status",
    "can_update_assigned_service_status", "can_view_document_queue",
    "can_view_document_summaries", "can_view_document_attachments",
    "can_review_documents", "can_view_payment_queue", "can_view_payment_summaries",
    "can_view_payment_receipts", "can_review_payments", "can_reconcile_settlement",
    "can_approve_post_paid", "can_view_support_tickets", "can_reply_support_tickets",
    "can_update_support_ticket_status", "can_assign_support_tickets",
    "can_view_internal_notes", "can_manage_settings", "can_manage_staff",
    "can_review_registrations", "can_manage_business_settings",
    "can_reassign_service_cases", "can_retry_sync", "can_view_referral_commissions",
    "can_approve_commissions", "can_mark_commissions_paid",
)

CUSTOMER_KEYS = (
    "can_view_public_catalogue", "can_view_public_content", "can_use_tax_calculator",
    "can_create_service_request", "can_upload_documents", "can_track_requests",
    "can_view_documents", "can_view_payments", "can_upload_payment_receipt",
    "can_upload_payment_receipts", "can_create_support_ticket",
    "can_view_customer_dashboard", "can_access_customer_dashboard",
    "can_view_customer_notifications",
)


def _base(*, access_state: str, is_guest: bool = False) -> dict:
    values = {
        "access_state": access_state,
        "is_guest": is_guest,
        "is_pending": access_state == "pending",
        "is_approved_customer": access_state == "approved",
    }
    values.update({key: False for key in CUSTOMER_KEYS + INTERNAL_CAPABILITY_KEYS})
    values["can_view_public_catalogue"] = True
    values["can_view_public_content"] = True
    values["can_use_tax_calculator"] = True
    return values


def _active_break_glass(
    user: str,
    *,
    scope_doctype: str = "",
    scope_name: str = "",
) -> set[str]:
    if not frappe.db.exists("DocType", "OMC Break Glass Grant"):
        return set()
    rows = frappe.get_all(
        "OMC Break Glass Grant",
        filters={"user": user, "revoked": 0, "expires_at": [">", now_datetime()]},
        fields=["capability", "expires_at", "scope_doctype", "scope_name"],
        limit_page_length=100,
    )
    return {
        str(row.capability or "").strip()
        for row in rows
        if (
            row.expires_at
            and get_datetime(row.expires_at) > now_datetime()
            and (
                (not row.scope_doctype and not row.scope_name)
                or (
                    scope_doctype
                    and row.scope_doctype == scope_doctype
                    and (not row.scope_name or row.scope_name == scope_name)
                )
            )
        )
    }


def effective(user: str | None = None) -> dict:
    user = str(user or identity.current_user(required=False) or "Guest").strip()
    if user == "Guest":
        return _base(access_state="guest", is_guest=True)
    if not identity.user_is_enabled(user):
        return _base(access_state="blocked")
    if user == "Administrator":
        values = _base(access_state="internal")
        values.update({key: True for key in INTERNAL_CAPABILITY_KEYS})
        return values

    staff = identity.get_staff_access(user)
    if staff:
        if staff.access_status != "Approved" or staff.reconciliation_status != "Current":
            return _base(access_state="pending")
        enabled = {
            str(row.capability or "").strip()
            for row in staff.capabilities or []
            if str(row.capability or "").strip() in INTERNAL_CAPABILITY_KEYS
        }
        enabled.update(_active_break_glass(user).intersection(INTERNAL_CAPABILITY_KEYS))
        values = _base(access_state="internal")
        values.update({key: key in enabled for key in INTERNAL_CAPABILITY_KEYS})
        values["can_access_internal_workspace"] = bool(enabled)
        return values

    account = identity.get_customer_account(user)
    if not account:
        return _base(access_state="pending")
    approved = (
        account.identity_proof_status == "Verified"
        and account.account_link_status == "Linked"
        and account.service_access_status == "Approved"
    )
    values = _base(access_state="approved" if approved else "pending")
    if approved:
        for key in (
            "can_create_service_request", "can_upload_documents", "can_track_requests",
            "can_view_documents", "can_view_payments", "can_upload_payment_receipt",
            "can_upload_payment_receipts", "can_create_support_ticket",
            "can_view_customer_dashboard", "can_access_customer_dashboard",
            "can_view_customer_notifications",
        ):
            values[key] = True
    return values


def require(capability: str, *, user: str | None = None) -> dict:
    values = effective(user)
    if not values.get(capability):
        frappe.throw("You do not have permission to perform this action.", frappe.PermissionError)
    return values


def require_scoped(
    capability: str,
    *,
    target_doctype: str,
    target_name: str = "",
    user: str | None = None,
) -> dict:
    user = str(user or identity.current_user()).strip()
    values = effective(user)
    if values.get(capability):
        return values
    staff = identity.get_staff_access(user)
    scoped = _active_break_glass(
        user,
        scope_doctype=str(target_doctype or "").strip(),
        scope_name=str(target_name or "").strip(),
    )
    if not (
        staff
        and staff.access_status == "Approved"
        and staff.reconciliation_status == "Current"
        and capability in scoped
    ):
        frappe.throw("You do not have permission to perform this action.", frappe.PermissionError)
    return {**values, capability: True}
