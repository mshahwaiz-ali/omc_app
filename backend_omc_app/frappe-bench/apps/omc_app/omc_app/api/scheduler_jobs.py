from __future__ import annotations

from collections.abc import Callable
from time import monotonic
from typing import Any

import frappe

from omc_app.api import auth_cleanup, mobile, workflow_automation

LOGGER_NAME = "omc_app.scheduler"


def _job_name(job: Callable[[], Any]) -> str:
    module = getattr(job, "__module__", "")
    name = getattr(job, "__name__", job.__class__.__name__)
    return f"{module}.{name}" if module else name


def _duration_ms(started_at: float) -> int:
    return max(0, round((monotonic() - started_at) * 1000))


def _log_completion(result: dict[str, Any]) -> None:
    frappe.logger(LOGGER_NAME).info(
        "OMC scheduled job %s: %s (%sms)",
        result["status"],
        result["job"],
        result["duration_ms"],
    )


def _log_run_summary(summary: dict[str, Any]) -> None:
    logger = frappe.logger(LOGGER_NAME)
    logger.info(
        "OMC %s scheduler run %s: %s completed, %s failed (%sms)",
        summary["schedule"],
        summary["status"],
        summary["completed"],
        summary["failed"],
        summary["duration_ms"],
    )
    if summary["failed_jobs"]:
        logger.warning(
            "OMC %s scheduler failed jobs: %s",
            summary["schedule"],
            ", ".join(summary["failed_jobs"]),
        )


def _run_job(job: Callable[[], Any]) -> dict[str, Any]:
    """Run one scheduler task with an isolated transaction and result summary."""
    name = _job_name(job)
    started_at = monotonic()
    try:
        result = job()
        frappe.db.commit()
    except Exception:
        frappe.db.rollback()
        failed = {
            "job": name,
            "status": "failed",
            "result": None,
            "duration_ms": _duration_ms(started_at),
        }
        frappe.log_error(
            title=f"OMC scheduled job failed: {name}",
            message=frappe.get_traceback(),
        )
        _log_completion(failed)
        return failed

    completed = {
        "job": name,
        "status": "completed",
        "result": result,
        "duration_ms": _duration_ms(started_at),
    }
    _log_completion(completed)
    return completed


def _run_jobs(
    schedule: str,
    jobs: tuple[Callable[[], Any], ...],
) -> dict[str, Any]:
    started_at = monotonic()
    results = [_run_job(job) for job in jobs]
    completed = sum(item["status"] == "completed" for item in results)
    failed_jobs = [item["job"] for item in results if item["status"] == "failed"]
    failed = len(failed_jobs)
    summary = {
        "schedule": schedule,
        "status": "completed" if failed == 0 else "completed_with_failures",
        "job_count": len(results),
        "completed": completed,
        "failed": failed,
        "failed_jobs": failed_jobs,
        "duration_ms": _duration_ms(started_at),
        "jobs": results,
    }
    _log_run_summary(summary)
    return summary


def run_hourly_jobs() -> dict[str, Any]:
    """Run hourly OMC maintenance tasks without cross-job failure propagation."""
    return _run_jobs(
        "hourly",
        (
            workflow_automation.run_hourly_workflow_checks,
            auth_cleanup.cleanup_pending_registrations,
        ),
    )


def run_daily_jobs() -> dict[str, Any]:
    """Run daily OMC maintenance tasks without cross-job failure propagation."""
    return _run_jobs(
        "daily",
        (
            workflow_automation.run_daily_workflow_checks,
            mobile.cleanup_notifications,
        ),
    )
