"""Paid service-request operational activation.

A service request remains intake-only until a confirmed Paid payment exists.
This module never commits; callers own transaction boundaries.
"""

from __future__ import annotations

from typing import Any

import frappe

from omc_app.api import (
    erp_service_task_adapter,
    mobile,
    service_assignment,
)


PAYMENT_DOCTYPE = "OMC Service Payment"


def _text(value: Any) -> str:
    return str(value or "").strip()


def _paid_payment(service_request: str):
    rows = frappe.get_all(
        PAYMENT_DOCTYPE,
        filters={
            "service_request": service_request,
            "status": "Paid",
            "visible_to_customer": 1,
        },
        fields=["name"],
        order_by="modified desc, creation desc",
        limit=1,
    )
    return rows[0].name if rows else ""


def _resolve_profile(request):
    profile_name = _text(getattr(request, "customer_profile", None))
    if profile_name and frappe.db.exists("OMC Customer Profile", profile_name):
        return frappe.get_doc("OMC Customer Profile", profile_name)
    return None


def _resolve_manual_customer(request):
    manual_name = _text(getattr(request, "manual_customer", None))
    if manual_name and frappe.db.exists("OMC Manual Customer", manual_name):
        return frappe.get_doc("OMC Manual Customer", manual_name)
    return None


def activate_paid_request(service_request):
    """Activate a paid request exactly through the canonical operational path."""
    request = (
        frappe.get_doc("OMC Service Request", service_request)
        if isinstance(service_request, str)
        else service_request
    )

    status = _text(getattr(request, "status", None))
    if status in {"Completed", "Cancelled"}:
        frappe.throw(
            f"A {status.lower()} service request cannot be activated.",
            frappe.ValidationError,
        )

    payment_name = _paid_payment(request.name)
    if not payment_name:
        frappe.throw(
            "Operational activation requires a confirmed Paid payment.",
            frappe.ValidationError,
        )

    service_name = _text(getattr(request, "service", None))
    if not service_name or not frappe.db.exists("OMC Service", service_name):
        frappe.throw(
            "The linked OMC Service is missing.",
            frappe.ValidationError,
        )

    service = frappe.get_doc("OMC Service", service_name)
    profile = _resolve_profile(request)
    manual_customer = _resolve_manual_customer(request)

    # Resolve assignment only when a valid assignee is not already present.
    current_assignee = _text(getattr(request, "assigned_staff", None))
    if current_assignee and service_assignment.active_assignable_user(current_assignee):
        assignment_decision = {
            "candidate": current_assignee,
            "source": "existing",
            "role": "",
            "rejected": [],
        }
    else:
        assignment_decision = service_assignment.resolve_assignee(
            service,
            referral_owner=_text(getattr(request, "referral_owner", None)),
        )

    assignee = _text(assignment_decision.get("candidate"))
    if not assignee:
        frappe.throw(
            assignment_decision.get("reason")
            or "No eligible operational staff member is available.",
            frappe.ValidationError,
        )

    # Set the request assignee before ERP sync so the ERP Task assignment
    # is created through the canonical adapter.
    request.assigned_staff = assignee
    frappe.db.set_value(
        "OMC Service Request",
        request.name,
        "assigned_staff",
        assignee,
        update_modified=False,
    )

    sync_result = erp_service_task_adapter.sync_request(
        request,
        service=service,
        profile=profile,
        manual_customer=manual_customer,
        repair=True,
    )

    if _text(sync_result.get("status")) != "Synced":
        frappe.throw(
            sync_result.get("reason")
            or "ERP Service/Task synchronization did not complete.",
            frappe.ValidationError,
        )

    # Reload ERP links written by the adapter before applying the OMC
    # Service Request assignment/ToDo.
    request.reload()

    assignment_result = service_assignment.apply_assignment(
        request,
        assignment_decision,
    )

    transitioned = False
    if _text(request.status) != "In Progress":
        request.status = "In Progress"
        request.save(ignore_permissions=True)
        transitioned = True

        mobile._create_service_timeline_entry(
            service_request=request.name,
            event_type="Status Updated",
            title="Work Started",
            description=(
                "Payment has been confirmed and the service request "
                "has entered operational processing."
            ),
            visible_to_customer=1,
        )

    return {
        "activated": True,
        "already_active": not transitioned,
        "payment": payment_name,
        "assigned_staff": assignee,
        "assignment_todo": assignment_result.get("todo"),
        "erp_sync_status": sync_result.get("status") or "",
        "erp_customer": sync_result.get("erp_customer") or "",
        "erp_service": sync_result.get("erp_service") or "",
        "erp_task": sync_result.get("erp_task") or "",
        "erp_task_assignment": (
            assignment_result.get("erp_task_assignment")
            or sync_result.get("task_assignment")
        ),
        "case_status": request.status,
    }
