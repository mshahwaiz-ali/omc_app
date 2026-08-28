from __future__ import annotations

from typing import Any

import frappe

from omc_app.setup.app_defaults.stages import (
    SERVICE_STAGE_PROFILE,
    stages_for_service,
    validate_stage_manifest,
)


STAGE_DOCTYPE = "OMC Service Stage Template"

NUMERIC_FIELDS = {
    "sort_order",
    "app_defaults_managed",
    "is_customer_visible",
    "is_active",
}


def _text(value: Any) -> str:
    return str(value or "").strip()


def _number(value: Any) -> float:
    try:
        return float(value or 0)
    except (TypeError, ValueError):
        return 0.0


def _same_value(
    fieldname: str,
    current: Any,
    desired: Any,
) -> bool:
    if fieldname in NUMERIC_FIELDS:
        return _number(current) == _number(desired)

    return _text(current) == _text(desired)


def _changes(
    current: dict[str, Any],
    desired: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    changes: dict[str, dict[str, Any]] = {}

    for fieldname, desired_value in desired.items():
        current_value = current.get(fieldname)

        if _same_value(
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


def _desired_values(stage) -> dict[str, Any]:
    return {
        "stage_title": stage.title,
        "stage_key": stage.stage_key,
        "description": stage.description,
        "sort_order": stage.sort_order,
        "app_defaults_managed": 1,
        "is_customer_visible": int(
            stage.is_customer_visible
        ),
        "is_active": 1,
    }


def _service_rows() -> dict[str, list[dict[str, Any]]]:
    rows = frappe.get_all(
        "OMC Service",
        fields=[
            "name",
            "service_id",
            "title",
            "is_active",
        ],
        limit_page_length=1000,
    )

    result: dict[str, list[dict[str, Any]]] = {}

    for row in rows:
        service_id = _text(row.service_id)

        if not service_id:
            continue

        result.setdefault(
            service_id,
            [],
        ).append(dict(row))

    return result


def _stage_rows() -> dict[str, list[dict[str, Any]]]:
    rows = frappe.get_all(
        STAGE_DOCTYPE,
        fields=[
            "name",
            "service",
            "stage_title",
            "stage_key",
            "description",
            "sort_order",
            "app_defaults_managed",
            "is_customer_visible",
            "is_active",
        ],
        limit_page_length=10000,
    )

    result: dict[str, list[dict[str, Any]]] = {}

    for row in rows:
        service_name = _text(row.service)

        if not service_name:
            continue

        result.setdefault(
            service_name,
            [],
        ).append(dict(row))

    return result


def _empty_preview(
    *,
    manifest: dict[str, Any],
    blockers: list[dict[str, Any]],
) -> dict[str, Any]:
    result = {
        "manifest": manifest,
        "create": [],
        "update": [],
        "deactivate": [],
        "unchanged": [],
        "ignored_unmanaged": [],
        "ignored_inactive_managed": [],
        "conflicts": [],
        "blockers": blockers,
    }

    result["summary"] = {
        "create": 0,
        "update": 0,
        "deactivate": 0,
        "unchanged": 0,
        "ignored_unmanaged": 0,
        "ignored_inactive_managed": 0,
        "conflicts": 0,
        "blockers": len(blockers),
    }
    result["safe_to_sync"] = False
    result["converged"] = False

    return result


def preview_stage_defaults() -> dict[str, Any]:
    manifest = validate_stage_manifest()

    if not frappe.db.exists(
        "DocType",
        STAGE_DOCTYPE,
    ):
        return _empty_preview(
            manifest=manifest,
            blockers=[
                {
                    "type": "missing_doctype",
                    "doctype": STAGE_DOCTYPE,
                }
            ],
        )

    if not frappe.db.has_column(
        STAGE_DOCTYPE,
        "app_defaults_managed",
    ):
        return _empty_preview(
            manifest=manifest,
            blockers=[
                {
                    "type": "schema_not_migrated",
                    "doctype": STAGE_DOCTYPE,
                    "field": "app_defaults_managed",
                }
            ],
        )

    service_rows = _service_rows()
    stage_rows = _stage_rows()

    create: list[dict[str, Any]] = []
    update: list[dict[str, Any]] = []
    deactivate: list[dict[str, Any]] = []
    unchanged: list[dict[str, Any]] = []
    ignored_unmanaged: list[dict[str, Any]] = []
    ignored_inactive_managed: list[
        dict[str, Any]
    ] = []
    conflicts: list[dict[str, Any]] = []
    blockers: list[dict[str, Any]] = []

    for service_id in sorted(
        SERVICE_STAGE_PROFILE
    ):
        matching_services = service_rows.get(
            service_id,
            [],
        )

        if not matching_services:
            blockers.append(
                {
                    "type": "missing_managed_service",
                    "service_id": service_id,
                }
            )
            continue

        if len(matching_services) > 1:
            blockers.append(
                {
                    "type": "duplicate_service_id",
                    "service_id": service_id,
                    "names": [
                        row.get("name")
                        for row in matching_services
                    ],
                }
            )
            continue

        service = matching_services[0]
        service_name = _text(
            service.get("name")
        )

        rows = stage_rows.get(
            service_name,
            [],
        )

        used_names: set[str] = set()
        desired_stages = stages_for_service(
            service_id
        )

        for stage in desired_stages:
            identity = (
                f"{service_id}:{stage.stage_key}"
            )
            desired = _desired_values(stage)

            matches = [
                row
                for row in rows
                if (
                    _text(row.get("stage_key"))
                    == stage.stage_key
                )
            ]

            if len(matches) > 1:
                conflicts.append(
                    {
                        "type": (
                            "duplicate_stage_key"
                        ),
                        "id": identity,
                        "service_id": service_id,
                        "stage_key": stage.stage_key,
                        "rows": [
                            row.get("name")
                            for row in matches
                        ],
                    }
                )
                continue

            if not matches:
                create.append(
                    {
                        "id": identity,
                        "service_id": service_id,
                        "service": service_name,
                        "stage_key": stage.stage_key,
                        "desired": desired,
                    }
                )
                continue

            current = matches[0]
            row_name = _text(
                current.get("name")
            )
            used_names.add(row_name)

            is_managed = bool(
                int(
                    _number(
                        current.get(
                            "app_defaults_managed"
                        )
                    )
                )
            )

            if not is_managed:
                conflicts.append(
                    {
                        "type": (
                            "unmanaged_stage_key_collision"
                        ),
                        "id": identity,
                        "service_id": service_id,
                        "stage_key": stage.stage_key,
                        "row": row_name,
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
                        "id": identity,
                        "name": row_name,
                        "service_id": service_id,
                        "service": service_name,
                        "stage_key": stage.stage_key,
                        "changes": changes,
                        "desired": desired,
                    }
                )
            else:
                unchanged.append(
                    {
                        "id": identity,
                        "name": row_name,
                    }
                )

        desired_keys = {
            stage.stage_key
            for stage in desired_stages
        }

        for row in rows:
            row_name = _text(
                row.get("name")
            )

            if row_name in used_names:
                continue

            stage_key = _text(
                row.get("stage_key")
            )
            identity = (
                f"{service_id}:{stage_key}"
            )

            is_managed = bool(
                int(
                    _number(
                        row.get(
                            "app_defaults_managed"
                        )
                    )
                )
            )
            is_active = bool(
                int(
                    _number(
                        row.get("is_active")
                    )
                )
            )

            if not is_managed:
                ignored_unmanaged.append(
                    {
                        "id": identity,
                        "name": row_name,
                        "service_id": service_id,
                        "stage_key": stage_key,
                    }
                )
                continue

            if stage_key in desired_keys:
                # A desired key would already have
                # been consumed above unless the DB
                # contains duplicate rows.
                continue

            if is_active:
                deactivate.append(
                    {
                        "id": identity,
                        "name": row_name,
                        "service_id": service_id,
                        "stage_key": stage_key,
                    }
                )
            else:
                ignored_inactive_managed.append(
                    {
                        "id": identity,
                        "name": row_name,
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

    safe_to_sync = not blockers and not conflicts
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


def validate_stage_defaults() -> dict[str, Any]:
    preview = preview_stage_defaults()

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


def sync_stage_defaults(
    *,
    commit: bool = True,
) -> dict[str, Any]:
    preview = preview_stage_defaults()

    if not preview.get("safe_to_sync"):
        frappe.throw(
            "Stage defaults synchronization is "
            "blocked by conflicts or prerequisites: "
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
        doc = frappe.get_doc(
            {
                "doctype": STAGE_DOCTYPE,
                "service": item["service"],
                **item["desired"],
            }
        )
        doc.insert(
            ignore_permissions=True
        )
        created += 1

    for item in preview["update"]:
        doc = frappe.get_doc(
            STAGE_DOCTYPE,
            item["name"],
        )

        for fieldname, value in (
            item["desired"].items()
        ):
            setattr(
                doc,
                fieldname,
                value,
            )

        doc.save(
            ignore_permissions=True
        )
        updated += 1

    for item in preview["deactivate"]:
        doc = frappe.get_doc(
            STAGE_DOCTYPE,
            item["name"],
        )
        doc.is_active = 0
        doc.save(
            ignore_permissions=True
        )
        deactivated += 1

    validation = validate_stage_defaults()

    if not validation["valid"]:
        frappe.throw(
            "Stage defaults failed post-sync "
            "validation: "
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
