from __future__ import annotations

import frappe

from omc_app.api import access, dashboard_scope, security


def _has_service_scope(capabilities: dict) -> bool:
    return any(
        bool(capabilities.get(name))
        for name in dashboard_scope.SERVICE_VIEW_CAPABILITIES
    )


def _my_service_performance(user: str, capabilities: dict) -> dict[str, int]:
    if not _has_service_scope(capabilities):
        return {
            "my_assigned_services": 0,
            "my_active_services": 0,
            "my_completed_services": 0,
            "my_completed_this_month": 0,
        }

    today = frappe.utils.getdate()
    month_start = today.replace(day=1)
    return {
        "my_assigned_services": frappe.db.count(
            "OMC Service Request",
            {"assigned_staff": user},
        ),
        "my_active_services": frappe.db.count(
            "OMC Service Request",
            {
                "assigned_staff": user,
                "status": ["not in", ["Completed", "Cancelled"]],
            },
        ),
        "my_completed_services": frappe.db.count(
            "OMC Service Request",
            {"completed_by": user, "status": "Completed"},
        ),
        "my_completed_this_month": frappe.db.count(
            "OMC Service Request",
            {
                "completed_by": user,
                "status": "Completed",
                "closed_on": [">=", month_start],
            },
        ),
    }


@frappe.whitelist()
def get_internal_workspace_summary():
    """Return a capability-scoped summary for the Flutter staff home.

    The legacy mobile implementation returned global business counts to every
    approved internal identity. This reader deliberately reuses the canonical
    permission-query-backed dashboard scope and fails closed for domains the
    caller cannot view.
    """
    user = getattr(getattr(frappe, "session", None), "user", None) or "Guest"
    if user == "Guest" or not access.can_access_internal_workspace(user):
        frappe.throw(
            "Internal workspace access requires an active and approved OMC staff profile.",
            frappe.PermissionError,
        )

    capabilities = access.get_mobile_capabilities(user=user)
    if not capabilities.get("can_access_internal_workspace"):
        frappe.throw(
            "You do not have permission to access the internal workspace.",
            frappe.PermissionError,
        )

    security.enforce_rate_limit("authenticated_list")

    lifecycle = dashboard_scope._service_lifecycle(user, capabilities)
    documents = dashboard_scope._document_summary(user, capabilities)
    payments = dashboard_scope._payment_summary(user, capabilities)
    support = dashboard_scope._support_summary(user, capabilities)
    operations = dashboard_scope._operations_summary(
        user,
        capabilities,
        lifecycle,
        documents,
        payments,
    )
    performance = _my_service_performance(user, capabilities)

    open_leads = int(operations.get("open_leads") or 0)
    active_customers = int(operations.get("active_customers") or 0)
    pending_tasks = int(operations.get("pending_tasks") or 0)
    pending_payments = int(operations.get("pending_payments") or 0)

    return {
        # Canonical Flutter summary keys.
        "open_leads": open_leads,
        "active_customers": active_customers,
        "pending_tasks": pending_tasks,
        "pending_payments": pending_payments,
        **performance,
        # Scoped operational context used by current/future internal homes.
        "open_services": int(lifecycle.get("active") or 0),
        "active_services": int(lifecycle.get("active") or 0),
        "waiting_customer": int(lifecycle.get("waiting_customer") or 0),
        "documents": int(documents.get("total") or 0),
        "documents_waiting_review": int(
            operations.get("documents_waiting_review") or 0
        ),
        "payments_due": int(payments.get("payments_due") or 0),
        "support_tickets": int(support.get("open") or 0),
        # Internal notification authority is not canonical yet; fail closed.
        "unread_notifications": 0,
        # Backward-compatible aliases now carry the same scoped values.
        "leads": open_leads,
        "customers": active_customers,
        "tasks": pending_tasks,
        "scope": "capability",
    }
