"""OMC-owned one-to-many linkage between Service Requests and ERP Tasks.

ERP Task remains the operational source of truth. ``OMC Service Task Link``
only records which internal ERP Tasks belong to an OMC customer-facing service
request. ``OMC Service Request.erp_task`` is retained as the compatibility
primary pointer while older deployments and callers are migrated.
"""
from __future__ import annotations

from typing import Any

import frappe
from frappe.utils import now_datetime


LINK_DOCTYPE = "OMC Service Task Link"
REQUEST_DOCTYPE = "OMC Service Request"


def _text(value: Any) -> str:
    return str(value or "").strip()


def _link_doctype_available() -> bool:
    try:
        return bool(frappe.db.exists("DocType", LINK_DOCTYPE))
    except Exception:
        return False


def _legacy_task(request_name: str) -> str:
    if not request_name or not frappe.db.exists(REQUEST_DOCTYPE, request_name):
        return ""
    return _text(
        frappe.db.get_value(
            REQUEST_DOCTYPE,
            request_name,
            "erp_task",
        )
    )


def ensure_link(
    *,
    request_name: str,
    task_name: str,
    erp_service: str = "",
    is_primary: bool = False,
    required_for_completion: bool = True,
    source: str = "Activation",
    actor: str = "",
):
    """Idempotently register one ERP Task as internal work for a request."""

    request_name = _text(request_name)
    task_name = _text(task_name)
    erp_service = _text(erp_service)
    actor = _text(actor) or _text(
        getattr(getattr(frappe, "session", None), "user", None)
    )

    if not request_name or not frappe.db.exists(REQUEST_DOCTYPE, request_name):
        frappe.throw("Service Request does not exist.", frappe.ValidationError)
    if not task_name or not frappe.db.exists("Task", task_name):
        frappe.throw("ERP Task does not exist.", frappe.ValidationError)
    if not _link_doctype_available():
        frappe.throw(
            "Service Task Link schema is not available. Run the OMC app migration.",
            frappe.ValidationError,
        )

    existing = frappe.db.get_value(
        LINK_DOCTYPE,
        {"erp_task": task_name},
        ["name", "service_request", "is_primary", "required_for_completion"],
        as_dict=True,
    )
    if existing:
        if _text(existing.service_request) != request_name:
            frappe.throw(
                f"ERP Task {task_name} is already linked to another Service Request.",
                frappe.ValidationError,
            )
        return frappe.get_doc(LINK_DOCTYPE, existing.name)

    if is_primary:
        primary = frappe.db.get_value(
            LINK_DOCTYPE,
            {"service_request": request_name, "is_primary": 1},
            "name",
        )
        if primary:
            frappe.throw(
                "This Service Request already has a primary ERP Task.",
                frappe.ValidationError,
            )

    doc = frappe.get_doc(
        {
            "doctype": LINK_DOCTYPE,
            "service_request": request_name,
            "erp_task": task_name,
            "erp_service": erp_service or None,
            "is_primary": 1 if is_primary else 0,
            "required_for_completion": 1 if required_for_completion else 0,
            "source": source or "Activation",
            "linked_at": now_datetime(),
            "linked_by": actor if actor and actor != "Guest" else None,
        }
    )
    try:
        doc.insert(ignore_permissions=True)
    except frappe.DuplicateEntryError:
        existing_name = frappe.db.get_value(
            LINK_DOCTYPE,
            {"erp_task": task_name},
            "name",
        )
        if existing_name:
            existing_doc = frappe.get_doc(LINK_DOCTYPE, existing_name)
            if _text(existing_doc.service_request) == request_name:
                return existing_doc
        raise
    return doc


def ensure_primary_link(request, *, source: str = "Activation"):
    """Backfill/register the legacy primary pointer in the relation table."""

    request_name = _text(getattr(request, "name", None))
    task_name = _text(getattr(request, "erp_task", None))
    if not request_name or not task_name:
        return None
    return ensure_link(
        request_name=request_name,
        task_name=task_name,
        erp_service=_text(getattr(request, "erp_service", None)),
        is_primary=True,
        required_for_completion=True,
        source=source,
    )


def linked_task_rows(request_name: str) -> list[dict[str, Any]]:
    """Return all linked Tasks, with legacy primary fallback when not backfilled."""

    request_name = _text(request_name)
    if not request_name:
        return []

    rows = []
    if _link_doctype_available():
        rows = frappe.get_all(
            LINK_DOCTYPE,
            filters={"service_request": request_name},
            fields=[
                "name",
                "erp_task",
                "erp_service",
                "is_primary",
                "required_for_completion",
                "source",
                "linked_at",
            ],
            order_by="is_primary desc, creation asc, name asc",
            limit_page_length=1000,
        )

    normalized = [dict(row) for row in rows]
    known = {_text(row.get("erp_task")) for row in normalized}
    legacy = _legacy_task(request_name)
    if legacy and legacy not in known:
        normalized.insert(
            0,
            {
                "name": "",
                "erp_task": legacy,
                "erp_service": _text(
                    frappe.db.get_value(
                        REQUEST_DOCTYPE,
                        request_name,
                        "erp_service",
                    )
                ),
                "is_primary": 1,
                "required_for_completion": 1,
                "source": "Legacy Backfill",
                "linked_at": None,
            },
        )
    return normalized


def task_names(request_name: str, *, required_only: bool = False) -> list[str]:
    names = []
    for row in linked_task_rows(request_name):
        if required_only and not int(row.get("required_for_completion") or 0):
            continue
        name = _text(row.get("erp_task"))
        if name and name not in names:
            names.append(name)
    return names


