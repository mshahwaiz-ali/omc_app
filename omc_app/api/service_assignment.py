from __future__ import annotations

from time import monotonic
from typing import Any

import frappe
from frappe.utils import add_to_date, now_datetime

from omc_app.api import capabilities, erp_service_task_adapter, identity, mobile

ASSIGNABLE_SERVICE_ROLES = {
    "Employee",
    "Consultant",
    "Tax Associates",
    "Business Partner",
    "OMC Manager",
    # Legacy values remain readable so older rows do not become unassignable
    # before the source-controlled catalogue reconciles them to Employee.
    "OMC Consultant",
    "OMC Tax Associate",
    "OMC Business Partner",
}

PERSONA_ASSIGNMENT_ROLES = {
    "Employee": {"Employee"},
    "Consultant": {"Consultant", "OMC Consultant"},
    "OMC Consultant": {"Consultant", "OMC Consultant"},
    "Tax Associate": {"Tax Associates", "OMC Tax Associate"},
    "Tax Associates": {"Tax Associates", "OMC Tax Associate"},
    "OMC Tax Associate": {"Tax Associates", "OMC Tax Associate"},
    "Business Partner": {"Business Partner", "OMC Business Partner"},
    "OMC Business Partner": {"Business Partner", "OMC Business Partner"},
    "Manager": {"OMC Manager"},
    "OMC Manager": {"OMC Manager"},
}

ROLE_PERSONAS = {
    "Employee": ["Employee"],
    "Consultant": ["Consultant", "OMC Consultant"],
    "Tax Associates": ["Tax Associate", "Tax Associates", "OMC Tax Associate"],
    "Business Partner": ["Business Partner", "OMC Business Partner"],
    "OMC Manager": ["Manager", "OMC Manager"],
    "OMC Consultant": ["Consultant", "OMC Consultant"],
    "OMC Tax Associate": ["Tax Associate", "Tax Associates", "OMC Tax Associate"],
    "OMC Business Partner": ["Business Partner", "OMC Business Partner"],
}

OPEN_CASE_STATUSES = ["Open", "In Progress", "Waiting for Customer", "Waiting for Payment"]
RECOVERY_BATCH_SIZE = 50
RECOVERY_RUNTIME_SECONDS = 45
JOB_LOCK_TIMEOUT_SECONDS = 55 * 60


def _text(value: Any) -> str:
    return str(value or "").strip()


def user_roles(user: str) -> set[str]:
    return set(frappe.get_roles(user) or []) if user and user != "Guest" else set()


def active_assignable_user(user: Any, *, required_role: str | None = None):
    user = _text(user)
    if not user or user in {"Guest", "Administrator"}:
        return None

    user_row = frappe.db.get_value(
        "User",
        user,
        ["enabled", "user_type", "full_name"],
        as_dict=True,
    )
    if not user_row:
        return None
    if not int(user_row.enabled or 0) or user_row.user_type != "System User":
        return None

    full_name = _text(user_row.full_name).lower()
    if full_name == "administrator":
        return None

    access = identity.get_staff_access(user)
    if not access or access.access_status != "Approved" or access.reconciliation_status != "Current":
        return None

    persona = _text(access.persona_snapshot)
    effective_roles = PERSONA_ASSIGNMENT_ROLES.get(persona, {persona}).intersection(
        ASSIGNABLE_SERVICE_ROLES
    )
    if required_role:
        return user if required_role in effective_roles else None

    return user if effective_roles else None


def users_for_role(role: str) -> list[str]:
    if role not in ASSIGNABLE_SERVICE_ROLES:
        return []

    users = frappe.get_all(
        "OMC Staff Access",
        filters={
            "persona_snapshot": ["in", ROLE_PERSONAS.get(role, [role])],
            "access_status": "Approved",
            "reconciliation_status": "Current",
        },
        pluck="user",
        limit_page_length=500,
    )

    return sorted(
        user
        for user in set(users)
        if active_assignable_user(user, required_role=role)
    )


def open_assignment_count(user: str) -> int:
    return frappe.db.count(
        "ToDo",
        filters={
            "allocated_to": user,
            "reference_type": "OMC Service Request",
            "status": ["not in", ["Closed", "Cancelled"]],
        },
    )


def least_loaded_user(users: list[str]):
    candidates = sorted(set(user for user in users if user))
    return min(candidates, key=lambda user: (open_assignment_count(user), user)) if candidates else None


def assignment_role_for_service(service) -> str:
    configured = _text(getattr(service, "default_assignment_role", None))
    if configured in ASSIGNABLE_SERVICE_ROLES:
        return configured

    # Source-controlled OMC services are reconciled to Employee. Keeping the
    # same fallback here also makes unmanaged/legacy services fail toward the
    # intended operational pool instead of guessing from service titles.
    return "Employee"


