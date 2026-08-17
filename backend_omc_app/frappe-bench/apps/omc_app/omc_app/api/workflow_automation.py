from __future__ import annotations

import frappe
from frappe.utils import add_days, add_to_date, getdate, now_datetime

from omc_app.api import mobile

OPEN_CASE_STATUSES = [
    "Open",
    "In Progress",
    "Waiting for Customer",
    "Waiting for Payment",
]
REVIEW_PAYMENT_STATUSES = ["Receipt Submitted", "Under Review"]
REVIEW_DOCUMENT_STATUSES = ["Uploaded"]
HOURLY_BATCH_SIZE = 500
DAILY_BATCH_SIZE = 500


def _notification_exists(
    *,
    title,
    reference_doctype,
    reference_name,
    recipient_user=None,
    customer_profile=None,
    since=None,
):
    filters = {
        "title": title,
        "reference_doctype": reference_doctype,
        "reference_name": reference_name,
    }
    if recipient_user:
        filters["recipient_user"] = recipient_user
    if customer_profile:
        filters["customer_profile"] = customer_profile
    if since:
        filters["creation"] = [">=", since]
    return bool(frappe.db.exists("OMC Notification", filters))


def _notify_once(
    *,
    title,
    message,
    notification_type,
    reference_doctype,
    reference_name,
    recipient_user=None,
    customer_profile=None,
    dedupe_hours=24,
):
    since = add_to_date(now_datetime(), hours=-dedupe_hours)
    if _notification_exists(
        title=title,
        reference_doctype=reference_doctype,
        reference_name=reference_name,
        recipient_user=recipient_user,
        customer_profile=customer_profile,
        since=since,
    ):
        return None

    return mobile._create_customer_notification(
        customer_profile=customer_profile,
        recipient_user=recipient_user,
        title=title,
        message=message,
        notification_type=notification_type,
        reference_doctype=reference_doctype,
        reference_name=reference_name,
    )


def _reviewer_users():
    users = frappe.get_all(
        "Has Role",
        filters={
            "role": ["in", ["OMC Admin", "OMC Manager"]],
            "parenttype": "User",
        },
        pluck="parent",
    )
    if not users:
        return []

    return frappe.get_all(
        "User",
        filters={
            "name": ["in", list(set(users))],
            "enabled": 1,
            "user_type": "System User",
        },
        pluck="name",
    )


def _notify_reviewers_once(
    *,
    title,
    message,
    reference_doctype,
    reference_name,
    reviewers=None,
):
    created = []
    for user in reviewers if reviewers is not None else _reviewer_users():
        notification = _notify_once(
            title=title,
            message=message,
            notification_type="Workflow",
            reference_doctype=reference_doctype,
            reference_name=reference_name,
            recipient_user=user,
        )
        if notification:
            created.append(notification.name)
    return created


def run_hourly_workflow_checks():
    """Compatibility wrapper for the isolated hourly automation jobs."""
    from omc_app.api import review_routing, service_assignment

    return {
        "unassigned_recovery": service_assignment.run_unassigned_recovery(),
        "review_routing": review_routing.run_review_assignment_checks(),
    }


