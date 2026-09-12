"""One-time, idempotent architecture reconciliation for OMC bridge upgrades.

This module is intentionally not scheduled and is not called from normal
``bench migrate``. Operators run ``preflight`` first, review conflicts, then
invoke ``apply`` with the explicit confirmation token.
"""
from __future__ import annotations

from typing import Any

import frappe

from omc_app.api import service_task_links, staff_authority


CONFIRM_TOKEN = "APPLY_OMC_ARCHITECTURE_V1"


def _text(value: Any) -> str:
    return str(value or "").strip()


def _service_task_plan(limit: int = 0) -> dict[str, Any]:
    filters = {"erp_task": ["is", "set"]}
    rows = frappe.get_all(
        "OMC Service Request",
        filters=filters,
        fields=["name", "erp_task", "erp_service"],
        order_by="creation asc, name asc",
        limit_page_length=max(int(limit or 0), 0),
    )

    result = {
        "scanned": 0,
        "already_linked": 0,
        "backfill_ready": 0,
        "missing_task": 0,
        "conflicts": 0,
        "samples": {
            "backfill_ready": [],
            "missing_task": [],
            "conflicts": [],
        },
    }

    link_available = service_task_links._link_doctype_available()
    for row in rows:
        result["scanned"] += 1
        request_name = _text(row.name)
        task_name = _text(row.erp_task)
        if not task_name or not frappe.db.exists("Task", task_name):
            result["missing_task"] += 1
            if len(result["samples"]["missing_task"]) < 25:
                result["samples"]["missing_task"].append(
                    {"service_request": request_name, "task": task_name}
                )
            continue

        existing_request = ""
        if link_available:
            existing_request = _text(
                frappe.db.get_value(
                    service_task_links.LINK_DOCTYPE,
                    {"erp_task": task_name},
                    "service_request",
                )
            )
        if existing_request == request_name:
            result["already_linked"] += 1
            continue
        if existing_request and existing_request != request_name:
            result["conflicts"] += 1
            if len(result["samples"]["conflicts"]) < 25:
                result["samples"]["conflicts"].append(
                    {
                        "service_request": request_name,
                        "task": task_name,
                        "linked_request": existing_request,
                    }
                )
            continue

        result["backfill_ready"] += 1
        if len(result["samples"]["backfill_ready"]) < 25:
            result["samples"]["backfill_ready"].append(
                {"service_request": request_name, "task": task_name}
            )

    return result


def _staff_access_plan(limit: int = 0) -> dict[str, Any]:
    rows = frappe.get_all(
        "OMC Staff Access",
        fields=[
            "name",
            "user",
            "employee",
            "legacy_staff_profile",
            "persona_snapshot",
            "access_status",
            "reconciliation_status",
        ],
        order_by="user asc",
        limit_page_length=max(int(limit or 0), 0),
    )

    result = {
        "scanned": 0,
        "current": 0,
        "link_backfill_ready": 0,
        "conflicts": 0,
        "missing_user": 0,
        "samples": {
            "link_backfill_ready": [],
            "conflicts": [],
            "missing_user": [],
        },
    }

    for row in rows:
        result["scanned"] += 1
        user = _text(row.user)
        if not user or not frappe.db.exists("User", user):
            result["missing_user"] += 1
            if len(result["samples"]["missing_user"]) < 25:
                result["samples"]["missing_user"].append(row.name)
            continue

        canonical = staff_authority.canonical_links(user)
        current_employee = _text(row.employee)
        current_profile = _text(row.legacy_staff_profile)
        expected_employee = _text(canonical.get("employee"))
        expected_profile = _text(canonical.get("legacy_staff_profile"))

        conflict = bool(
            (current_employee and expected_employee and current_employee != expected_employee)
            or (current_profile and expected_profile and current_profile != expected_profile)
        )
        if conflict:
            result["conflicts"] += 1
            if len(result["samples"]["conflicts"]) < 25:
                result["samples"]["conflicts"].append(
                    {
                        "staff_access": row.name,
                        "user": user,
                        "employee": current_employee,
                        "expected_employee": expected_employee,
                        "profile": current_profile,
                        "expected_profile": expected_profile,
                    }
                )
            continue

        needs_backfill = bool(
            (not current_employee and expected_employee)
            or (not current_profile and expected_profile)
        )
        if needs_backfill:
            result["link_backfill_ready"] += 1
            if len(result["samples"]["link_backfill_ready"]) < 25:
                result["samples"]["link_backfill_ready"].append(
                    {"staff_access": row.name, "user": user}
                )
        else:
            result["current"] += 1

    return result