def resolve_assignee(service, *, explicit_user=None, referral_owner=None) -> dict[str, Any]:
    rejected = []
    explicit = _text(explicit_user)
    if explicit:
        active = active_assignable_user(explicit)
        if not active:
            frappe.throw(
                "The selected assignee must be an enabled System User with an assignable OMC staff persona.",
                frappe.ValidationError,
            )
        return {"candidate": active, "source": "explicit", "role": "", "rejected": rejected}

    for source, candidate in (
        ("referral_owner", referral_owner),
        ("service_default", getattr(service, "default_assignee", None)),
    ):
        candidate = _text(candidate)
        if not candidate:
            continue
        active = active_assignable_user(candidate)
        if active:
            return {"candidate": active, "source": source, "role": "", "rejected": rejected}
        rejected.append({"source": source, "candidate": candidate, "reason": "ineligible"})

    role = assignment_role_for_service(service)
    candidate = least_loaded_user(users_for_role(role))
    if candidate:
        return {"candidate": candidate, "source": "service_role", "role": role, "rejected": rejected}

    candidate = least_loaded_user(users_for_role("OMC Manager"))
    if candidate:
        return {
            "candidate": candidate,
            "source": "manager_fallback",
            "role": "OMC Manager",
            "rejected": rejected,
        }

    return {
        "candidate": None,
        "source": "none",
        "role": role,
        "rejected": rejected,
        "reason": f"no enabled System User is eligible for {role} or OMC Manager",
    }


def ensure_assignment_todo(service_request, assignee: str) -> dict[str, Any]:
    if not assignee:
        return {"name": None, "created": False}
    existing = frappe.get_all(
        "ToDo",
        filters={
            "reference_type": "OMC Service Request",
            "reference_name": service_request.name,
            "status": ["not in", ["Closed", "Cancelled"]],
        },
        fields=["name", "allocated_to"],
        order_by="creation asc, name asc",
    )
    reusable = next((todo for todo in existing if todo.allocated_to == assignee), None)
    for todo in existing:
        if reusable and todo.name == reusable.name:
            continue
        frappe.db.set_value("ToDo", todo.name, "status", "Cancelled", update_modified=False)
    if reusable:
        return {"name": reusable.name, "created": False}
    todo = frappe.new_doc("ToDo")
    todo.allocated_to = assignee
    todo.reference_type = "OMC Service Request"
    todo.reference_name = service_request.name
    todo.description = f"Process {service_request.title or service_request.name}"
    todo.status = "Open"
    todo.priority = service_request.priority or "Medium"
    todo.insert(ignore_permissions=True)
    return {"name": todo.name, "created": True}


def apply_assignment(service_request, decision: dict[str, Any], *, set_assignee: bool = True) -> dict[str, Any]:
    assignee = _text(decision.get("candidate"))
    if not assignee:
        return {**decision, "todo": None, "todo_created": False, "notification_created": False}
    if set_assignee:
        service_request.assigned_staff = assignee
        if getattr(service_request, "name", None):
            frappe.db.set_value(
                "OMC Service Request",
                service_request.name,
                "assigned_staff",
                assignee,
                update_modified=False,
            )
    todo = ensure_assignment_todo(service_request, assignee)
    notification_created = False
    if todo["created"]:
        notification_created = bool(
            mobile._create_customer_notification(
                recipient_user=assignee,
                title="New service request assigned",
                message=(
                    f"{service_request.name} — "
                    f"{service_request.service_title or service_request.title or 'Service Request'}"
                ),
                notification_type="Service",
                reference_doctype="OMC Service Request",
                reference_name=service_request.name,
            )
        )
        mobile._create_service_timeline_entry(
            service_request=service_request.name,
            event_type="Assignment",
            title="Request Assigned",
            description=f"Request assigned to {assignee}.",
            visible_to_customer=0,
        )
    task_result = None
    erp_task = _text(getattr(service_request, "erp_task", None))
    if erp_task and frappe.db.exists("Task", erp_task):
        task_result = erp_service_task_adapter.ensure_task_assignment(
            frappe.get_doc("Task", erp_task), assignee, service_request.priority or "Medium"
        )
        if task_result.get("conflict"):
            frappe.logger("omc_app.scheduler").warning(
                "OMC assignment divergence for request %s and ERP Task %s: request assignee %s, task assignee %s",
                service_request.name,
                erp_task,
                assignee,
                task_result["conflict"],
            )
    return {
        **decision,
        "todo": todo["name"],
        "todo_created": todo["created"],
        "notification_created": notification_created,
        "erp_task_assignment": task_result,
    }


def assign_new_request(service_request, service, *, explicit_user=None, referral_owner=None):
    decision = resolve_assignee(
        service,
        explicit_user=explicit_user,
        referral_owner=referral_owner,
    )
    service_request.assigned_staff = decision.get("candidate") or ""
    return decision


