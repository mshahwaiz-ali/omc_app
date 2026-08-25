from __future__ import annotations

from typing import Any

import frappe

from omc_app.setup.service_catalogue.manifest import (
    DEFAULT_ASSIGNMENT_ROLE,
    SERVICES,
    service_by_id,
)


PRESENTATION_FIELDS = (
    "short_description",
    "description",
    "support_message",
    "default_assignment_role",
)


def _text(value: Any) -> str:
    return str(value or "").strip()


def validate_presentation_source() -> dict[str, Any]:
    """Validate presentation data already carried by the catalogue manifest."""
    errors: list[str] = []

    for spec in SERVICES:
        for fieldname in ("short_description", "description", "support_message"):
            if not _text(getattr(spec, fieldname, "")):
                errors.append(f"{spec.service_id}.{fieldname} is empty")

        if len(_text(spec.short_description)) > 240:
            errors.append(f"{spec.service_id}.short_description is too long")
        if len(_text(spec.support_message)) > 240:
            errors.append(f"{spec.service_id}.support_message is too long")
        if _text(spec.default_assignment_role) != DEFAULT_ASSIGNMENT_ROLE:
            errors.append(
                f"{spec.service_id}.default_assignment_role must be "
                f"{DEFAULT_ASSIGNMENT_ROLE}"
            )

    return {
        "ok": not errors,
        "expected_services": len(SERVICES),
        "configured_services": len(SERVICES),
        "assignment_role": DEFAULT_ASSIGNMENT_ROLE,
        "errors": errors,
    }


def desired_presentation(service_id: str) -> dict[str, str]:
    source = validate_presentation_source()
    if not source["ok"]:
        frappe.throw("; ".join(source["errors"]), frappe.ValidationError)

    spec = service_by_id().get(_text(service_id))
    if not spec:
        frappe.throw(
            f"Unknown managed service: {service_id}",
            frappe.ValidationError,
        )

    return {
        "short_description": spec.short_description,
        "description": spec.description,
        "support_message": spec.support_message,
        "default_assignment_role": spec.default_assignment_role,
    }


def _service_rows() -> dict[str, dict[str, Any]]:
    rows = frappe.get_all(
        "OMC Service",
        fields=["name", "service_id", *PRESENTATION_FIELDS],
        limit_page_length=1000,
    )
    return {
        _text(row.service_id): dict(row)
        for row in rows
        if _text(row.service_id)
    }


def preview_service_presentation() -> dict[str, Any]:
    """Read-only preview of managed customer copy and assignment defaults."""
    source = validate_presentation_source()
    if not source["ok"]:
        return {
            "ok": False,
            "read_only": True,
            "operation": "preview_service_presentation",
            "ready_to_sync": False,
            "updated": 0,
            "unchanged": 0,
            "missing_services": [],
            "update_services": [],
            "assignment_role": DEFAULT_ASSIGNMENT_ROLE,
            "errors": source["errors"],
        }

    existing = _service_rows()
    updated: list[str] = []
    unchanged: list[str] = []
    missing: list[str] = []

    for spec in SERVICES:
        current = existing.get(spec.service_id)
        if not current:
            missing.append(spec.service_id)
            continue

        desired = desired_presentation(spec.service_id)
        if any(
            _text(current.get(fieldname)) != _text(value)
            for fieldname, value in desired.items()
        ):
            updated.append(spec.service_id)
        else:
            unchanged.append(spec.service_id)

    return {
        "ok": True,
        "read_only": True,
        "operation": "preview_service_presentation",
        "ready_to_sync": not missing,
        "updated": len(updated),
        "unchanged": len(unchanged),
        "missing_services": missing,
        "update_services": updated,
        "assignment_role": DEFAULT_ASSIGNMENT_ROLE,
        "errors": [],
    }


def validate_service_presentation() -> dict[str, Any]:
    preview = preview_service_presentation()
    valid = bool(
        preview.get("ok")
        and not preview.get("missing_services")
        and int(preview.get("updated") or 0) == 0
    )
    return {
        **preview,
        "operation": "validate_service_presentation",
        "valid": valid,
    }


def sync_service_presentation(*, commit: bool = True) -> dict[str, Any]:
    """Reconcile manifest-owned copy/defaults for existing managed services.

    Normal deployment calls this inside operations.sync_service_catalogue so
    catalogue rows and their presentation defaults share one outer transaction.
    The standalone entrypoint remains for compatibility and repair only.
    """
    source = validate_presentation_source()
    if not source["ok"]:
        frappe.throw("; ".join(source["errors"]), frappe.ValidationError)

    savepoint = "omc_service_presentation_sync"
    frappe.db.savepoint(savepoint)
    changed = 0
    unchanged = 0

    try:
        existing = _service_rows()
        for spec in SERVICES:
            current = existing.get(spec.service_id)
            if not current:
                frappe.throw(
                    f"Managed OMC Service is missing after catalogue sync: {spec.service_id}",
                    frappe.ValidationError,
                )

            desired = desired_presentation(spec.service_id)
            changes = {
                fieldname: value
                for fieldname, value in desired.items()
                if _text(current.get(fieldname)) != _text(value)
            }
            if not changes:
                unchanged += 1
                continue

            frappe.db.set_value(
                "OMC Service",
                current["name"],
                changes,
                update_modified=False,
            )
            changed += 1

        validation = validate_service_presentation()
        if not validation["valid"]:
            frappe.throw(
                "Service presentation validation failed after synchronization.",
                frappe.ValidationError,
            )

        if commit:
            frappe.db.commit()

        return {
            "ok": True,
            "operation": "sync_service_presentation",
            "committed": bool(commit),
            "updated": changed,
            "unchanged": unchanged,
            "assignment_role": DEFAULT_ASSIGNMENT_ROLE,
            "validation": validation,
        }
    except Exception:
        frappe.db.rollback(save_point=savepoint)
        raise
