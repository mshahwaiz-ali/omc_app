"""Manager-only recovery APIs for unresolved ERP Service/Task synchronization."""
from __future__ import annotations

from time import monotonic

import frappe
from frappe.utils import add_to_date, cint, get_datetime, now_datetime

from omc_app.api import bridge_outbox, capabilities, erp_activation

RETRYABLE_STATUSES = {"Pending Configuration", "Repair Required", "Failed"}
MAX_AUTOMATIC_ATTEMPTS = 5
RETRY_DELAYS_HOURS = (1, 2, 4, 8, 24)
CONFIGURATION_DELAYS_HOURS = (24, 48, 96, 168, 168)
AUTOMATIC_BATCH_SIZE = 25
AUTOMATIC_RUNTIME_SECONDS = 45
JOB_LOCK_TIMEOUT_SECONDS = 55 * 60
TRANSIENT_EXCEPTION_NAMES = {
    "DeadlockError",
    "LockTimeoutError",
    "QueryTimeoutError",
    "RedisConnectionError",
}
TRANSIENT_DB_ERROR_CODES = {1205, 1213, 2006, 2013}


def _text(value) -> str:
    return str(value or "").strip()


def _is_historical_request(request) -> bool:
    return _text(getattr(request, "request_state", None)) == "Historical"


def _assert_recovery_manager() -> str:
    user = _text(getattr(getattr(frappe, "session", None), "user", None))
    if not user or user == "Guest":
        frappe.throw("Login is required.", frappe.PermissionError)
    capabilities.require("can_retry_sync", user=user)
    return user


def _bounded_int(value, *, default: int, minimum: int, maximum: int) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        parsed = default
    return min(max(parsed, minimum), maximum)


def _set_retry_values(request, values):
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


def _category_for_status(status: str) -> str:
    if status == "Pending Configuration":
        return "Configuration"
    if status == "Repair Required":
        return "Repairable"
    if status == "Failed":
        return "Transient"
    return "Permanent"


def _category_for_exception(error: Exception) -> str:
    if error.__class__.__name__ in TRANSIENT_EXCEPTION_NAMES:
        return "Transient"
    error_code = error.args[0] if getattr(error, "args", None) else None
    return "Transient" if error_code in TRANSIENT_DB_ERROR_CODES else "Permanent"


def _delay_for(category: str, attempt: int) -> int:
    delays = CONFIGURATION_DELAYS_HOURS if category == "Configuration" else RETRY_DELAYS_HOURS
    return delays[min(max(attempt, 1), len(delays)) - 1]


def _record_attempt_result(request, *, status: str, attempt: int, category: str | None = None):
    now = now_datetime()
    if status == "Synced":
        _set_retry_values(
            request,
            {
                "erp_retry_count": 0,
                "erp_last_attempt_at": now,
                "erp_next_attempt_at": None,
                "erp_last_failure_category": None,
                "erp_retry_exhausted_at": None,
                "erp_last_success_at": now,
            },
        )
        return {"exhausted": False, "next_attempt_at": None}

    category = category or _category_for_status(status)
    exhausted = category == "Permanent" or attempt >= MAX_AUTOMATIC_ATTEMPTS
    next_attempt = None if exhausted else add_to_date(now, hours=_delay_for(category, attempt))
    _set_retry_values(
        request,
        {
            "erp_retry_count": attempt,
            "erp_last_attempt_at": now,
            "erp_next_attempt_at": next_attempt,
            "erp_last_failure_category": category,
            "erp_retry_exhausted_at": now if exhausted else None,
        },
    )
    return {"exhausted": exhausted, "next_attempt_at": next_attempt}


def _bridge_operation(request_name: str):
    row = frappe.db.get_value(
        "OMC Bridge Operation",
        {"service_request": request_name},
        ["name", "state", "attempt_count", "next_attempt_at"],
        as_dict=True,
    )
    return row or None


