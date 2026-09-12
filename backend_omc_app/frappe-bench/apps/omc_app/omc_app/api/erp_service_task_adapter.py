"""Canonical ERP Service/Task bridge for OMC service requests.

OMC Service Request remains the mobile/customer authority. ERP records are
created only when an ERP Customer link and ERP Task Type mapping exist.
This module never commits the database transaction.
"""
from __future__ import annotations

from typing import Any

import frappe

from omc_app.api import customer_authority


def _text(value: Any) -> str:
    return str(value or "").strip()


def _set_if_field(doc, fieldname: str, value: Any) -> None:
    if value not in (None, "") and doc.meta.get_field(fieldname):
        doc.set(fieldname, value)


def _service_remarks(request) -> str:
    # The legacy Service custom field is Data (140 characters). The complete
    # request description is retained on the linked ERP Task below.
    return f"Created from OMC Service Request {request.name}."


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


def _linked_customer(request, profile) -> str:
    return customer_authority.resolve_request_customer(
        request,
        profile=profile,
    )


def _customer_user(customer: str) -> str:
    if not frappe.get_meta("Customer").get_field("user_link"):
        return ""
    return _text(frappe.db.get_value("Customer", customer, "user_link"))


def _existing_result(request):
    # Validate the canonical account/customer relationship before every bridge
    # path, including already-synced repair/retry paths that may return early.
    if _text(getattr(request, "customer_account", None)):
        customer_authority.resolve_request_customer(request)

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
    service_amount = getattr(request, "original_price", None)
    if service_amount is None:
        service_amount = getattr(service, "base_price", None) or 0

    discount = getattr(request, "discount_amount", None)
    discount = discount if discount is not None else 0

    net_service_amount = getattr(request, "final_price", None)
    if net_service_amount is None:
        net_service_amount = service_amount - discount
    _set_if_field(doc, "full_name", customer_name)
    _set_if_field(doc, "mobile_no", getattr(request, "contact_phone", None))
    _set_if_field(doc, "cnic", getattr(profile, "cnic", None) if profile else None)
    _set_if_field(doc, "service_amount", service_amount)
    _set_if_field(doc, "discount", discount)
    _set_if_field(doc, "net_service_amount", net_service_amount)
    _set_if_field(doc, "user_link", _customer_user(customer))
    _set_if_field(doc, "custom_status", "In Progress")
    _set_if_field(doc, "custom_customer_type", _text(getattr(profile, "customer_type", None)) or "Customer")
    _set_if_field(
        doc,
        "custom_remarks",
        _service_remarks(request),
    )
    doc.insert(ignore_permissions=True)
    return doc


