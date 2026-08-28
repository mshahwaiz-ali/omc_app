from __future__ import annotations

from typing import Any

import frappe


SETTINGS_DOCTYPE = "OMC Mobile Settings"

MANAGED_VALUES = {
    "integration_mode": "ERPNext Hybrid",
    "erpnext_integration_enabled": 1,
}


def _text(value: Any) -> str:
    return str(value or "").strip()


def _number(value: Any) -> float:
    try:
        return float(value or 0)
    except (TypeError, ValueError):
        return 0.0


def _same(fieldname: str, current: Any, desired: Any) -> bool:
    if fieldname == "erpnext_integration_enabled":
        return _number(current) == _number(desired)

    return _text(current) == _text(desired)


def _mapping_report(settings) -> dict[str, Any]:
    return settings.validate_erpnext_mapping(
        update_doc=False,
    )


def preview_mobile_settings() -> dict[str, Any]:
    if not frappe.db.exists(
        "DocType",
        SETTINGS_DOCTYPE,
    ):
        return {
            "changes": {},
            "mapping": {},
            "blockers": [
                {
                    "type": "missing_doctype",
                    "doctype": SETTINGS_DOCTYPE,
                }
            ],
            "safe_to_sync": False,
            "converged": False,
        }

    settings = frappe.get_single(
        SETTINGS_DOCTYPE
    )

    changes = {}

    for fieldname, desired in MANAGED_VALUES.items():
        current = settings.get(fieldname)

        if _same(
            fieldname,
            current,
            desired,
        ):
            continue

        changes[fieldname] = {
            "current": current,
            "desired": desired,
        }

    mapping = _mapping_report(settings)
    blockers = []

    if mapping.get("errors"):
        blockers.append(
            {
                "type": "invalid_erpnext_mapping",
                "errors": mapping.get("errors"),
            }
        )

    safe_to_sync = not blockers

    return {
        "changes": changes,
        "mapping": mapping,
        "blockers": blockers,
        "safe_to_sync": safe_to_sync,
        "converged": (
            safe_to_sync
            and not changes
        ),
    }


def validate_mobile_settings() -> dict[str, Any]:
    preview = preview_mobile_settings()

    return {
        "valid": bool(
            preview.get("converged")
        ),
        "safe_to_sync": bool(
            preview.get("safe_to_sync")
        ),
        "changes": preview.get(
            "changes",
            {},
        ),
        "mapping": preview.get(
            "mapping",
            {},
        ),
        "blockers": preview.get(
            "blockers",
            [],
        ),
    }


def sync_mobile_settings(
    *,
    commit: bool = True,
) -> dict[str, Any]:
    preview = preview_mobile_settings()

    if not preview.get("safe_to_sync"):
        frappe.throw(
            "Mobile Settings synchronization "
            "is blocked: "
            + frappe.as_json(
                preview.get("blockers", [])
            ),
            frappe.ValidationError,
        )

    settings = frappe.get_single(
        SETTINGS_DOCTYPE
    )

    changed_fields = []

    for fieldname, desired in MANAGED_VALUES.items():
        if _same(
            fieldname,
            settings.get(fieldname),
            desired,
        ):
            continue

        settings.set(
            fieldname,
            desired,
        )
        changed_fields.append(fieldname)

    if changed_fields:
        settings.save(
            ignore_permissions=True
        )

    report = settings.validate_mobile_backend()

    if report.get("errors"):
        frappe.throw(
            "Mobile backend validation failed: "
            + frappe.as_json(report),
            frappe.ValidationError,
        )

    validation = validate_mobile_settings()

    if not validation["valid"]:
        frappe.throw(
            "Mobile Settings failed post-sync "
            "validation: "
            + frappe.as_json(validation),
            frappe.ValidationError,
        )

    if commit:
        frappe.db.commit()

    return {
        "changed_fields": changed_fields,
        "validation": validation,
        "backend_validation": report,
    }