@frappe.whitelist()
def get_erp_sync_issues(limit_start=0, limit_page_length=50):
    """Return a bounded manager-only queue of unresolved synchronization records."""
    _assert_recovery_manager()
    start = _bounded_int(limit_start, default=0, minimum=0, maximum=1_000_000)
    page_length = _bounded_int(limit_page_length, default=50, minimum=1, maximum=200)
    filters = {
        "erp_sync_status": ["in", sorted(RETRYABLE_STATUSES)],
        "request_state": ["!=", "Historical"],
    }
    rows = frappe.get_all(
        "OMC Service Request",
        filters=filters,
        fields=[
            "name", "title", "status", "request_state", "service", "customer_profile",
            "manual_customer", "assigned_staff", "erp_sync_status", "erp_sync_error",
            "erp_customer", "erp_service", "erp_task", "erp_retry_count",
            "erp_last_attempt_at", "erp_next_attempt_at", "erp_last_failure_category",
            "erp_retry_exhausted_at", "erp_last_success_at", "modified",
        ],
        order_by="modified asc, name asc",
        limit_start=start,
        limit_page_length=page_length,
    )
    issues = []
    for row in rows:
        item = dict(row)
        operation = _bridge_operation(row.name)
        item["bridge_operation"] = operation.name if operation else ""
        item["bridge_state"] = operation.state if operation else ""
        item["bridge_attempt_count"] = operation.attempt_count if operation else 0
        issues.append(item)
    return {
        "issues": issues,
        "count": len(issues),
        "total": frappe.db.count("OMC Service Request", filters=filters),
        "limit_start": start,
        "limit_page_length": page_length,
    }


@frappe.whitelist(methods=["POST"])
def retry_erp_sync(request_name=None, reset_exhaustion=0):
    """Explicitly retry one request through the durable bridge authority."""
    actor = _assert_recovery_manager()
    request_name = _text(request_name)
    if not request_name:
        frappe.throw("request_name is required.", frappe.ValidationError)

    locked = frappe.db.get_value("OMC Service Request", request_name, "name", for_update=True)
    if not locked:
        frappe.throw("Service request not found.", frappe.DoesNotExistError)
    request = frappe.get_doc("OMC Service Request", locked)

    if _is_historical_request(request):
        frappe.throw(
            "Historical service requests are not eligible for ERP synchronization recovery.",
            frappe.ValidationError,
        )

    operation = _bridge_operation(request.name)
    if operation:
        if operation.state == "Failed":
            if getattr(request, "erp_retry_exhausted_at", None) and not cint(reset_exhaustion):
                frappe.throw(
                    "ERP synchronization retries are exhausted. Confirm reset_exhaustion to recover the failed bridge manually.",
                    frappe.ValidationError,
                )
            result = bridge_outbox._recover_failed_operation(
                operation.name,
                actor=actor,
                reason="Authorized ERP synchronization retry requested.",
            )
            _set_retry_values(
                request,
                {
                    "erp_retry_count": 0,
                    "erp_retry_exhausted_at": None,
                    "erp_next_attempt_at": None,
                    "erp_last_failure_category": None,
                },
            )
            return {
                "request_name": request.name,
                "status": "Pending",
                "operation": operation.name,
                "bridge_state": result["state"],
                "recovered": True,
                "exhausted": False,
                "next_attempt_at": None,
            }
        if operation.state in {"Pending", "Retry", "Processing"}:
            return {
                "request_name": request.name,
                "status": "Pending",
                "operation": operation.name,
                "bridge_state": operation.state,
                "recovered": False,
                "exhausted": False,
                "next_attempt_at": operation.next_attempt_at,
            }
        if operation.state == "Completed":
            return {
                "request_name": request.name,
                "status": "Synced",
                "operation": operation.name,
                "bridge_state": "Completed",
                "recovered": False,
                "exhausted": False,
                "next_attempt_at": None,
            }
        frappe.throw(
            "The bridge operation is cancelled and cannot be revived implicitly. Reconcile the request before creating new activation eligibility.",
            frappe.ValidationError,
        )

    service_name = _text(getattr(request, "service", None))
    if not service_name or not frappe.db.exists("OMC Service", service_name):
        frappe.throw(
            "The linked OMC Service is missing; synchronization cannot be repaired.",
            frappe.ValidationError,
        )

    result = erp_activation.activate_request(
        request,
        service=frappe.get_doc("OMC Service", service_name),
        repair=True,
    )
    if not result.get("eligible", True):
        return {
            "request_name": request.name,
            **result,
            "exhausted": False,
            "next_attempt_at": None,
        }
    return {
        "request_name": request.name,
        **result,
        "exhausted": False,
        "next_attempt_at": None,
    }