def preflight(limit: int = 0) -> dict[str, Any]:
    """Read-only compatibility report; safe to run repeatedly."""

    if not frappe.db.exists("DocType", service_task_links.LINK_DOCTYPE):
        return {
            "read_only": True,
            "ready": False,
            "reason": "Run bench migrate first so OMC Service Task Link exists.",
            "service_tasks": {},
            "staff_access": {},
        }

    service_tasks = _service_task_plan(limit=limit)
    staff_access = _staff_access_plan(limit=limit)
    return {
        "read_only": True,
        "ready": not (
            service_tasks["conflicts"]
            or service_tasks["missing_task"]
            or staff_access["conflicts"]
            or staff_access["missing_user"]
        ),
        "service_tasks": service_tasks,
        "staff_access": staff_access,
    }


def apply(
    confirm=None,
    limit: int = 0,
    commit: bool = True,
) -> dict[str, Any]:
    """Apply only deterministic additive backfills after explicit confirmation."""

    if _text(confirm) != CONFIRM_TOKEN:
        frappe.throw(
            f"Explicit confirmation is required: {CONFIRM_TOKEN}",
            frappe.ValidationError,
        )
    if not frappe.db.exists("DocType", service_task_links.LINK_DOCTYPE):
        frappe.throw(
            "Run bench migrate before applying the architecture backfill.",
            frappe.ValidationError,
        )

    summary = {
        "service_task_links_created": 0,
        "service_task_links_skipped": 0,
        "staff_access_updated": 0,
        "staff_access_skipped": 0,
        "conflicts": [],
    }

    requests = frappe.get_all(
        "OMC Service Request",
        filters={"erp_task": ["is", "set"]},
        fields=["name", "erp_task", "erp_service"],
        order_by="creation asc, name asc",
        limit_page_length=max(int(limit or 0), 0),
    )
    for row in requests:
        task_name = _text(row.erp_task)
        if not task_name or not frappe.db.exists("Task", task_name):
            summary["conflicts"].append(
                {
                    "domain": "service_task",
                    "service_request": row.name,
                    "task": task_name,
                    "reason": "missing_task",
                }
            )
            continue
        existing_request = _text(
            frappe.db.get_value(
                service_task_links.LINK_DOCTYPE,
                {"erp_task": task_name},
                "service_request",
            )
        )
        if existing_request and existing_request != row.name:
            summary["conflicts"].append(
                {
                    "domain": "service_task",
                    "service_request": row.name,
                    "task": task_name,
                    "reason": "task_linked_to_other_request",
                    "linked_request": existing_request,
                }
            )
            continue
        if existing_request == row.name:
            summary["service_task_links_skipped"] += 1
            continue

        service_task_links.ensure_link(
            request_name=row.name,
            task_name=task_name,
            erp_service=_text(row.erp_service),
            is_primary=True,
            required_for_completion=True,
            source="Legacy Backfill",
        )
        summary["service_task_links_created"] += 1

    staff_rows = frappe.get_all(
        "OMC Staff Access",
        fields=["name", "user", "employee", "legacy_staff_profile"],
        order_by="user asc",
        limit_page_length=max(int(limit or 0), 0),
    )
    for row in staff_rows:
        user = _text(row.user)
        if not user or not frappe.db.exists("User", user):
            summary["conflicts"].append(
                {
                    "domain": "staff_access",
                    "staff_access": row.name,
                    "reason": "missing_user",
                }
            )
            continue

        canonical = staff_authority.canonical_links(user)
        expected_employee = _text(canonical.get("employee"))
        expected_profile = _text(canonical.get("legacy_staff_profile"))
        current_employee = _text(row.employee)
        current_profile = _text(row.legacy_staff_profile)
        if (
            (current_employee and expected_employee and current_employee != expected_employee)
            or (current_profile and expected_profile and current_profile != expected_profile)
        ):
            summary["conflicts"].append(
                {
                    "domain": "staff_access",
                    "staff_access": row.name,
                    "user": user,
                    "reason": "canonical_link_conflict",
                }
            )
            continue

        values = {}
        if not current_employee and expected_employee:
            values["employee"] = expected_employee
        if not current_profile and expected_profile:
            values["legacy_staff_profile"] = expected_profile
        if not values:
            summary["staff_access_skipped"] += 1
            continue

        values["source_version"] = staff_authority._text(
            frappe.db.get_value("OMC Staff Access", row.name, "source_version")
        )
        frappe.db.set_value(
            "OMC Staff Access",
            row.name,
            {key: value for key, value in values.items() if key != "source_version"},
            update_modified=False,
        )
        summary["staff_access_updated"] += 1

    if commit:
        frappe.db.commit()

    summary["conflict_count"] = len(summary["conflicts"])
    summary["applied"] = True
    return summary
