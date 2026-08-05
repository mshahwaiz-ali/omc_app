"""Canonical ERP Service/Task bridge for OMC service requests.

OMC Service Request remains the mobile/customer authority. ERP records are
created only when an ERP Customer link and ERP Task Type mapping exist.
This module never commits the database transaction.
"""
from __future__ import annotations

from typing import Any

import frappe

from omc_app.api import erp_customer_resolver


def _text(value: Any) -> str:
    return str(value or "").strip()


def _set_if_field(doc, fieldname: str, value: Any) -> None:
    if value not in (None, "") and doc.meta.get_field(fieldname):
        doc.set(fieldname, value)


def _set_request_state(request, *, status: str, customer="", service="", task="", error="") -> None:
    values = {
        "erp_sync_status": status,
        "erp_customer": customer or None,
        "erp_service": service or None,
        "erp_task": task or None,
        "erp_sync_error": error[:1000] if error else None,
    }
    for fieldname, value in values.items():
        if request.meta.get_field(fieldname):
            request.set(fieldname, value)
            frappe.db.set_value(
                request.doctype,
                request.name,
                fieldname,
                value,
                update_modified=False,
            )


def _linked_customer(profile) -> str:
    result = erp_customer_resolver.resolve_profile_customer(profile)
    return _text(result.get("customer"))


def _customer_user(customer: str) -> str:
    if not frappe.get_meta("Customer").get_field("user_link"):
        return ""
    return _text(frappe.db.get_value("Customer", customer, "user_link"))


def _existing_result(request):
    erp_service = _text(getattr(request, "erp_service", None))
    erp_task = _text(getattr(request, "erp_task", None))

    if not erp_service and not erp_task:
        return None

    service_exists = bool(
        erp_service and frappe.db.exists("Service", erp_service)
    )
    task_exists = bool(
        erp_task and frappe.db.exists("Task", erp_task)
    )

    if erp_service and erp_task and service_exists and task_exists:
        return {
            "status": "Synced",
            "erp_customer": _text(
                getattr(request, "erp_customer", None)
            ),
            "erp_service": erp_service,
            "erp_task": erp_task,
            "task_assignment": None,
            "created": False,
        }

    missing = []
    if not erp_service:
        missing.append("ERP Service link is missing")
    elif not service_exists:
        missing.append("linked ERP Service does not exist")

    if not erp_task:
        missing.append("ERP Task link is missing")
    elif not task_exists:
        missing.append("linked ERP Task does not exist")

    return {
        "status": "Repair Required",
        "erp_customer": _text(
            getattr(request, "erp_customer", None)
        ),
        "erp_service": erp_service,
        "erp_task": erp_task,
        "task_assignment": None,
        "created": False,
        "reason": "; ".join(missing),
    }


def _create_service(request, service, profile, customer: str, task_type: str):
    doc = frappe.new_doc("Service")
    doc.customer = customer
    doc.service_type = task_type
    customer_name = (
        _text(getattr(request, "customer_name", None))
        or _text(frappe.db.get_value("Customer", customer, "customer_name"))
        or customer
    )
    amount = getattr(service, "base_price", None) or 0
    _set_if_field(doc, "full_name", customer_name)
    _set_if_field(doc, "mobile_no", getattr(request, "contact_phone", None))
    _set_if_field(doc, "cnic", getattr(profile, "cnic", None) if profile else None)
    _set_if_field(doc, "service_amount", amount)
    _set_if_field(doc, "net_service_amount", amount)
    _set_if_field(doc, "discount", 0)
    _set_if_field(doc, "user_link", _customer_user(customer))
    _set_if_field(doc, "custom_status", "In Progress")
    _set_if_field(doc, "custom_customer_type", _text(getattr(profile, "customer_type", None)) or "Customer")
    _set_if_field(
        doc,
        "custom_remarks",
        f"Created from OMC Service Request {request.name}. {_text(getattr(request, 'description', None))}".strip(),
    )
    doc.insert(ignore_permissions=True)
    return doc


def _create_task(request, service_doc, customer: str, task_type: str):
    task = frappe.new_doc("Task")
    task.subject = _text(getattr(request, "title", None)) or f"Task for {request.name}"
    task.type = task_type
    task.customer = customer
    _set_if_field(
        task,
        "description",
        f"OMC Service Request: {request.name}\nERP Service: {service_doc.name}\n{_text(getattr(request, 'description', None))}".strip(),
    )
    _set_if_field(task, "priority", getattr(request, "priority", None) or "Medium")
    _set_if_field(task, "rate", getattr(service_doc, "service_amount", None) or 0)
    _set_if_field(task, "user_link", _customer_user(customer))
    _set_if_field(task, "custom_operation_status", "Open")
    _set_if_field(task, "exp_end_date", getattr(request, "expected_completion_date", None))
    task.insert(ignore_permissions=True)
    return task