def _hydrate_task_from_request(
    task,
    request,
    service_doc,
    *,
    preserve_existing=False,
):
    """Apply OMC context without replacing legacy ERP Task authority."""

    values = {}

    # ERP Task.type is the canonical ERP Task Type.
    task_type = _text(getattr(service_doc, "service_type", None))
    if (
        task.meta.get_field("type")
        and task_type
        and not _text(getattr(task, "type", None))
    ):
        values["type"] = task_type

    # task_status is a separate legacy workflow discriminator. Do not
    # copy Service.service_type into it: the value domains are different.
    omc_service = _text(getattr(request, "service", None))
    mapped_task_status = ""
    if omc_service:
        mapped_task_status = _text(
            frappe.db.get_value(
                "OMC Service",
                omc_service,
                "erp_task_status",
            )
        )

    task_status_field = task.meta.get_field("task_status")
    if (
        task_status_field
        and mapped_task_status
        and not _text(getattr(task, "task_status", None))
    ):
        allowed = {
            option.strip()
            for option in str(
                getattr(task_status_field, "options", "") or ""
            ).splitlines()
            if option.strip()
        }

        if allowed and mapped_task_status not in allowed:
            frappe.throw(
                "OMC Service legacy Task Status mapping "
                f"{mapped_task_status} is not allowed by "
                "Task.task_status.",
                frappe.ValidationError,
            )

        values["task_status"] = mapped_task_status

    # Completion validation compares Task.tax_id with proof/OCR data.
    # Fill it from the authoritative ERP Customer only when missing.
    if (
        task.meta.get_field("tax_id")
        and not _text(getattr(task, "tax_id", None))
    ):
        customer = _text(getattr(service_doc, "customer", None))
        if customer:
            tax_id = _text(
                frappe.db.get_value(
                    "Customer",
                    customer,
                    "tax_id",
                )
            )
            if tax_id:
                values["tax_id"] = tax_id

    # Keep the ERP Service's valid User projection when Task has none.
    if (
        task.meta.get_field("user_link")
        and not _text(getattr(task, "user_link", None))
    ):
        service_user = _text(
            getattr(service_doc, "user_link", None)
        )
        if service_user:
            values["user_link"] = service_user

    if (
        task.meta.get_field("priority")
        and (
            not preserve_existing
            or not _text(getattr(task, "priority", None))
        )
    ):
        values["priority"] = (
            _text(getattr(request, "priority", None))
            or "Medium"
        )

    expected_completion_date = getattr(
        request,
        "expected_completion_date",
        None,
    )
    if (
        expected_completion_date
        and task.meta.get_field("exp_end_date")
        and (
            not preserve_existing
            or not getattr(task, "exp_end_date", None)
        )
    ):
        values["exp_end_date"] = expected_completion_date

    operation_field = task.meta.get_field(
        "custom_operation_status"
    )
    if (
        operation_field
        and not _text(
            getattr(task, "custom_operation_status", None)
        )
    ):
        allowed = {
            option.strip()
            for option in str(
                getattr(operation_field, "options", "") or ""
            ).splitlines()
            if option.strip()
        }
        if not allowed or "Open" in allowed:
            values["custom_operation_status"] = "Open"

    if values:
        frappe.db.set_value(
            "Task",
            task.name,
            values,
            update_modified=False,
        )
        for fieldname, value in values.items():
            setattr(task, fieldname, value)

    return task


def _create_task_from_service(request, service_doc):
    """Use the existing ERP Service -> Task creator instead of duplicating it."""

    linked_task = _text(getattr(service_doc, "task_link", None))

    # Repair-safe reuse: if ERP Service already owns a valid Task, use it.
    if linked_task and frappe.db.exists("Task", linked_task):
        task = frappe.get_doc("Task", linked_task)
        return _hydrate_task_from_request(
            task,
            request,
            service_doc,
            preserve_existing=True,
        )

    # Stale Service flags must not block the legacy creator during repair.
    if getattr(service_doc, "task_created", 0) or linked_task:
        frappe.db.set_value(
            "Service",
            service_doc.name,
            {
                "task_created": 0,
                "task_link": None,
            },
            update_modified=False,
        )
        service_doc.task_created = 0
        service_doc.task_link = None

    from erpnext.service import create_task_from_service_dt

    task_name = _text(create_task_from_service_dt(service_doc.name))

    # Legacy method writes task_link itself; use it as a defensive fallback.
    if not task_name:
        task_name = _text(
            frappe.db.get_value("Service", service_doc.name, "task_link")
        )

    if not task_name or not frappe.db.exists("Task", task_name):
        frappe.throw(
            f"ERP Service {service_doc.name} did not create a valid Task.",
            frappe.ValidationError,
        )

    task = frappe.get_doc("Task", task_name)
    return _hydrate_task_from_request(task, request, service_doc)


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

    from omc_app.api import mobile

    mobile._create_customer_notification(
        recipient_user=assignee,
        title="New task assigned",
        message=(
            f"{task.name} — "
            f"{_text(getattr(task, 'subject', None)) or 'ERP Task'}"
        ),
        notification_type="Task",
        reference_doctype="Task",
        reference_name=task.name,
    )

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
        _hydrate_task_from_request(
            task,
            request,
            service_doc,
            preserve_existing=True,
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
    customer = _linked_customer(request, profile)
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
    if (
        repair
        and existing_task
        and frappe.db.exists("Task", existing_task)
    ):
        task = frappe.get_doc("Task", existing_task)
        task = _hydrate_task_from_request(
            task,
            request,
            service_doc,
            preserve_existing=True,
        )
    else:
        task = _create_task_from_service(request, service_doc)
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
