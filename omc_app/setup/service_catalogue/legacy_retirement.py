from __future__ import annotations

from typing import Any

import frappe

from omc_app.setup.service_catalogue.provisioner import (
    _request_is_historical_projection,
)


LEGACY_SERVICE_DUPLICATES = (
    {
        "legacy_id":
            "advocacy-service---hearing-with-commissioner",
        "canonical_id":
            "advocacy-service-hearing-with-commissioner",
        "task_type":
            "Advocacy Service - Hearing with Commissioner",
    },
    {
        "legacy_id":
            "ntn--modification",
        "canonical_id":
            "ntn-modification",
        "task_type":
            "NTN  MODIFICATION",
    },
)


def _text(value) -> str:
    return str(value or "").strip()


def _service(service_id: str) -> dict[str, Any] | None:
    rows = frappe.get_all(
        "OMC Service",
        filters={
            "service_id": service_id,
        },
        fields=[
            "name",
            "service_id",
            "title",
            "is_active",
            "erp_task_type",
        ],
        limit_page_length=2,
    )

    if len(rows) != 1:
        return None

    return dict(rows[0])


def _link_fields() -> set[tuple[str, str]]:
    fields: set[tuple[str, str]] = set()

    for row in frappe.get_all(
        "DocField",
        filters={
            "fieldtype": "Link",
            "options": "OMC Service",
        },
        fields=[
            "parent",
            "fieldname",
        ],
        limit_page_length=1000,
    ):
        doctype = _text(row.parent)
        fieldname = _text(row.fieldname)

        if doctype and fieldname:
            fields.add(
                (
                    doctype,
                    fieldname,
                )
            )

    for row in frappe.get_all(
        "Custom Field",
        filters={
            "fieldtype": "Link",
            "options": "OMC Service",
        },
        fields=[
            "dt",
            "fieldname",
        ],
        limit_page_length=1000,
    ):
        doctype = _text(row.dt)
        fieldname = _text(row.fieldname)

        if doctype and fieldname:
            fields.add(
                (
                    doctype,
                    fieldname,
                )
            )

    return fields


def _historical_requests(
    service_name: str,
) -> list[dict[str, Any]]:
    meta = frappe.get_meta(
        "OMC Service Request"
    )

    fields = [
        "name",
        "service",
        "status",
    ]

    for fieldname in (
        "request_state",
        "source_channel",
        "submission_mode",
        "erp_sync_status",
        "erp_service",
        "erp_task",
    ):
        if meta.has_field(fieldname):
            fields.append(
                fieldname
            )

    return [
        dict(row)
        for row in frappe.get_all(
            "OMC Service Request",
            filters={
                "service": service_name,
            },
            fields=fields,
            order_by="creation asc, name asc",
            limit_page_length=10000,
        )
    ]


