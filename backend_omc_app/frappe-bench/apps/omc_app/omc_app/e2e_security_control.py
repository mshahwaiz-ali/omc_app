from __future__ import annotations

import os

import frappe
from frappe.utils import now_datetime, time_diff_in_hours

from omc_app.api import capabilities, erp_task_status_sync, payments


def _required_env(name: str) -> str:
    value = str(os.environ.get(name) or "").strip()
    if not value:
        frappe.throw(f"{name} is required for the permissions E2E control actor.")
    return value


def _guard_local_e2e() -> None:
    if str(os.environ.get("OMC_E2E_CONTROL") or "").strip() != "1":
        frappe.throw("OMC_E2E_CONTROL=1 is required for permissions E2E control.")
    site = str(getattr(frappe.local, "site", "") or "").strip().lower()
    if not (site == "localhost" or site.endswith(".local")):
        frappe.throw("Permissions E2E control is restricted to local development sites.")


def _profile_for_user(user: str):
    for filters in (
        {"user": user},
        {"linked_app_user": user},
        {"email": user},
        {"username": user},
    ):
        name = frappe.db.get_value("OMC Customer Profile", filters, "name")
        if name:
            return frappe.get_doc("OMC Customer Profile", name)
    frappe.throw(f"No OMC Customer Profile is linked to E2E customer {user}.")


def _service_name(service_title: str) -> str:
    names = frappe.get_all(
        "OMC Service",
        filters={"title": service_title, "is_active": 1},
        pluck="name",
        limit_page_length=2,
    )
    if len(names) != 1:
        frappe.throw(
            "E2E_SERVICE_TITLE must resolve to exactly one active service for Phase 4."
        )
    return names[0]


def _latest_completed_request(profile_name: str, service_name: str):
    rows = frappe.get_all(
        "OMC Service Request",
        filters={
            "customer_profile": profile_name,
            "service": service_name,
            "status": "Completed",
        },
        fields=["name", "creation"],
        order_by="creation desc",
        limit_page_length=1,
    )
    if not rows:
        frappe.throw(
            "Phase 4 requires the fresh Completed request produced by Phase 3."
        )
    if time_diff_in_hours(now_datetime(), rows[0].creation) > 3:
        frappe.throw(
            "The latest Completed request is older than three hours; refusing stale E2E state."
        )
    request = frappe.get_doc("OMC Service Request", rows[0].name)
    if not request.erp_task or not frappe.db.exists("Task", request.erp_task):
        frappe.throw("Completed E2E request is missing its canonical ERP Task.")
    if not request.erp_service or not frappe.db.exists("Service", request.erp_service):
        frappe.throw("Completed E2E request is missing its canonical ERP Service.")
    if not request.closed_on:
        frappe.throw("Completed E2E request is missing closed_on.")
    return request


def _runtime_context() -> dict:
    _guard_local_e2e()
    primary_user = _required_env("E2E_USERNAME")
    other_user = _required_env("E2E_OTHER_USERNAME")
    service_title = _required_env("E2E_SERVICE_TITLE")

    if primary_user.lower() == other_user.lower():
        frappe.throw("E2E_OTHER_USERNAME must identify a different user.")

    primary_profile = _profile_for_user(primary_user)
    other_profile = _profile_for_user(other_user)
    if primary_profile.name == other_profile.name:
        frappe.throw("Primary and other E2E users resolve to the same customer profile.")

    for user in (primary_user, other_user):
        effective = capabilities.effective(user)
        if not effective.get("can_create_service_request"):
            frappe.throw(f"Phase 4 customer must be approved and active: {user}")
        if effective.get("can_access_internal_workspace"):
            frappe.throw(f"Phase 4 customer unexpectedly has internal workspace access: {user}")
        if effective.get("can_view_tasks"):
            frappe.throw(f"Phase 4 customer unexpectedly has internal Task visibility: {user}")

    service_name = _service_name(service_title)
    request = _latest_completed_request(primary_profile.name, service_name)

    other_owns_request = frappe.db.exists(
        "OMC Service Request",
        {"name": request.name, "customer_profile": other_profile.name},
    )
    if other_owns_request:
        frappe.throw("Cross-customer E2E fixture is invalid: other customer owns primary request.")

    return {
        "primary_user": primary_user,
        "other_user": other_user,
        "primary_profile": primary_profile,
        "other_profile": other_profile,
        "request": request,
    }