def _job_lock():
    site = getattr(frappe.local, "site", "site")
    return frappe.cache().lock(
        f"omc_app:{site}:erp_sync_recovery",
        timeout=JOB_LOCK_TIMEOUT_SECONDS,
        blocking_timeout=0,
    )


def run_automatic_erp_sync_recovery():
    """Recover only pre-outbox configuration failures; terminal bridge failures require a human action."""
    summary = {
        "scanned": 0,
        "retried": 0,
        "synced": 0,
        "not_due": 0,
        "manual_recovery_required": 0,
        "exhausted": 0,
        "locked": 0,
        "failed": 0,
        "runtime_budget_stopped": 0,
    }
    lock = _job_lock()
    if not lock.acquire(blocking=False):
        return {**summary, "status": "skipped_locked"}
    started = monotonic()
    now = now_datetime()
    try:
        rows = frappe.get_all(
            "OMC Service Request",
            filters={
                "erp_sync_status": ["in", sorted(RETRYABLE_STATUSES)],
                "request_state": ["!=", "Historical"],
                "erp_retry_exhausted_at": ["is", "not set"],
            },
            fields=["name", "erp_next_attempt_at"],
            order_by="erp_next_attempt_at asc, modified asc, name asc",
            limit_page_length=AUTOMATIC_BATCH_SIZE,
        )
        summary["scanned"] = len(rows)
        for index, row in enumerate(rows):
            if monotonic() - started >= AUTOMATIC_RUNTIME_SECONDS:
                summary["runtime_budget_stopped"] = len(rows) - index
                break
            if row.erp_next_attempt_at and get_datetime(row.erp_next_attempt_at) > get_datetime(now):
                summary["not_due"] += 1
                continue

            operation = _bridge_operation(row.name)
            if operation:
                if operation.state == "Failed":
                    summary["manual_recovery_required"] += 1
                else:
                    summary["not_due"] += 1
                continue

            savepoint = f"erp_retry_{index}"
            frappe.db.savepoint(savepoint)
            attempt = 1
            request = None
            try:
                locked = frappe.db.get_value(
                    "OMC Service Request", row.name, "name", for_update=True, wait=False
                )
                if not locked:
                    summary["locked"] += 1
                    continue
                request = frappe.get_doc("OMC Service Request", row.name)
                attempt = int(getattr(request, "erp_retry_count", 0) or 0) + 1
                service_name = _text(getattr(request, "service", None))
                if not service_name or not frappe.db.exists("OMC Service", service_name):
                    _record_attempt_result(request, status="Failed", attempt=attempt, category="Permanent")
                    summary["exhausted"] += 1
                    continue

                result = erp_activation.activate_request(
                    request,
                    service=frappe.get_doc("OMC Service", service_name),
                    repair=True,
                )
                if not result.get("eligible", True):
                    summary["not_due"] += 1
                    continue

                summary["retried"] += 1
                if result.get("status") == "Synced":
                    summary["synced"] += 1
            except Exception as error:
                frappe.db.rollback(save_point=savepoint)
                category = _category_for_exception(error)
                if request is None and frappe.db.exists("OMC Service Request", row.name):
                    request = frappe.get_doc("OMC Service Request", row.name)
                if request is not None:
                    frappe.db.set_value(
                        "OMC Service Request",
                        request.name,
                        {"erp_sync_status": "Failed", "erp_sync_error": _text(error)[:1000]},
                        update_modified=False,
                    )
                    state = _record_attempt_result(
                        request,
                        status="Failed",
                        attempt=attempt,
                        category=category,
                    )
                    summary["exhausted"] += int(state["exhausted"])
                summary["failed"] += 1
                frappe.log_error(
                    title=f"OMC ERP retry failed: {row.name}",
                    message=f"{error.__class__.__name__}: {_text(error)}"[:1000],
                )
        return {**summary, "status": "completed"}
    finally:
        try:
            lock.release()
        except Exception:
            pass