def _job_lock(name: str):
    key = f"omc_app:{getattr(frappe.local, 'site', 'site')}:{name}"
    return frappe.cache().lock(key, timeout=JOB_LOCK_TIMEOUT_SECONDS, blocking_timeout=0)


def _escalate_assignment_issue(service_request, reason: str) -> bool:
    staff_users = frappe.get_all(
        "OMC Staff Access",
        filters={"access_status": "Approved", "reconciliation_status": "Current"},
        pluck="user",
        limit_page_length=500,
    )
    active = [
        user
        for user in staff_users
        if identity.user_is_enabled(user)
        and capabilities.effective(user).get("can_reassign_service_cases")
    ]
    if not active:
        return False
    recipient = sorted(set(active))[0]
    title = "Service request assignment needs attention"
    if frappe.db.exists(
        "OMC Notification",
        {
            "recipient_user": recipient,
            "title": title,
            "reference_doctype": "OMC Service Request",
            "reference_name": service_request.name,
            "creation": [">=", add_to_date(now_datetime(), hours=-24)],
        },
    ):
        return False
    return bool(
        mobile._create_customer_notification(
            recipient_user=recipient,
            title=title,
            message=f"{service_request.name} requires manual assignment review: {reason}",
            notification_type="Service",
            reference_doctype="OMC Service Request",
            reference_name=service_request.name,
        )
    )


def run_unassigned_recovery() -> dict[str, Any]:
    summary = {
        "scanned": 0,
        "assigned": 0,
        "already_assigned": 0,
        "invalid_existing": 0,
        "no_candidate": 0,
        "failed": 0,
        "locked": 0,
        "notifications_created": 0,
        "runtime_budget_stopped": 0,
    }
    lock = _job_lock("unassigned_recovery")
    if not lock.acquire(blocking=False):
        return {**summary, "status": "skipped_locked"}
    started = monotonic()
    try:
        names = frappe.get_all(
            "OMC Service Request",
            filters={
                "request_state": "Activated",
                "status": ["in", OPEN_CASE_STATUSES],
                "assigned_staff": ["is", "not set"],
            },
            pluck="name",
            order_by="creation asc, name asc",
            limit_page_length=RECOVERY_BATCH_SIZE,
        )
        remaining = max(0, RECOVERY_BATCH_SIZE - len(names))
        if remaining:
            existing_names = frappe.get_all(
                "OMC Service Request",
                filters={
                    "request_state": "Activated",
                    "status": ["in", OPEN_CASE_STATUSES],
                    "assigned_staff": ["is", "set"],
                },
                pluck="name",
                order_by="modified asc, name asc",
                limit_page_length=remaining,
            )
            names.extend(name for name in existing_names if name not in names)
        summary["scanned"] = len(names)
        for index, name in enumerate(names):
            if monotonic() - started >= RECOVERY_RUNTIME_SECONDS:
                summary["runtime_budget_stopped"] = len(names) - index
                break
            savepoint = f"assign_{index}"
            frappe.db.savepoint(savepoint)
            try:
                locked = frappe.db.get_value(
                    "OMC Service Request", name, "name", for_update=True, wait=False
                )
                if not locked:
                    summary["locked"] += 1
                    continue
                request = frappe.get_doc("OMC Service Request", name)
                if _text(request.assigned_staff):
                    if active_assignable_user(request.assigned_staff):
                        summary["already_assigned"] += 1
                    else:
                        summary["invalid_existing"] += 1
                        summary["notifications_created"] += int(
                            _escalate_assignment_issue(
                                request,
                                "the existing assignee is disabled or lacks an assignable OMC staff persona",
                            )
                        )
                    continue
                if not request.service or not frappe.db.exists("OMC Service", request.service):
                    raise frappe.ValidationError("Linked OMC Service is missing.")
                decision = resolve_assignee(
                    frappe.get_doc("OMC Service", request.service),
                    referral_owner=getattr(request, "referral_owner", None),
                )
                if not decision.get("candidate"):
                    summary["no_candidate"] += 1
                    summary["notifications_created"] += int(
                        _escalate_assignment_issue(
                            request, decision.get("reason") or "no eligible candidate"
                        )
                    )
                    frappe.logger("omc_app.scheduler").warning(
                        "OMC assignment recovery found no candidate for %s: %s",
                        request.name,
                        decision.get("reason"),
                    )
                    continue
                result = apply_assignment(request, decision)
                summary["assigned"] += 1
                summary["notifications_created"] += int(result["notification_created"])
            except Exception as error:
                frappe.db.rollback(save_point=savepoint)
                summary["failed"] += 1
                frappe.log_error(
                    title=f"OMC assignment recovery failed: {name}",
                    message=f"{error.__class__.__name__}: {_text(error)}"[:1000],
                )
        return {**summary, "status": "completed"}
    finally:
        try:
            lock.release()
        except Exception:
            pass
