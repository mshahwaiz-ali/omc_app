from __future__ import annotations

from typing import Any

import frappe

from omc_app.setup.app_defaults.faqs import (
    FAQS,
    validate_faq_manifest,
)


DOCTYPE = "OMC FAQ"

MANAGED_FIELDS = (
    "faq_id",
    "app_defaults_managed",
    "question",
    "answer",
    "category",
    "sort_order",
    "status",
)

NUMERIC_FIELDS = {
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


def _desired(faq) -> dict[str, Any]:
    return {
        "faq_id": faq.faq_id,
        "app_defaults_managed": 1,
        "question": faq.question,
        "answer": faq.answer,
        "category": faq.category,
        "sort_order": int(faq.sort_order),
        "status": faq.status,
    }


def _changes(
    current: dict[str, Any],
    desired: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    result = {}

    for fieldname in MANAGED_FIELDS:
        current_value = current.get(fieldname)
        desired_value = desired.get(fieldname)

        if _same(
            fieldname,
            current_value,
            desired_value,
        ):
            continue

        result[fieldname] = {
            "current": current_value,
            "desired": desired_value,
        }

    return result


def preview_faqs() -> dict[str, Any]:
    blockers = []
    conflicts = []

    try:
        manifest = validate_faq_manifest()
    except Exception as exc:
        manifest = {
            "faqs": len(FAQS),
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
            "archive": [],
            "unchanged": [],
            "ignored_unmanaged": [],
            "ignored_archived_managed": [],
            "conflicts": conflicts,
            "blockers": blockers,
            "summary": {
                "create": 0,
                "update": 0,
                "archive": 0,
                "unchanged": 0,
                "ignored_unmanaged": 0,
                "ignored_archived_managed": 0,
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

    by_faq_id = {
        _text(row.faq_id): dict(row)
        for row in rows
        if _text(row.faq_id)
    }

    desired_by_id = {
        faq.faq_id: _desired(faq)
        for faq in FAQS
    }

    create = []
    update = []
    archive = []
    unchanged = []
    ignored_unmanaged = []
    ignored_archived_managed = []

    for faq_id, desired in desired_by_id.items():
        current = by_faq_id.get(faq_id)

        if not current:
            create.append(
                {
                    "faq_id": faq_id,
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
                        "managed_faq_id_owned_by_unmanaged_row"
                    ),
                    "faq_id": faq_id,
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
                    "faq_id": faq_id,
                    "name": current["name"],
                    "changes": changes,
                    "desired": desired,
                }
            )
        else:
            unchanged.append(
                {
                    "faq_id": faq_id,
                    "name": current["name"],
                }
            )

    desired_ids = set(desired_by_id)

    for row in rows:
        faq_id = _text(row.faq_id)

        if faq_id in desired_ids:
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
                    "faq_id": faq_id,
                    "name": row.name,
                    "status": row.status or "",
                }
            )
            continue

        if _text(row.status) != "Archived":
            archive.append(
                {
                    "faq_id": faq_id,
                    "name": row.name,
                    "current_status": row.status or "",
                }
            )
        else:
            ignored_archived_managed.append(
                {
                    "faq_id": faq_id,
                    "name": row.name,
                }
            )

    summary = {
        "create": len(create),
        "update": len(update),
        "archive": len(archive),
        "unchanged": len(unchanged),
        "ignored_unmanaged": len(
            ignored_unmanaged
        ),
        "ignored_archived_managed": len(
            ignored_archived_managed
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
        and not archive
    )

    return {
        "manifest": manifest,
        "create": create,
        "update": update,
        "archive": archive,
        "unchanged": unchanged,
        "ignored_unmanaged": ignored_unmanaged,
        "ignored_archived_managed": (
            ignored_archived_managed
        ),
        "conflicts": conflicts,
        "blockers": blockers,
        "summary": summary,
        "safe_to_sync": safe_to_sync,
        "converged": converged,
    }


def validate_faqs() -> dict[str, Any]:
    preview = preview_faqs()

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


def sync_faqs(
    *,
    commit: bool = True,
) -> dict[str, Any]:
    preview = preview_faqs()

    if not preview.get("safe_to_sync"):
        frappe.throw(
            "FAQ synchronization is blocked: "
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
    archived = 0

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

    for item in preview["archive"]:
        doc = frappe.get_doc(
            DOCTYPE,
            item["name"],
        )
        doc.status = "Archived"
        doc.save(
            ignore_permissions=True
        )
        archived += 1

    validation = validate_faqs()

    if not validation["valid"]:
        frappe.throw(
            "FAQs failed post-sync validation: "
            + frappe.as_json(validation),
            frappe.ValidationError,
        )

    if commit:
        frappe.db.commit()

    return {
        "created": created,
        "updated": updated,
        "archived": archived,
        "validation": validation,
    }