def preview_legacy_service_retirement() -> dict[str, Any]:
    """Read-only retirement plan for known pre-manifest duplicates."""
    link_fields = _link_fields()

    items = []
    blockers = []

    total_repoints = 0
    total_clear_mappings = 0

    for spec in LEGACY_SERVICE_DUPLICATES:
        legacy_id = spec["legacy_id"]
        canonical_id = spec["canonical_id"]
        expected_task_type = spec["task_type"]

        item = {
            "legacy_id": legacy_id,
            "canonical_id": canonical_id,
            "task_type": expected_task_type,
            "legacy": None,
            "canonical": None,
            "historical_requests": [],
            "other_references": [],
            "actions": {
                "repoint_requests": [],
                "clear_legacy_task_type": False,
            },
            "retired": False,
            "blockers": [],
        }

        legacy = _service(
            legacy_id
        )
        canonical = _service(
            canonical_id
        )

        item["legacy"] = legacy
        item["canonical"] = canonical

        if not legacy:
            reason = {
                "type":
                    "legacy_service_missing_or_ambiguous",
                "legacy_id":
                    legacy_id,
            }
            item["blockers"].append(reason)
            blockers.append(reason)
            items.append(item)
            continue

        if not canonical:
            reason = {
                "type":
                    "canonical_service_missing_or_ambiguous",
                "canonical_id":
                    canonical_id,
            }
            item["blockers"].append(reason)
            blockers.append(reason)
            items.append(item)
            continue

        if int(
            legacy.get("is_active")
            or 0
        ):
            reason = {
                "type":
                    "legacy_service_still_active",
                "legacy_id":
                    legacy_id,
            }
            item["blockers"].append(reason)
            blockers.append(reason)

        canonical_task_type = _text(
            canonical.get(
                "erp_task_type"
            )
        )

        if canonical_task_type != expected_task_type:
            reason = {
                "type":
                    "canonical_task_type_mismatch",
                "canonical_id":
                    canonical_id,
                "expected":
                    expected_task_type,
                "actual":
                    canonical_task_type,
            }
            item["blockers"].append(reason)
            blockers.append(reason)

        legacy_task_type = _text(
            legacy.get(
                "erp_task_type"
            )
        )

        if (
            legacy_task_type
            and legacy_task_type
            != expected_task_type
        ):
            reason = {
                "type":
                    "legacy_task_type_unexpected",
                "legacy_id":
                    legacy_id,
                "expected":
                    expected_task_type,
                "actual":
                    legacy_task_type,
            }
            item["blockers"].append(reason)
            blockers.append(reason)

        service_name = _text(
            legacy.get("name")
        )

        requests = _historical_requests(
            service_name
        )

        item["historical_requests"] = requests

        for request in requests:
            if not _request_is_historical_projection(
                request
            ):
                reason = {
                    "type":
                        "legacy_service_has_nonhistorical_request",
                    "legacy_id":
                        legacy_id,
                    "request":
                        request.get("name"),
                }
                item["blockers"].append(reason)
                blockers.append(reason)
                continue

            item[
                "actions"
            ][
                "repoint_requests"
            ].append(
                request.get("name")
            )

        for doctype, fieldname in sorted(
            link_fields
        ):
            if (
                doctype
                == "OMC Service Request"
                and fieldname
                == "service"
            ):
                continue

            if not frappe.db.exists(
                "DocType",
                doctype,
            ):
                continue

            try:
                meta = frappe.get_meta(
                    doctype
                )

                if getattr(
                    meta,
                    "issingle",
                    False,
                ):
                    count = int(
                        _text(
                            frappe.db.get_single_value(
                                doctype,
                                fieldname,
                            )
                        )
                        == service_name
                    )
                else:
                    count = frappe.db.count(
                        doctype,
                        {
                            fieldname:
                                service_name,
                        },
                    )
            except Exception as exc:
                reason = {
                    "type":
                        "reference_scan_failed",
                    "legacy_id":
                        legacy_id,
                    "doctype":
                        doctype,
                    "fieldname":
                        fieldname,
                    "error":
                        str(exc),
                }
                item["blockers"].append(reason)
                blockers.append(reason)
                continue

            if not count:
                continue

            reference = {
                "doctype":
                    doctype,
                "fieldname":
                    fieldname,
                "count":
                    int(count),
            }

            item[
                "other_references"
            ].append(reference)

            reason = {
                "type":
                    "legacy_service_has_other_references",
                "legacy_id":
                    legacy_id,
                **reference,
            }

            item["blockers"].append(reason)
            blockers.append(reason)

        if legacy_task_type:
            item[
                "actions"
            ][
                "clear_legacy_task_type"
            ] = True

        if not item["blockers"]:
            total_repoints += len(
                item[
                    "actions"
                ][
                    "repoint_requests"
                ]
            )

            total_clear_mappings += int(
                item[
                    "actions"
                ][
                    "clear_legacy_task_type"
                ]
            )

            item["retired"] = bool(
                not item[
                    "actions"
                ][
                    "repoint_requests"
                ]
                and not item[
                    "actions"
                ][
                    "clear_legacy_task_type"
                ]
            )

        items.append(item)

    return {
        "ok": True,
        "read_only": True,
        "ready_to_retire":
            not blockers,
        "items": items,
        "totals": {
            "legacy_services":
                len(items),
            "repoint_requests":
                total_repoints,
            "clear_task_type_mappings":
                total_clear_mappings,
            "blockers":
                len(blockers),
        },
        "blockers": blockers,
    }