def _markers(request) -> str:
    return f"OMC_E2E_REQUEST_ID={request.name}|OMC_E2E_TASK_ID={request.erp_task}"


def preflight() -> str:
    context = _runtime_context()
    return _markers(context["request"])


def assert_terminal_and_idempotency() -> str:
    """Read-only regression assertions for a completed Phase 3 request."""
    context = _runtime_context()
    request = context["request"]

    original = {
        "status": str(request.status or "").strip(),
        "request_state": str(request.request_state or "").strip(),
        "erp_task": str(request.erp_task or "").strip(),
        "erp_service": str(request.erp_service or "").strip(),
        "closed_on": request.closed_on,
    }

    bridge_operations = frappe.get_all(
        "OMC Bridge Operation",
        filters={
            "service_request": request.name,
            "operation_type": "Activate Request",
        },
        fields=["name", "operation_key", "state", "erp_service", "erp_task"],
        order_by="creation asc",
    )
    if len(bridge_operations) != 1:
        frappe.throw(
            f"Exactly-once activation requires one bridge operation; found {len(bridge_operations)}."
        )
    operation = bridge_operations[0]
    if str(operation.state or "").strip() != "Completed":
        frappe.throw(
            f"Canonical activation bridge operation is not Completed: {operation.state}."
        )
    if str(operation.erp_task or "").strip() != original["erp_task"]:
        frappe.throw("Activation bridge Task link differs from the request Task link.")
    if str(operation.erp_service or "").strip() != original["erp_service"]:
        frappe.throw("Activation bridge Service link differs from the request Service link.")

    payment_rows = frappe.get_all(
        payments.PAYMENT_DOCTYPE,
        filters={"service_request": request.name},
        fields=["name", "status"],
        order_by="creation asc",
    )
    if len(payment_rows) != 1:
        frappe.throw(
            f"Payment opening must remain idempotent for the E2E request; found {len(payment_rows)} payments."
        )
    if str(payment_rows[0].status or "").strip() != "Paid":
        frappe.throw(
            f"Completed E2E request lost settled payment state: {payment_rows[0].status}."
        )

    accounting_links = frappe.get_all(
        "OMC Accounting Link",
        filters={"base_request_key": request.name},
        fields=["name", "accounting_status"],
        order_by="creation asc",
    )
    if len(accounting_links) != 1:
        frappe.throw(
            f"Request must have one canonical accounting link; found {len(accounting_links)}."
        )
    if str(accounting_links[0].accounting_status or "").strip() != "Settled":
        frappe.throw("Completed E2E request is no longer accounting-settled.")

    # This synthetic document is deliberately not saved. sync_task_status checks
    # terminal request protection before any ERP/OMC mutation or notification path.
    probe = frappe._dict(
        name=original["erp_task"],
        status="Working",
        custom_operation_status="Pending at Operation Side",
        workflow_state="",
    )
    result = erp_task_status_sync.sync_task_status(probe)
    if result.get("updated") is not False:
        frappe.throw(f"Completed request accepted an ERP reopen projection: {result}")
    reason = str(result.get("reason") or "").lower()
    if "cannot be reopened" not in reason:
        frappe.throw(
            "Completed request did not reject reopen for the canonical terminal-state reason: "
            f"{result}"
        )

    request.reload()
    after = {
        "status": str(request.status or "").strip(),
        "request_state": str(request.request_state or "").strip(),
        "erp_task": str(request.erp_task or "").strip(),
        "erp_service": str(request.erp_service or "").strip(),
        "closed_on": request.closed_on,
    }
    if after != original:
        frappe.throw(
            "Terminal reopen regression probe mutated the completed request: "
            f"before={original}, after={after}"
        )

    return _markers(request)