def _link_service_task(service_doc, task) -> None:
    values = {}
    if service_doc.meta.get_field("task_created"):
        values["task_created"] = 1
    if service_doc.meta.get_field("task_link"):
        values["task_link"] = task.name
    if values:
        frappe.db.set_value("Service", service_doc.name, values, update_modified=False)


def ensure_task_assignment(task, assignee: str, priority: str):
    assignee = _text(assignee)
    if not assignee:
        return {"todo": None, "created": False, "conflict": None}
    if not frappe.db.exists("User", {"name": assignee, "enabled": 1, "user_type": "System User"}):
        frappe.throw(f"Assigned staff user {assignee} is not an active System User.", frappe.ValidationError)
    open_todos = frappe.get_all(
        "ToDo",
        filters={
            "reference_type": "Task",
            "reference_name": task.name,
            "status": ["not in", ["Closed", "Cancelled"]],
        },
        fields=["name", "allocated_to"],
        order_by="creation asc, name asc",
    )
    for existing in open_todos:
        if existing.allocated_to == assignee:
            return {"todo": existing.name, "created": False, "conflict": None}
    if open_todos:
        return {
            "todo": None,
            "created": False,
            "conflict": open_todos[0].allocated_to,
        }
    todo = frappe.new_doc("ToDo")
    todo.allocated_to = assignee
    todo.reference_type = "Task"
    todo.reference_name = task.name
    todo.description = f"Process ERP Task {task.name}"
    todo.status = "Open"
    todo.priority = priority or "Medium"
    todo.insert(ignore_permissions=True)
    return {"todo": todo.name, "created": True, "conflict": None}


def _assign_task(task, assignee: str, priority: str):
    return ensure_task_assignment(task, assignee, priority).get("todo")


def sync_request(
    request,
    *,
    service,
    profile=None,
    manual_customer=None,
    repair=False,
):
    existing = _existing_result(request)
    if existing and existing["status"] == "Synced" and repair:
        service_doc = frappe.get_doc("Service", existing["erp_service"])
        task = frappe.get_doc("Task", existing["erp_task"])
        _link_service_task(service_doc, task)
        assignment = _assign_task(
            task,
            _text(getattr(request, "assigned_staff", None)),
            _text(getattr(request, "priority", None)) or "Medium",
        )
        _set_request_state(
            request,
            status="Synced",
            customer=existing.get("erp_customer") or "",
            service=existing["erp_service"],
            task=existing["erp_task"],
        )
        return {**existing, "task_assignment": assignment}
    if existing and (existing["status"] != "Repair Required" or not repair):
        if existing["status"] == "Repair Required":
            _set_request_state(
                request,
                status="Repair Required",
                customer=existing.get("erp_customer") or "",
                service=existing.get("erp_service") or "",
                task=existing.get("erp_task") or "",
                error=existing.get("reason") or "",
            )
        else:
            _set_request_state(
                request,
                status="Synced",
                customer=existing.get("erp_customer") or "",
                service=existing.get("erp_service") or "",
                task=existing.get("erp_task") or "",
            )
        return existing

    existing_customer = _text(getattr(request, "erp_customer", None))
    existing_service = _text(getattr(request, "erp_service", None))
    existing_task = _text(getattr(request, "erp_task", None))
    customer = _linked_customer(profile)
    if (
        repair
        and not customer
        and existing_customer
        and frappe.db.exists("Customer", existing_customer)
    ):
        customer = existing_customer
    task_type = _text(getattr(service, "erp_task_type", None))
    missing = []
    if manual_customer and not profile:
        missing.append("walk-in customer requires ERP Customer conversion")
    elif not customer:
        missing.append("customer profile has no valid linked ERP Customer")
    if not task_type:
        missing.append("OMC Service has no ERP Task Type mapping")

    if missing:
        reason = "; ".join(missing)
        _set_request_state(
            request,
            status="Pending Configuration",
            customer=customer or existing_customer,
            service=existing_service,
            task=existing_task,
            error=reason,
        )
        return {
            "status": "Pending Configuration",
            "erp_customer": customer or existing_customer,
            "erp_service": existing_service,
            "erp_task": existing_task,
            "task_assignment": None,
            "created": False,
            "reason": reason,
        }

    service_doc = (
        frappe.get_doc("Service", existing_service)
        if repair
        and existing_service
        and frappe.db.exists("Service", existing_service)
        else _create_service(request, service, profile, customer, task_type)
    )
    task = (
        frappe.get_doc("Task", existing_task)
        if repair
        and existing_task
        and frappe.db.exists("Task", existing_task)
        else _create_task(request, service_doc, customer, task_type)
    )
    _link_service_task(service_doc, task)
    assignment = _assign_task(
        task,
        _text(getattr(request, "assigned_staff", None)),
        _text(getattr(request, "priority", None)) or "Medium",
    )
    _set_request_state(
        request,
        status="Synced",
        customer=customer,
        service=service_doc.name,
        task=task.name,
    )
    return {
        "status": "Synced",
        "erp_customer": customer,
        "erp_service": service_doc.name,
        "erp_task": task.name,
        "task_assignment": assignment,
        "created": True,
    }