def retire_legacy_service_duplicates() -> dict[str, Any]:
    """Atomically retire exact known duplicate service masters."""
    preview = (
        preview_legacy_service_retirement()
    )

    if not preview[
        "ready_to_retire"
    ]:
        frappe.throw(
            "Legacy service retirement is blocked.",
            frappe.ValidationError,
        )

    repoint_count = int(
        preview[
            "totals"
        ][
            "repoint_requests"
        ]
    )
    clear_count = int(
        preview[
            "totals"
        ][
            "clear_task_type_mappings"
        ]
    )

    if (
        repoint_count == 0
        and clear_count == 0
    ):
        return {
            "ok": True,
            "operation":
                "retire_legacy_service_duplicates",
            "committed": False,
            "idempotent_noop": True,
            "repointed_requests": 0,
            "cleared_task_type_mappings": 0,
            "deleted": 0,
            "validation": preview,
        }

    savepoint = (
        "omc_legacy_service_retirement"
    )

    frappe.db.savepoint(
        savepoint
    )

    try:
        repointed = 0
        cleared = 0

        for item in preview["items"]:
            legacy = item["legacy"]
            canonical = item["canonical"]

            legacy_name = _text(
                legacy.get("name")
            )
            canonical_name = _text(
                canonical.get("name")
            )

            for request_name in (
                item[
                    "actions"
                ][
                    "repoint_requests"
                ]
            ):
                frappe.db.set_value(
                    "OMC Service Request",
                    request_name,
                    "service",
                    canonical_name,
                    update_modified=False,
                )
                repointed += 1

            if (
                item[
                    "actions"
                ][
                    "clear_legacy_task_type"
                ]
            ):
                frappe.db.set_value(
                    "OMC Service",
                    legacy_name,
                    {
                        "erp_task_type": None,
                        "is_active": 0,
                    },
                    update_modified=False,
                )
                cleared += 1

        post = (
            preview_legacy_service_retirement()
        )

        if not post[
            "ready_to_retire"
        ]:
            frappe.throw(
                "Legacy service retirement post-validation failed.",
                frappe.ValidationError,
            )

        if (
            post[
                "totals"
            ][
                "repoint_requests"
            ]
            or post[
                "totals"
            ][
                "clear_task_type_mappings"
            ]
        ):
            frappe.throw(
                "Legacy service retirement did not converge.",
                frappe.ValidationError,
            )

        # Exact Task Type authority must now resolve only to canonical rows.
        for spec in LEGACY_SERVICE_DUPLICATES:
            rows = frappe.get_all(
                "OMC Service",
                filters={
                    "erp_task_type":
                        spec["task_type"],
                },
                fields=[
                    "service_id",
                ],
                limit_page_length=10,
            )

            ids = sorted(
                _text(
                    row.service_id
                )
                for row in rows
                if _text(
                    row.service_id
                )
            )

            if ids != [
                spec["canonical_id"]
            ]:
                frappe.throw(
                    (
                        "Task Type authority did not converge for "
                        f"{spec['task_type']}: {ids}"
                    ),
                    frappe.ValidationError,
                )

        frappe.db.commit()

        return {
            "ok": True,
            "operation":
                "retire_legacy_service_duplicates",
            "committed": True,
            "idempotent_noop": False,
            "repointed_requests":
                repointed,
            "cleared_task_type_mappings":
                cleared,
            "deleted": 0,
            "validation": post,
        }

    except Exception:
        frappe.db.rollback(
            save_point=savepoint
        )
        raise
