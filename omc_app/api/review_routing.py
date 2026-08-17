from __future__ import annotations

from time import monotonic
from typing import Any

import frappe
from frappe.utils import add_to_date, get_datetime, now_datetime

from omc_app.api import access, mobile, notification_events

DOCUMENT_DOCTYPE = "OMC Service Document"
PAYMENT_DOCTYPE = "OMC Service Payment"
DOMAIN_CONFIG = {
    DOCUMENT_DOCTYPE: {
        "capability": "can_review_documents",
        "role": "OMC Document Reviewer",
        "statuses": ["Uploaded"],
        "title": "Document review assigned",
        "type": "Document",
    },
    PAYMENT_DOCTYPE: {
        "capability": "can_review_payments",
        "role": "OMC Finance Reviewer",
        "statuses": ["Receipt Submitted", "Under Review"],
        "title": "Payment review assigned",
        "type": "Payment",
    },
}
FALLBACK_ROLES = ["OMC Manager", "OMC Admin"]
TERMINAL_CASE_STATUSES = {"Completed", "Cancelled"}
REVIEW_BATCH_SIZE = 100
REVIEW_RUNTIME_SECONDS = 45
JOB_LOCK_TIMEOUT_SECONDS = 55 * 60
STALE_REVIEW_HOURS = {DOCUMENT_DOCTYPE: 4, PAYMENT_DOCTYPE: 2}


def _text(value: Any) -> str:
    return str(value or "").strip()


def _active_system_user(user: str) -> bool:
    return bool(
        user
        and user != "Guest"
        and frappe.db.exists("User", {"name": user, "enabled": 1, "user_type": "System User"})
    )


def _has_capability(user: str, capability: str) -> bool:
    return _active_system_user(user) and bool(
        access.get_mobile_capabilities(user=user).get(capability)
    )


def _users_for_roles(roles: list[str]) -> list[str]:
    parents = frappe.get_all(
        "Has Role",
        filters={"role": ["in", roles], "parenttype": "User"},
        pluck="parent",
    )
    if not parents:
        return []
    return sorted(
        set(
            frappe.get_all(
                "User",
                filters={
                    "name": ["in", sorted(set(parents))],
                    "enabled": 1,
                    "user_type": "System User",
                },
                pluck="name",
            )
        )
    )


def _open_review_count(user: str, doctype: str) -> int:
    return frappe.db.count(
        "ToDo",
        filters={
            "allocated_to": user,
            "reference_type": doctype,
            "status": ["not in", ["Closed", "Cancelled"]],
        },
    )


def _least_loaded(users: list[str], doctype: str):
    candidates = sorted(set(users))
    return min(candidates, key=lambda user: (_open_review_count(user, doctype), user)) if candidates else None


def resolve_reviewer(record, service_case) -> dict[str, Any]:
    config = DOMAIN_CONFIG[record.doctype]
    assigned_staff = _text(getattr(service_case, "assigned_staff", None))
    if assigned_staff and _has_capability(assigned_staff, config["capability"]):
        return {"candidate": assigned_staff, "source": "assigned_staff"}
    specialists = [
        user
        for user in _users_for_roles([config["role"]])
        if _has_capability(user, config["capability"])
    ]
    candidate = _least_loaded(specialists, record.doctype)
    if candidate:
        return {"candidate": candidate, "source": "domain_reviewer"}
    fallback = [
        user
        for user in _users_for_roles(FALLBACK_ROLES)
        if _has_capability(user, config["capability"])
    ]
    candidate = _least_loaded(fallback, record.doctype)
    if candidate:
        return {"candidate": candidate, "source": "manager_fallback"}
    return {"candidate": None, "source": "none", "reason": "no capability-eligible reviewer"}


def _open_todos(record):
    return frappe.get_all(
        "ToDo",
        filters={
            "reference_type": record.doctype,
            "reference_name": record.name,
            "status": ["not in", ["Closed", "Cancelled"]],
        },
        fields=["name", "allocated_to", "creation"],
        order_by="creation asc, name asc",
    )