def request_for_task(task_name: str) -> str:
    """Resolve the single OMC Service Request that owns an ERP Task."""

    task_name = _text(task_name)
    if not task_name:
        return ""

    if _link_doctype_available():
        request_name = _text(
            frappe.db.get_value(
                LINK_DOCTYPE,
                {"erp_task": task_name},
                "service_request",
            )
        )
        if request_name:
            return request_name

    # Compatibility fallback for records that have not yet been backfilled.
    rows = frappe.get_all(
        REQUEST_DOCTYPE,
        filters={"erp_task": task_name},
        pluck="name",
        order_by="creation asc, name asc",
        limit_page_length=2,
    )
    if len(rows) > 1:
        frappe.throw(
            f"ERP Task {task_name} is linked to multiple OMC service requests. Repair the OMC task linkage.",
            frappe.ValidationError,
        )
    return _text(rows[0]) if rows else ""


def completion_state(request_name: str) -> dict[str, Any]:
    """Aggregate required ERP Task completion without owning Task status."""

    required = task_names(request_name, required_only=True)
    if not required:
        return {
            "required_tasks": 0,
            "completed_tasks": 0,
            "incomplete_tasks": [],
            "cancelled_tasks": [],
            "all_required_completed": False,
        }

    rows = frappe.get_all(
        "Task",
        filters={"name": ["in", required]},
        fields=["name", "status"],
        limit_page_length=len(required),
    )
    status_by_name = {
        _text(row.name): _text(row.status)
        for row in rows
    }
    incomplete = [
        name
        for name in required
        if status_by_name.get(name) != "Completed"
    ]
    cancelled = [
        name
        for name in required
        if status_by_name.get(name) in {"Cancelled", "Canceled"}
    ]
    return {
        "required_tasks": len(required),
        "completed_tasks": len(required) - len(incomplete),
        "incomplete_tasks": incomplete,
        "cancelled_tasks": cancelled,
        "all_required_completed": not incomplete,
    }


def _validate_staff_link_target(request, task_name: str) -> None:
    if _text(getattr(request, "request_state", None)) != "Activated":
        frappe.throw(
            "Additional ERP Tasks can only be linked after service activation.",
            frappe.ValidationError,
        )
    if _text(getattr(request, "status", None)) in {"Completed", "Cancelled"}:
        frappe.throw(
            "Terminal Service Requests cannot accept additional ERP Tasks.",
            frappe.ValidationError,
        )

    task_meta = frappe.get_meta("Task")
    request_customer = _text(getattr(request, "erp_customer", None))
    if request_customer and task_meta.get_field("customer"):
        task_customer = _text(
            frappe.db.get_value("Task", task_name, "customer")
        )
        if task_customer and task_customer != request_customer:
            frappe.throw(
                "ERP Task Customer does not match the Service Request ERP Customer.",
                frappe.ValidationError,
            )


@frappe.whitelist(methods=["POST"])
def link_existing_task(
    service_request=None,
    task=None,
    required_for_completion=1,
):
    """Manager/admin bridge for attaching additional ERP Tasks to a request."""

    from omc_app.api import capabilities

    capabilities.require("can_manage_tasks")
    request_name = _text(service_request)
    task_name = _text(task)
    if not request_name or not frappe.db.exists(REQUEST_DOCTYPE, request_name):
        frappe.throw("Service Request does not exist.", frappe.DoesNotExistError)
    if not task_name or not frappe.db.exists("Task", task_name):
        frappe.throw("ERP Task does not exist.", frappe.DoesNotExistError)

    request = frappe.get_doc(REQUEST_DOCTYPE, request_name)
    _validate_staff_link_target(request, task_name)
    link = ensure_link(
        request_name=request.name,
        task_name=task_name,
        erp_service=_text(getattr(request, "erp_service", None)),
        is_primary=False,
        required_for_completion=bool(int(required_for_completion or 0)),
        source="Staff Linked",
    )
    progress = completion_state(request.name)
    return {
        "service_request": request.name,
        "task": task_name,
        "link": link.name,
        "required_for_completion": int(link.required_for_completion or 0),
        "task_progress": {
            "required": progress["required_tasks"],
            "completed": progress["completed_tasks"],
            "remaining": len(progress["incomplete_tasks"]),
        },
    }


@frappe.whitelist(methods=["POST"])
def unlink_secondary_task(service_request=None, task=None):
    """Manager/admin repair path; primary compatibility Task cannot be unlinked."""

    from omc_app.api import capabilities

    capabilities.require("can_manage_tasks")
    request_name = _text(service_request)
    task_name = _text(task)
    if not request_name or not task_name:
        frappe.throw("service_request and task are required.", frappe.ValidationError)

    link_name = frappe.db.get_value(
        LINK_DOCTYPE,
        {"service_request": request_name, "erp_task": task_name},
        "name",
    )
    if not link_name:
        frappe.throw("Service Task Link does not exist.", frappe.DoesNotExistError)

    link = frappe.get_doc(LINK_DOCTYPE, link_name)
    if int(link.is_primary or 0):
        frappe.throw(
            "The primary compatibility ERP Task cannot be unlinked here.",
            frappe.ValidationError,
        )

    request = frappe.get_doc(REQUEST_DOCTYPE, request_name)
    if _text(getattr(request, "status", None)) in {"Completed", "Cancelled"}:
        frappe.throw(
            "Terminal Service Request task links cannot be changed.",
            frappe.ValidationError,
        )

    frappe.delete_doc(LINK_DOCTYPE, link.name, ignore_permissions=True)
    progress = completion_state(request_name)
    return {
        "service_request": request_name,
        "task": task_name,
        "unlinked": True,
        "task_progress": {
            "required": progress["required_tasks"],
            "completed": progress["completed_tasks"],
            "remaining": len(progress["incomplete_tasks"]),
        },
    }