def run_daily_workflow_checks():
    cases = frappe.get_all(
        "OMC Service Request",
        filters={"status": ["in", OPEN_CASE_STATUSES]},
        fields=[
            "name",
            "title",
            "status",
            "customer_profile",
            "assigned_staff",
            "expected_completion_date",
            "modified",
        ],
        order_by="modified asc",
        limit_page_length=DAILY_BATCH_SIZE,
    )

    reviewers = set(_reviewer_users())
    summary = {
        "cases_scanned": len(cases),
        "reviewers": len(reviewers),
        "customer_reminders_created": 0,
        "overdue_escalations_created": 0,
        "missing_customer_profile": 0,
    }
    today = getdate()

    for service_case in cases:
        if service_case.status in {"Waiting for Customer", "Waiting for Payment"}:
            if not service_case.customer_profile:
                summary["missing_customer_profile"] += 1
            elif service_case.status == "Waiting for Customer":
                notification = _notify_once(
                    title="Action required on your service request",
                    message=(
                        f"{service_case.name} needs information or a corrected item "
                        "from you."
                    ),
                    notification_type="Reminder",
                    reference_doctype="OMC Service Request",
                    reference_name=service_case.name,
                    customer_profile=service_case.customer_profile,
                    dedupe_hours=72,
                )
                summary["customer_reminders_created"] += int(bool(notification))
            else:
                notification = _notify_once(
                    title="Payment pending",
                    message=f"Payment is pending for {service_case.name}.",
                    notification_type="Payment",
                    reference_doctype="OMC Service Request",
                    reference_name=service_case.name,
                    customer_profile=service_case.customer_profile,
                    dedupe_hours=72,
                )
                summary["customer_reminders_created"] += int(bool(notification))

        due_date = (
            getdate(service_case.expected_completion_date)
            if service_case.expected_completion_date
            else None
        )
        if due_date and due_date < today:
            recipients = set(reviewers)
            if service_case.assigned_staff:
                recipients.add(service_case.assigned_staff)
            for user in recipients:
                notification = _notify_once(
                    title="Service request overdue",
                    message=(
                        f"{service_case.name} passed its expected completion date "
                        f"of {due_date}."
                    ),
                    notification_type="Escalation",
                    reference_doctype="OMC Service Request",
                    reference_name=service_case.name,
                    recipient_user=user,
                    dedupe_hours=24,
                )
                summary["overdue_escalations_created"] += int(bool(notification))

    return summary


def completion_blockers(service_case, *, require_erp_task_completed=True):
    blockers = []

    required_templates = mobile._service_required_documents(
        service_case.service
    )
    documents = frappe.get_all(
        "OMC Service Document",
        filters={
            "service_request": service_case.name,
            "visible_to_customer": 1,
        },
        fields=[
            "document_title",
            "document_type",
            "status",
            "attachment",
        ],
    )
    document_payload = [
        {
            "document_title": getattr(
                row,
                "document_title",
                "",
            )
            or "",
            "document_type": getattr(
                row,
                "document_type",
                "",
            )
            or "",
            "status": getattr(row, "status", "") or "",
            "attachment": getattr(
                row,
                "attachment",
                "",
            )
            or "",
        }
        for row in documents
    ]

    if not mobile._required_documents_complete(
        required_templates,
        document_payload,
    ):
        blockers.append(
            "Required documents are not fully approved."
        )

    active_payments = frappe.get_all(
        "OMC Service Payment",
        filters={
            "service_request": service_case.name,
            "status": ["not in", ["Cancelled"]],
        },
        fields=["status"],
    )
    if active_payments and any(
        (payment.status or "") != "Paid"
        for payment in active_payments
    ):
        blockers.append(
            "Required payment has not been confirmed."
        )

    erp_task = str(
        getattr(service_case, "erp_task", None) or ""
    ).strip()
    if erp_task and require_erp_task_completed:
        task_status = frappe.db.get_value(
            "Task",
            erp_task,
            "status",
        )
        if (task_status or "").strip() != "Completed":
            blockers.append(
                "Operational ERP Task is not complete."
            )

    return blockers