def close_review_todos(doctype: str, name: str, *, cancelled: bool = False) -> int:
    status = "Cancelled" if cancelled else "Closed"
    todos = frappe.get_all(
        "ToDo",
        filters={
            "reference_type": doctype,
            "reference_name": name,
            "status": ["not in", ["Closed", "Cancelled"]],
        },
        pluck="name",
    )
    for todo in todos:
        frappe.db.set_value("ToDo", todo, "status", status, update_modified=False)
    return len(todos)


def close_parent_review_todos(service_request: str, *, cancelled: bool = False) -> int:
    closed = 0
    for doctype in DOMAIN_CONFIG:
        names = frappe.get_all(doctype, filters={"service_request": service_request}, pluck="name")
        for name in names:
            closed += close_review_todos(doctype, name, cancelled=cancelled)
    return closed


def ensure_review_assignment(record, service_case=None) -> dict[str, Any]:
    if record.doctype not in DOMAIN_CONFIG:
        frappe.throw("Unsupported review record type.", frappe.ValidationError)
    config = DOMAIN_CONFIG[record.doctype]
    status = _text(getattr(record, "status", None))
    service_case = service_case or frappe.get_doc("OMC Service Request", record.service_request)
    if status not in config["statuses"] or _text(service_case.status) in TERMINAL_CASE_STATUSES:
        closed = close_review_todos(
            record.doctype,
            record.name,
            cancelled=_text(service_case.status) == "Cancelled" or status == "Cancelled",
        )
        return {"status": "terminal", "closed": closed, "created": False, "notification_created": False}

    open_todos = _open_todos(record)
    reusable = next(
        (
            todo
            for todo in open_todos
            if _has_capability(todo.allocated_to, config["capability"])
        ),
        None,
    )
    for todo in open_todos:
        if reusable and todo.name == reusable.name:
            continue
        frappe.db.set_value("ToDo", todo.name, "status", "Cancelled", update_modified=False)
    if reusable:
        return {
            "status": "already_assigned",
            "todo": reusable.name,
            "reviewer": reusable.allocated_to,
            "created": False,
            "notification_created": False,
        }

    decision = resolve_reviewer(record, service_case)
    reviewer = decision.get("candidate")
    if not reviewer:
        return {**decision, "status": "no_candidate", "created": False, "notification_created": False}
    todo = frappe.new_doc("ToDo")
    todo.allocated_to = reviewer
    todo.reference_type = record.doctype
    todo.reference_name = record.name
    todo.description = f"Review {record.doctype} {record.name} for {record.service_request}"
    todo.status = "Open"
    todo.priority = "High" if _text(service_case.priority) in {"High", "Urgent"} else "Medium"
    todo.insert(ignore_permissions=True)
    notification = None
    actor = _text(getattr(frappe.session, "user", None))
    if reviewer != actor:
        event_name = (
            "document.review"
            if record.doctype == DOCUMENT_DOCTYPE
            else "payment.review"
        )
        contract = notification_events.event_contract(
            event_name,
            record.name,
        )
        notification = mobile._create_customer_notification(
            recipient_user=reviewer,
            title=config["title"],
            message=(
                f"Review task {todo.name}: {record.name} "
                f"for {record.service_request} is ready for review."
            ),
            notification_type=contract["category"],
            reference_doctype=contract["reference_doctype"],
            reference_name=contract["reference_name"],
            mobile_route=contract["mobile_route"],
            event_key=f"{contract['event_key']}:{todo.name}",
        )

    return {
        **decision,
        "status": "assigned",
        "todo": todo.name,
        "reviewer": reviewer,
        "created": True,
        "notification_created": bool(notification),
    }


