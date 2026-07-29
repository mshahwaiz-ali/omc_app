from __future__ import annotations

from collections.abc import Callable
from typing import Any

import frappe

from omc_app.api import auth_cleanup, mobile, workflow_automation


def _job_name(job: Callable[[], Any]) -> str:
    module = getattr(job, "__module__", "")
    name = getattr(job, "__name__", job.__class__.__name__)
    return f"{module}.{name}" if module else name


def _run_job(job: Callable[[], Any]) -> dict[str, Any]:
    """Run one scheduler task with rollback and structured failure reporting."""
    name = _job_name(job)
    try:
        result = job()
    except Exception:
        frappe.db.rollback()
        frappe.log_error(
            title=f"OMC scheduled job failed: {name}",
            message=frappe.get_traceback(),
        )
        return {
            "job": name,
            "status": "failed",
            "result": None,
        }

    return {
        "job": name,
        "status": "completed",
        "result": result,
    }


def _run_jobs(jobs: tuple[Callable[[], Any], ...]) -> dict[str, Any]:
    results = [_run_job(job) for job in jobs]
    completed = sum(item["status"] == "completed" for item in results)
    failed = len(results) - completed
    return {
        "completed": completed,
        "failed": failed,
        "jobs": results,
    }


def run_hourly_jobs() -> dict[str, Any]:
    """Run hourly OMC maintenance tasks without cross-job failure propagation."""
    return _run_jobs(
        (
            workflow_automation.run_hourly_workflow_checks,
            auth_cleanup.cleanup_pending_registrations,
        )
    )


def run_daily_jobs() -> dict[str, Any]:
    """Run daily OMC maintenance tasks without cross-job failure propagation."""
    return _run_jobs(
        (
            workflow_automation.run_daily_workflow_checks,
            mobile.cleanup_notifications,
        )
    )