def record_completion_attribution(
    service_case,
    *,
    source,
    actor=None,
):
    # Persist the first trusted completion actor without rewriting history.
    if (getattr(service_case, "status", None) or "") == "Completed":
        existing_actor = getattr(service_case, "completed_by", None)
        existing_source = getattr(service_case, "completion_source", None)
        if existing_actor or existing_source:
            return {
                "updated": False,
                "completed_by": existing_actor or "",
                "completion_source": existing_source or "",
            }

    actor = str(
        actor
        or getattr(service_case, "assigned_staff", None)
        or ""
    ).strip()
    source = str(source or "").strip()

    meta = getattr(service_case, "meta", None)

    def has_field(fieldname):
        if meta is None:
            return True
        get_field = getattr(meta, "get_field", None)
        if not callable(get_field):
            return True
        return bool(get_field(fieldname))

    values = {}
    if actor and has_field("completed_by"):
        values["completed_by"] = actor
    if source and has_field("completion_source"):
        values["completion_source"] = source

    if not values:
        return {
            "updated": False,
            "completed_by": "",
            "completion_source": "",
        }

    setter = getattr(service_case, "set", None)
    for fieldname, value in values.items():
        if callable(setter):
            setter(fieldname, value)
        else:
            setattr(service_case, fieldname, value)

    return {
        "updated": True,
        "completed_by": values.get("completed_by", ""),
        "completion_source": values.get("completion_source", ""),
    }

def _set_case_todos_terminal(service_case, status):
    references = [("OMC Service Request", service_case.name)]
    erp_task = str(getattr(service_case, "erp_task", None) or "").strip()
    if erp_task:
        references.append(("Task", erp_task))

    for reference_type, reference_name in references:
        frappe.db.set_value(
            "ToDo",
            {
                "reference_type": reference_type,
                "reference_name": reference_name,
                "status": ["not in", ["Closed", "Cancelled"]],
            },
            "status",
            status,
            update_modified=False,
        )


def finalize_cancelled_case(
    service_case,
    *,
    reason=None,
    cancelled_by_customer=False,
    sync_erp=True,
):
    """Finalize one cancellation consistently without committing the transaction."""

    if sync_erp:
        from omc_app.api import erp_task_status_sync

        erp_task_status_sync.cancel_linked_erp_records(service_case)

    _set_case_todos_terminal(service_case, "Cancelled")
    from omc_app.api import review_routing

    review_routing.close_parent_review_todos(service_case.name, cancelled=True)
    title = getattr(service_case, "title", None) or service_case.name
    reason = str(reason or "").strip()
    message = f"{title} has been cancelled."
    if reason:
        message = f"{message} Reason: {reason}"

    mobile._create_service_timeline_entry(
        service_request=service_case.name,
        event_type="Status Updated",
        title="Service Request Cancelled",
        description=message,
        visible_to_customer=1,
    )

    if cancelled_by_customer:
        assigned_staff = str(
            getattr(service_case, "assigned_staff", None) or ""
        ).strip()
        if assigned_staff:
            mobile._create_customer_notification(
                recipient_user=assigned_staff,
                title="Customer cancelled service request",
                message=message,
                notification_type="Service",
                reference_doctype="OMC Service Request",
                reference_name=service_case.name,
            )
    else:
        customer_profile = str(
            getattr(service_case, "customer_profile", None) or ""
        ).strip()
        if customer_profile:
            mobile._create_customer_notification(
                customer_profile=customer_profile,
                title="Service request cancelled",
                message=message,
                notification_type="Service",
                reference_doctype="OMC Service Request",
                reference_name=service_case.name,
            )


def finalize_completed_case(service_case):
    frappe.db.set_value(
        "ToDo",
        {
            "reference_type": "OMC Service Request",
            "reference_name": service_case.name,
            "status": ["not in", ["Closed", "Cancelled"]],
        },
        "status",
        "Closed",
        update_modified=False,
    )
    from omc_app.api import review_routing

    review_routing.close_parent_review_todos(service_case.name)

    message = (
        f"{service_case.title or service_case.name} has been completed. "
        "Please review the completed service and share your feedback."
    )
    mobile._create_service_timeline_entry(
        service_request=service_case.name,
        event_type="Completed",
        title="Service Completed",
        description=message,
        visible_to_customer=1,
    )
    mobile._create_customer_notification(
        customer_profile=service_case.customer_profile,
        title="Service completed",
        message=message,
        notification_type="Service",
        reference_doctype="OMC Service Request",
        reference_name=service_case.name,
        mobile_route=f"/my-services/{service_case.name}",
        event_key=f"service.completed:{service_case.name}",
    )
