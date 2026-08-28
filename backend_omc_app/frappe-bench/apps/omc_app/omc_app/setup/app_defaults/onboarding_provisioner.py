from __future__ import annotations

from typing import Any

import frappe

from omc_app.setup.app_defaults.onboarding import (
    ONBOARDING_SLIDES,
    validate_onboarding_manifest,
)


DOCTYPE = "OMC Onboarding Slide"

MANAGED_FIELDS = (
    "slide_id",
    "enabled",
    "app_defaults_managed",
    "audience",
    "title",
    "subtitle",
    "description",
    "image",
    "icon_key",
    "accent_color",
    "benefits",
    "primary_cta_label",
    "primary_cta_route",
    "secondary_cta_label",
    "secondary_cta_route",
    "sort_order",
)

NUMERIC_FIELDS = {
    "enabled",
    "app_defaults_managed",
    "sort_order",
}


def _text(value: Any) -> str:
    return str(value or "").strip()


def _number(value: Any) -> float:
    try:
        return float(value or 0)
    except (TypeError, ValueError):
        return 0.0


def _same(
    fieldname: str,
    current: Any,
    desired: Any,
) -> bool:
    if fieldname in NUMERIC_FIELDS:
        return _number(current) == _number(desired)

    return _text(current) == _text(desired)


def _desired(slide) -> dict[str, Any]:
    return {
        "slide_id": slide.slide_id,
        "enabled": int(slide.enabled),
        "app_defaults_managed": 1,
        "audience": slide.audience,
        "title": slide.title,
        "subtitle": slide.subtitle,
        "description": slide.description,
        "image": slide.image,
        "icon_key": slide.icon_key,
        "accent_color": slide.accent_color,
        "benefits": slide.benefits_text,
        "primary_cta_label": slide.primary_cta_label,
        "primary_cta_route": slide.primary_cta_route,
        "secondary_cta_label": slide.secondary_cta_label,
        "secondary_cta_route": slide.secondary_cta_route,
        "sort_order": int(slide.sort_order),
    }


