from __future__ import annotations

import re
import uuid

import frappe
from frappe.utils import cint, now_datetime


RUN_DOCTYPE = "OMC Reconciliation Run"
CHECKPOINT_DOCTYPE = "OMC Reconciliation Checkpoint"
_SAFE_CODE = re.compile(r"^[a-z0-9_.:-]{1,140}$")


def _text(value) -> str:
    return str(value or "").strip()


def _safe_code(value, fallback="unspecified") -> str:
    value = _text(value).lower().replace(" ", "_")
    return value if _SAFE_CODE.fullmatch(value) else fallback


def _checkpoint_key(job_key: str, domain: str) -> str:
    return f"{_safe_code(domain)}:{_safe_code(job_key)}"[:140]


def _triggered_by() -> str:
    user = _text(getattr(getattr(frappe, "session", None), "user", None))
    return user if user and user != "Guest" else "scheduler"


def get_or_create_checkpoint(*, job_key: str, domain: str):
    key = _checkpoint_key(job_key, domain)
    name = frappe.db.get_value(CHECKPOINT_DOCTYPE, {"checkpoint_key": key}, "name")
    if name:
        return frappe.get_doc(CHECKPOINT_DOCTYPE, name)

    doc = frappe.get_doc(
        {
            "doctype": CHECKPOINT_DOCTYPE,
            "checkpoint_key": key,
            "job_key": _text(job_key),
            "domain": _text(domain),
            "cursor_value": "",
            "cycle_count": 0,
        }
    )
    try:
        doc.insert(ignore_permissions=True)
        return doc
    except frappe.DuplicateEntryError:
        name = frappe.db.get_value(CHECKPOINT_DOCTYPE, {"checkpoint_key": key}, "name")
        if not name:
            raise
        return frappe.get_doc(CHECKPOINT_DOCTYPE, name)


def start_run(*, job_key: str, domain: str, batch_size: int):
    checkpoint = get_or_create_checkpoint(job_key=job_key, domain=domain)
    run_id = uuid.uuid4().hex
    run = frappe.get_doc(
        {
            "doctype": RUN_DOCTYPE,
            "run_id": run_id,
            "job_key": _text(job_key),
            "domain": _text(domain),
            "status": "Running",
            "started_at": now_datetime(),
            "checkpoint_key": checkpoint.checkpoint_key,
            "cursor_start": _text(checkpoint.cursor_value),
            "cursor_end": _text(checkpoint.cursor_value),
            "batch_size": max(1, min(cint(batch_size or 100), 500)),
            "triggered_by": _triggered_by(),
        }
    )
    run.insert(ignore_permissions=True)
    # Persist the run before doing work so a worker crash leaves durable evidence.
    frappe.db.commit()
    return run, checkpoint


def checkpoint_progress(
    run,
    checkpoint,
    *,
    cursor: str,
    counters: dict[str, int],
    source_version: str = "",
) -> None:
    now = now_datetime()
    run_values = {
        "cursor_end": _text(cursor),
        "scanned_count": cint(counters.get("scanned")),
        "changed_count": cint(counters.get("changed")),
        "review_count": cint(counters.get("review")),
        "quarantine_count": cint(counters.get("quarantine")),
        "failed_count": cint(counters.get("failed")),
    }
    frappe.db.set_value(RUN_DOCTYPE, run.name, run_values, update_modified=False)
    frappe.db.set_value(
        CHECKPOINT_DOCTYPE,
        checkpoint.name,
        {
            "cursor_value": _text(cursor),
            "last_run_id": run.run_id,
            "last_completed_at": now,
            "source_version": _text(source_version),
        },
        update_modified=False,
    )
    for key, value in run_values.items():
        setattr(run, key, value)
    checkpoint.cursor_value = _text(cursor)
    checkpoint.last_run_id = run.run_id
    checkpoint.last_completed_at = now
    checkpoint.source_version = _text(source_version)
    frappe.db.commit()


def complete_run(
    run,
    checkpoint,
    *,
    counters: dict[str, int],
    cursor: str,
    cycle_completed: bool,
    source_version: str = "",
) -> dict:
    now = now_datetime()
    next_cursor = "" if cycle_completed else _text(cursor)
    cycle_count = cint(checkpoint.cycle_count or 0) + int(bool(cycle_completed))
    status = "Partial" if cint(counters.get("failed")) else "Completed"

    frappe.db.set_value(
        RUN_DOCTYPE,
        run.name,
        {
            "status": status,
            "completed_at": now,
            "cursor_end": _text(cursor),
            "scanned_count": cint(counters.get("scanned")),
            "changed_count": cint(counters.get("changed")),
            "review_count": cint(counters.get("review")),
            "quarantine_count": cint(counters.get("quarantine")),
            "failed_count": cint(counters.get("failed")),
            "cycle_completed": int(bool(cycle_completed)),
        },
        update_modified=False,
    )
    frappe.db.set_value(
        CHECKPOINT_DOCTYPE,
        checkpoint.name,
        {
            "cursor_value": next_cursor,
            "last_run_id": run.run_id,
            "last_completed_at": now,
            "cycle_count": cycle_count,
            "source_version": _text(source_version),
        },
        update_modified=False,
    )
    frappe.db.commit()
    return {
        "run_id": run.run_id,
        "status": status,
        "cursor_start": _text(run.cursor_start),
        "cursor_end": _text(cursor),
        "next_cursor": next_cursor,
        "cycle_completed": bool(cycle_completed),
        **{key: cint(counters.get(key)) for key in ("scanned", "changed", "review", "quarantine", "failed")},
    }


def fail_run(run, *, error_code: str, counters: dict[str, int] | None = None) -> dict:
    counters = counters or {}
    code = _safe_code(error_code, "reconciliation_failed")
    frappe.db.rollback()
    frappe.db.set_value(
        RUN_DOCTYPE,
        run.name,
        {
            "status": "Failed",
            "completed_at": now_datetime(),
            "scanned_count": cint(counters.get("scanned")),
            "changed_count": cint(counters.get("changed")),
            "review_count": cint(counters.get("review")),
            "quarantine_count": cint(counters.get("quarantine")),
            "failed_count": max(1, cint(counters.get("failed"))),
            "safe_error_code": code,
        },
        update_modified=False,
    )
    frappe.db.commit()
    return {"run_id": run.run_id, "status": "Failed", "safe_error_code": code}
