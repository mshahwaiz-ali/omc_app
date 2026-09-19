from __future__ import annotations

from typing import Any

import frappe

from omc_app.api.mobile_release_controls import (
    validate_release_controls,
)


SETTINGS_DOCTYPE = "OMC Mobile Settings"


def _release_controls(
    settings,
) -> dict[str, Any]:
    try:
        controls = validate_release_controls(
            settings.get("minimum_app_version"),
            settings.get("force_update"),
            settings.get("maintenance_mode"),
        )
    except ValueError as error:
        return {
            "valid": False,
            "controls": {},
            "errors": [str(error)],
        }

    return {
        "valid": True,
        "controls": controls,
        "errors": [],
    }


def preview_mobile_settings() -> dict[str, Any]:
    """Validate the current Mobile Settings contract without owning it.

    ERP mapping mode/field controls were removed from OMC Mobile Settings.
    Remaining feature, pricing, legal and release-control values are
    site/client-managed and must not be overwritten by app defaults.
    """

    if not frappe.db.exists(
        "DocType",
        SETTINGS_DOCTYPE,
    ):
        return {
            "changes": {},
            "release_controls": {},
            "ownership": "client_managed",
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

    release = _release_controls(settings)
    blockers = []

    if not release["valid"]:
        blockers.append(
            {
                "type": "invalid_release_controls",
                "errors": release["errors"],
            }
        )

    safe_to_sync = not blockers

    return {
        "changes": {},
        "release_controls": release["controls"],
        "ownership": "client_managed",
        "blockers": blockers,
        "safe_to_sync": safe_to_sync,
        "converged": safe_to_sync,
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
        "changes": {},
        "release_controls": preview.get(
            "release_controls",
            {},
        ),
        "ownership": "client_managed",
        "blockers": preview.get(
            "blockers",
            [],
        ),
    }


def sync_mobile_settings(
    *,
    commit: bool = True,
) -> dict[str, Any]:
    """Validate Mobile Settings without mutating client-managed values."""

    preview = preview_mobile_settings()

    if not preview.get("safe_to_sync"):
        frappe.throw(
            "Mobile Settings validation is blocked: "
            + frappe.as_json(
                preview.get("blockers", [])
            ),
            frappe.ValidationError,
        )

    validation = validate_mobile_settings()

    if not validation["valid"]:
        frappe.throw(
            "Mobile Settings failed validation: "
            + frappe.as_json(validation),
            frappe.ValidationError,
        )

    return {
        "changed_fields": [],
        "committed": False,
        "ownership": "client_managed",
        "release_controls": validation.get(
            "release_controls",
            {},
        ),
        "validation": validation,
    }
