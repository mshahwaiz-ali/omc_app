"""Manager-only recovery APIs for unresolved ERP Service/Task synchronization."""
from __future__ import annotations

import frappe

from omc_app.api import erp_service_task_adapter
from omc_app.setup.roles import ADMIN_ROLE, MANAGER_ROLE, SYSTEM_ROLE

RECOVERY_ROLES = {ADMIN_ROLE, MANAGER_ROLE, SYSTEM_ROLE}
RETRYABLE_STATUSES = {"Pending Configuration", "Repair Required", "Failed"}


def _text(value) -> str:
    return str(value or "").strip()


def _assert_recovery_manager() -> str:
    user = _text(getattr(getattr(frappe, "session", None), "user", None))
    if not user or user == "Guest":
        frappe.throw("Login is required.", frappe.PermissionError)
    if not set(frappe.get_roles(user) or []).intersection(RECOVERY_ROLES):
        frappe.throw(
            "Only OMC managers may repair ERP synchronization.",
            frappe.PermissionError,
        )
    return user


def _bounded_int(value, *, default: int, minimum: int, maximum: int) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        parsed = default
    return min(max(parsed, minimum), maximum)


def _profile_for_request(request):
    name = _text(getattr(request, "customer_profile", None))
    if name and frappe.db.exists("OMC Customer Profile", name):
        return frappe.get_doc("OMC Customer Profile", name)
    return None


def _manual_customer_for_request(request):
    name = _text(getattr(request, "manual_customer", None))
    if name and frappe.db.exists("OMC Manual Customer", name):
        return frappe.get_doc("OMC Manual Customer", name)
    return None


@frappe.whitelist()
def get_erp_sync_issues(limit_start=0, limit_page_length=50):
    """Return a bounded manager-only queue of unresolved synchronization records."""
    _assert_recovery_manager()
    start = _bounded_int(limit_start, default=0, minimum=0, maximum=1_000_000)
    page_length = _bounded_int(
        limit_page_length,
        default=50,
        minimum=1,
        maximum=200,
    )
    filters = {"erp_sync_status": ["in", sorted(RETRYABLE_STATUSES)]}
    rows = frappe.get_all(
        "OMC Service Request",
        filters=filters,
        fields=[
            "name",
            "title",
            "status",
            "service",
            "customer_profile",
            "manual_customer",
            "assigned_staff",
            "erp_sync_status",
            "erp_sync_error",
            "erp_customer",
            "erp_service",
            "erp_task",
            "modified",
        ],
        order_by="modified asc, name asc",
        limit_start=start,
        limit_page_length=page_length,
    )
    return {
        "issues": [dict(row) for row in rows],
        "count": len(rows),
        "total": frappe.db.count("OMC Service Request", filters=filters),
        "limit_start": start,
        "limit_page_length": page_length,
    }


@frappe.whitelist(methods=["POST"])
def retry_erp_sync(request_name=None):
    """Retry one unresolved request without duplicating valid ERP records."""
    actor = _assert_recovery_manager()
    request_name = _text(request_name)
    if not request_name:
        frappe.throw("request_name is required.", frappe.ValidationError)
    if not frappe.db.exists("OMC Service Request", request_name):
        frappe.throw("Service request not found.", frappe.DoesNotExistError)

    request = frappe.get_doc("OMC Service Request", request_name)
    current_status = _text(getattr(request, "erp_sync_status", None))
    if current_status not in RETRYABLE_STATUSES | {"Synced"}:
        frappe.throw(
            f"ERP synchronization cannot be retried from status {current_status or 'Unset'}.",
            frappe.ValidationError,
        )

    service_name = _text(getattr(request, "service", None))
    if not service_name or not frappe.db.exists("OMC Service", service_name):
        frappe.throw(
            "The linked OMC Service is missing; synchronization cannot be repaired.",
            frappe.ValidationError,
        )

    result = erp_service_task_adapter.sync_request(
        request,
        service=frappe.get_doc("OMC Service", service_name),
        profile=_profile_for_request(request),
        manual_customer=_manual_customer_for_request(request),
        repair=True,
    )
    frappe.logger("omc_app").info(
        "ERP sync retry for %s by %s finished with %s",
        request.name,
        actor,
        result.get("status"),
    )
    frappe.db.commit()
    return {"request_name": request.name, **result}
