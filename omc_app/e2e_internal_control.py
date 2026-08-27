from __future__ import annotations

import os

import frappe
from frappe.utils import now_datetime, time_diff_in_hours

from omc_app.api import capabilities, service_document_guard, workflow_automation


def _required_env(name: str) -> str:
    value = str(os.environ.get(name) or "").strip()
    if not value:
        frappe.throw(f"{name} is required for the internal E2E control actor.")
    return value


def _guard_local_e2e() -> None:
    if str(os.environ.get("OMC_E2E_CONTROL") or "").strip() != "1":
        frappe.throw("OMC_E2E_CONTROL=1 is required for the internal E2E control actor.")
    site = str(getattr(frappe.local, "site", "") or "").strip().lower()
    if not (site == "localhost" or site.endswith(".local")):
        frappe.throw("Internal E2E control is restricted to local development sites.")


def _profile_name(customer_user: str) -> str:
    for filters in (
        {"user": customer_user},
        {"linked_app_user": customer_user},
        {"email": customer_user},
        {"username": customer_user},
    ):
        name = frappe.db.get_value("OMC Customer Profile", filters, "name")
        if name:
            return name
    frappe.throw(f"No OMC Customer Profile is linked to {customer_user}.")


def _service_name(service_title: str) -> str:
    names = frappe.get_all(
        "OMC Service",
        filters={"title": service_title, "is_active": 1},
        pluck="name",
        limit_page_length=2,
    )
    if len(names) != 1:
        frappe.throw(
            "E2E_SERVICE_TITLE must resolve to exactly one active service for Phase 3."
        )
    return names[0]


def _latest_activated_request(customer_user: str, service_title: str):
    profile_name = _profile_name(customer_user)
    service_name = _service_name(service_title)
    rows = frappe.get_all(
        "OMC Service Request",
        filters={
            "customer_profile": profile_name,
            "service": service_name,
            "request_state": "Activated",
        },
        fields=["name", "creation"],
        order_by="creation desc",
        limit_page_length=1,
    )
    if not rows:
        frappe.throw(
            "Phase 3 needs a fresh Activated request from Phase 2; none was found."
        )
    if time_diff_in_hours(now_datetime(), rows[0].creation) > 2:
        frappe.throw(
            "The latest Activated request is older than two hours; refusing stale E2E state."
        )

    request = frappe.get_doc("OMC Service Request", rows[0].name)
    if not request.erp_task or not frappe.db.exists("Task", request.erp_task):
        frappe.throw("Activated E2E request is missing its real ERP Task.")
    if not request.erp_service or not frappe.db.exists("Service", request.erp_service):
        frappe.throw("Activated E2E request is missing its real ERP Service.")
    accounting_status = frappe.db.get_value(
        "OMC Accounting Link",
        {"service_request": request.name},
        "accounting_status",
    )
    if accounting_status != "Settled":
        frappe.throw(
            f"Phase 3 requires the Phase 2 request to remain Settled; got {accounting_status}."
        )
    return request


def _runtime_context() -> dict:
    _guard_local_e2e()
    customer_user = _required_env("E2E_USERNAME")
    service_title = _required_env("E2E_SERVICE_TITLE")
    internal_user = _required_env("E2E_INTERNAL_USERNAME")

    if not frappe.db.exists("User", internal_user):
        frappe.throw(f"Internal E2E user does not exist: {internal_user}")
    if not frappe.db.get_value("User", internal_user, "enabled"):
        frappe.throw(f"Internal E2E user is disabled: {internal_user}")

    internal_caps = capabilities.effective(internal_user)
    for capability in ("can_view_tasks", "can_review_documents"):
        if not internal_caps.get(capability):
            frappe.throw(
                f"Internal E2E user requires capability {capability}: {internal_user}"
            )
    if not frappe.has_permission("Task", "write", user=internal_user):
        frappe.throw(
            "Internal E2E user must have ERPNext Task write permission because Task writes "
            "are intentionally not exposed by Flutter."
        )

    request = _latest_activated_request(customer_user, service_title)
    task = frappe.get_doc("Task", request.erp_task)

    assigned_users = set(
        frappe.get_all(
            "ToDo",
            filters={
                "reference_type": "Task",
                "reference_name": task.name,
                "status": ["not in", ["Closed", "Cancelled"]],
            },
            pluck="allocated_to",
        )
    )
    request_assignee = str(request.assigned_staff or "").strip()
    task_user = str(getattr(task, "user_link", None) or "").strip()
    if not assigned_users and not request_assignee and not task_user:
        frappe.throw(
            "Activated E2E Task has no staff assignment. Phase 3 does not accept an unassigned work item."
        )

    return {
        "customer_user": customer_user,
        "service_title": service_title,
        "internal_user": internal_user,
        "request": request,
        "task": task,
    }


def _markers(request, task) -> str:
    return f"OMC_E2E_REQUEST_ID={request.name}|OMC_E2E_TASK_ID={task.name}"


def preflight() -> str:
    context = _runtime_context()
    return _markers(context["request"], context["task"])