def _escalate_stale_review(record) -> bool:
    creation = getattr(record, "creation", None)
    if not creation or get_datetime(creation) > add_to_date(
        now_datetime(), hours=-STALE_REVIEW_HOURS[record.doctype]
    ):
        return False
    config = DOMAIN_CONFIG[record.doctype]
    managers = [
        user
        for user in _users_for_roles(FALLBACK_ROLES)
        if _has_capability(user, config["capability"])
    ]
    recipient = _least_loaded(managers, record.doctype)
    if not recipient:
        return False
    title = "Stale review task needs attention"
    if frappe.db.exists(
        "OMC Notification",
        {
            "recipient_user": recipient,
            "title": title,
            "reference_doctype": record.doctype,
            "reference_name": record.name,
            "creation": [">=", add_to_date(now_datetime(), hours=-24)],
        },
    ):
        return False
    return bool(
        mobile._create_customer_notification(
            recipient_user=recipient,
            title=title,
            message=f"{record.doctype} {record.name} remains awaiting review.",
            notification_type=config["type"],
            reference_doctype=record.doctype,
            reference_name=record.name,
        )
    )


def _job_lock():
    site = getattr(frappe.local, "site", "site")
    return frappe.cache().lock(
        f"omc_app:{site}:review_routing",
        timeout=JOB_LOCK_TIMEOUT_SECONDS,
        blocking_timeout=0,
    )


def run_review_assignment_checks():
    summary = {
        "scanned": 0,
        "assigned": 0,
        "already_assigned": 0,
        "closed": 0,
        "no_candidate": 0,
        "stale_escalated": 0,
        "failed": 0,
        "notifications_created": 0,
        "runtime_budget_stopped": 0,
    }
    lock = _job_lock()
    if not lock.acquire(blocking=False):
        return {**summary, "status": "skipped_locked"}
    started = monotonic()
    candidates = []
    try:
        per_domain = max(1, REVIEW_BATCH_SIZE // len(DOMAIN_CONFIG))
        for doctype, config in DOMAIN_CONFIG.items():
            names = frappe.get_all(
                doctype,
                filters={"status": ["in", config["statuses"]]},
                pluck="name",
                order_by="creation asc, name asc",
                limit_page_length=per_domain,
            )
            candidates.extend((doctype, name) for name in names)
        candidates.sort()
        summary["scanned"] = len(candidates)
        for index, (doctype, name) in enumerate(candidates):
            if monotonic() - started >= REVIEW_RUNTIME_SECONDS:
                summary["runtime_budget_stopped"] = len(candidates) - index
                break
            savepoint = f"review_{index}"
            frappe.db.savepoint(savepoint)
            try:
                locked = frappe.db.get_value(doctype, name, "name", for_update=True, wait=False)
                if not locked:
                    continue
                record = frappe.get_doc(doctype, name)
                result = ensure_review_assignment(record)
                if result["status"] == "assigned":
                    summary["assigned"] += 1
                elif result["status"] == "already_assigned":
                    summary["already_assigned"] += 1
                elif result["status"] == "terminal":
                    summary["closed"] += int(result.get("closed") or 0)
                elif result["status"] == "no_candidate":
                    summary["no_candidate"] += 1
                    frappe.logger("omc_app.scheduler").warning(
                        "OMC review routing found no candidate for %s %s", doctype, name
                    )
                summary["notifications_created"] += int(result.get("notification_created") or 0)
                if result["status"] in {"assigned", "already_assigned"}:
                    escalated = int(_escalate_stale_review(record))
                    summary["stale_escalated"] += escalated
                    summary["notifications_created"] += escalated
            except Exception as error:
                frappe.db.rollback(save_point=savepoint)
                summary["failed"] += 1
                frappe.log_error(
                    title=f"OMC review routing failed: {doctype} {name}",
                    message=f"{error.__class__.__name__}: {_text(error)}"[:1000],
                )
        return {**summary, "status": "completed"}
    finally:
        try:
            lock.release()
        except Exception:
            pass