def _changes(
    current: dict[str, Any],
    desired: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    changes = {}

    for fieldname in MANAGED_FIELDS:
        current_value = current.get(fieldname)
        desired_value = desired.get(fieldname)

        if _same(
            fieldname,
            current_value,
            desired_value,
        ):
            continue

        changes[fieldname] = {
            "current": current_value,
            "desired": desired_value,
        }

    return changes


def preview_onboarding_slides() -> dict[str, Any]:
    blockers = []
    conflicts = []

    try:
        manifest = validate_onboarding_manifest()
    except Exception as exc:
        manifest = {
            "slides": len(ONBOARDING_SLIDES),
            "valid": False,
        }
        blockers.append(
            {
                "type": "invalid_manifest",
                "message": str(exc),
            }
        )

    if not frappe.db.exists("DocType", DOCTYPE):
        blockers.append(
            {
                "type": "missing_doctype",
                "doctype": DOCTYPE,
            }
        )

        return {
            "manifest": manifest,
            "create": [],
            "update": [],
            "deactivate": [],
            "unchanged": [],
            "ignored_unmanaged": [],
            "ignored_inactive_managed": [],
            "conflicts": conflicts,
            "blockers": blockers,
            "summary": {
                "create": 0,
                "update": 0,
                "deactivate": 0,
                "unchanged": 0,
                "ignored_unmanaged": 0,
                "ignored_inactive_managed": 0,
                "conflicts": len(conflicts),
                "blockers": len(blockers),
            },
            "safe_to_sync": False,
            "converged": False,
        }

    meta = frappe.get_meta(DOCTYPE)

    if not meta.has_field("app_defaults_managed"):
        blockers.append(
            {
                "type": "missing_management_field",
                "fieldname": "app_defaults_managed",
            }
        )

    rows = frappe.get_all(
        DOCTYPE,
        fields=["name", *MANAGED_FIELDS],
        limit_page_length=1000,
    )

    by_slide_id = {
        _text(row.slide_id): dict(row)
        for row in rows
        if _text(row.slide_id)
    }

    desired_by_id = {
        slide.slide_id: _desired(slide)
        for slide in ONBOARDING_SLIDES
    }

    create = []
    update = []
    deactivate = []
    unchanged = []
    ignored_unmanaged = []
    ignored_inactive_managed = []

    for slide_id, desired in desired_by_id.items():
        current = by_slide_id.get(slide_id)

        if not current:
            create.append(
                {
                    "slide_id": slide_id,
                    "desired": desired,
                }
            )
            continue

        if not int(
            _number(
                current.get("app_defaults_managed")
            )
        ):
            conflicts.append(
                {
                    "type": (
                        "managed_slide_id_owned_by_unmanaged_row"
                    ),
                    "slide_id": slide_id,
                    "name": current.get("name"),
                }
            )
            continue

        changes = _changes(
            current,
            desired,
        )

        if changes:
            update.append(
                {
                    "slide_id": slide_id,
                    "name": current["name"],
                    "changes": changes,
                    "desired": desired,
                }
            )
        else:
            unchanged.append(
                {
                    "slide_id": slide_id,
                    "name": current["name"],
                }
            )

    desired_ids = set(desired_by_id)

    for row in rows:
        slide_id = _text(row.slide_id)

        if slide_id in desired_ids:
            continue

        is_managed = bool(
            int(
                _number(
                    row.app_defaults_managed
                )
            )
        )

        if not is_managed:
            ignored_unmanaged.append(
                {
                    "slide_id": slide_id,
                    "name": row.name,
                    "enabled": int(
                        row.enabled or 0
                    ),
                }
            )
            continue

        if int(row.enabled or 0):
            deactivate.append(
                {
                    "slide_id": slide_id,
                    "name": row.name,
                }
            )
        else:
            ignored_inactive_managed.append(
                {
                    "slide_id": slide_id,
                    "name": row.name,
                }
            )

    summary = {
        "create": len(create),
        "update": len(update),
        "deactivate": len(deactivate),
        "unchanged": len(unchanged),
        "ignored_unmanaged": len(
            ignored_unmanaged
        ),
        "ignored_inactive_managed": len(
            ignored_inactive_managed
        ),
        "conflicts": len(conflicts),
        "blockers": len(blockers),
    }

    safe_to_sync = (
        not conflicts
        and not blockers
    )

    converged = (
        safe_to_sync
        and not create
        and not update
        and not deactivate
    )

    return {
        "manifest": manifest,
        "create": create,
        "update": update,
        "deactivate": deactivate,
        "unchanged": unchanged,
        "ignored_unmanaged": ignored_unmanaged,
        "ignored_inactive_managed": (
            ignored_inactive_managed
        ),
        "conflicts": conflicts,
        "blockers": blockers,
        "summary": summary,
        "safe_to_sync": safe_to_sync,
        "converged": converged,
    }


def validate_onboarding_slides() -> dict[str, Any]:
    preview = preview_onboarding_slides()

    return {
        "valid": bool(
            preview.get("converged")
        ),
        "safe_to_sync": bool(
            preview.get("safe_to_sync")
        ),
        "manifest": preview.get(
            "manifest",
            {},
        ),
        "summary": preview.get(
            "summary",
            {},
        ),
        "conflicts": preview.get(
            "conflicts",
            [],
        ),
        "blockers": preview.get(
            "blockers",
            [],
        ),
    }


def sync_onboarding_slides(
    *,
    commit: bool = True,
) -> dict[str, Any]:
    preview = preview_onboarding_slides()

    if not preview.get("safe_to_sync"):
        frappe.throw(
            "Onboarding Slide synchronization "
            "is blocked: "
            + frappe.as_json(
                {
                    "conflicts": preview.get(
                        "conflicts",
                        [],
                    ),
                    "blockers": preview.get(
                        "blockers",
                        [],
                    ),
                }
            ),
            frappe.ValidationError,
        )

    created = 0
    updated = 0
    deactivated = 0

    for item in preview["create"]:
        frappe.get_doc(
            {
                "doctype": DOCTYPE,
                **item["desired"],
            }
        ).insert(
            ignore_permissions=True
        )
        created += 1

    for item in preview["update"]:
        doc = frappe.get_doc(
            DOCTYPE,
            item["name"],
        )

        for fieldname, value in (
            item["desired"].items()
        ):
            doc.set(
                fieldname,
                value,
            )

        doc.save(
            ignore_permissions=True
        )
        updated += 1

    for item in preview["deactivate"]:
        doc = frappe.get_doc(
            DOCTYPE,
            item["name"],
        )

        doc.enabled = 0
        doc.save(
            ignore_permissions=True
        )
        deactivated += 1

    validation = validate_onboarding_slides()

    if not validation["valid"]:
        frappe.throw(
            "Onboarding Slides failed "
            "post-sync validation: "
            + frappe.as_json(validation),
            frappe.ValidationError,
        )

    if commit:
        frappe.db.commit()

    return {
        "created": created,
        "updated": updated,
        "deactivated": deactivated,
        "validation": validation,
    }