def _approve_uploaded_documents(request_name: str) -> int:
    documents = frappe.get_all(
        "OMC Service Document",
        filters={"service_request": request_name},
        fields=["name", "status", "attachment"],
        order_by="creation asc",
    )
    if not documents:
        frappe.throw("Phase 3 expected real service documents from Phase 2, but none exist.")

    approved = 0
    for row in documents:
        if not str(row.attachment or "").strip():
            frappe.throw(f"Service document {row.name} has no uploaded attachment.")
        if str(row.status or "").strip() == "Approved":
            continue
        service_document_guard.update_service_document_status(
            document_id=row.name,
            status="Approved",
            remarks="OMC E2E internal review approved the uploaded document.",
        )
        approved += 1
    return approved


def _operation_options(task) -> set[str]:
    field = frappe.get_meta("Task").get_field("custom_operation_status")
    if not field or not getattr(field, "options", None):
        return set()
    return {
        value.strip()
        for value in str(field.options).splitlines()
        if value.strip()
    }


def _save_task(task, *, status: str | None = None, operation_status: str | None = None):
    if status is not None:
        task.status = status
    if operation_status is not None:
        task.custom_operation_status = operation_status
    task.save()
    frappe.db.commit()
    task.reload()


def _assert_request_status(request_name: str, expected: str, step: str) -> None:
    actual = str(
        frappe.db.get_value("OMC Service Request", request_name, "status") or ""
    ).strip()
    if actual != expected:
        frappe.throw(
            f"{step} did not propagate to customer status {expected}; got {actual}."
        )


def _precompletion_blockers(request) -> list[str]:
    return [
        blocker
        for blocker in workflow_automation.completion_blockers(request)
        if blocker != "Operational ERP Task is not complete."
    ]


def _assert_completed_evidence(request, task) -> None:
    request.reload()
    task.reload()
    if str(task.status or "").strip() != "Completed":
        frappe.throw("Completed E2E request does not retain a completed ERP Task.")
    if str(request.status or "").strip() != "Completed":
        frappe.throw("Completed ERP Task did not retain customer status Completed.")
    if request.request_state != "Activated":
        frappe.throw(
            "Completing ERP work must not rewrite the payment-first activation state; "
            f"got {request.request_state}."
        )
    if request.erp_task != task.name:
        frappe.throw("Task completion changed the canonical ERP Task link unexpectedly.")
    if not request.closed_on:
        frappe.throw("Completed E2E request did not record closed_on.")

    service_status_field = frappe.get_meta("Service").get_field("status")
    if not service_status_field:
        return
    allowed_service_statuses = {
        value.strip()
        for value in str(getattr(service_status_field, "options", "") or "").splitlines()
        if value.strip()
    }
    if "Completed" not in allowed_service_statuses:
        return
    erp_service_status = str(
        frappe.db.get_value("Service", request.erp_service, "status") or ""
    ).strip()
    if erp_service_status != "Completed":
        frappe.throw(
            "ERP Task completion did not propagate Completed to the linked ERP Service."
        )


def approve_documents_and_complete_work() -> str:
    context = _runtime_context()
    request = context["request"]
    task = context["task"]

    frappe.set_user(context["internal_user"])
    _approve_uploaded_documents(request.name)

    task.reload()
    request.reload()
    task_completed = str(task.status or "").strip() == "Completed"
    request_completed = str(request.status or "").strip() == "Completed"
    if task_completed or request_completed:
        if not (task_completed and request_completed):
            frappe.throw(
                "Phase 3 found inconsistent terminal ERP Task and customer request states."
            )
        _assert_completed_evidence(request, task)
        return _markers(request, task)

    options = _operation_options(task)
    working_operation = next(
        (
            value
            for value in (
                "Pending at Operation Side",
                "Pending at Tax Associate",
            )
            if value in options
        ),
        None,
    )
    if working_operation is None:
        field = frappe.get_meta("Task").get_field("custom_operation_status")
        if field and not getattr(field, "reqd", 0):
            task.custom_operation_status = None

    _save_task(task, status="Working", operation_status=working_operation)
    _assert_request_status(request.name, "In Progress", "ERP Task Working")

    if "Pending at Client" in options:
        _save_task(task, status="Working", operation_status="Pending at Client")
        _assert_request_status(
            request.name,
            "Waiting for Customer",
            "ERP operation Pending at Client",
        )
        if working_operation:
            _save_task(task, status="Working", operation_status=working_operation)
            _assert_request_status(
                request.name,
                "In Progress",
                "ERP work resumed after customer wait",
            )

    request.reload()
    blockers = _precompletion_blockers(request)
    if blockers:
        frappe.throw(
            "Phase 3 cannot complete the ERP Task because real workflow blockers remain: "
            + " ".join(blockers)
        )

    final_operation = "Submitted by QC" if "Submitted by QC" in options else None
    _save_task(task, status="Completed", operation_status=final_operation)
    _assert_request_status(request.name, "Completed", "ERP Task completion")
    _assert_completed_evidence(request, task)

    return _markers(request, task)
