from __future__ import annotations

from typing import Any

import frappe
from frappe.utils import get_datetime

from omc_app.setup.app_defaults.knowledge import (
    KNOWLEDGE_ARTICLES,
    validate_knowledge_manifest,
)


DOCTYPE = "OMC Knowledge Article"

MANAGED_FIELDS = (
    "article_id",
    "app_defaults_managed",
    "title",
    "category",
    "summary",
    "content",
    "cover_image",
    "is_featured",
    "sort_order",
    "status",
    "published_on",
)

NUMERIC_FIELDS = {
    "app_defaults_managed",
    "is_featured",
    "sort_order",
}

ADOPTABLE_BASELINES = {
    "business-document-checklist": {
        "title": "A simple business document checklist",
        "category": "Business Guide",
        "summary": (
            "A practical way to keep the documents commonly needed for "
            "professional services organised and easy to find."
        ),
        "status": "Published",
    },
    "choosing-right-service": {
        "title": "How to choose the right OMC service",
        "category": "Getting Started",
        "summary": (
            "Start with the outcome you need, review the service requirements, "
            "and check the documents before submitting a request."
        ),
        "status": "Published",
    },
}


def _text(value: Any) -> str:
    return str(value or "").strip()


def _number(value: Any) -> float:
    try:
        return float(value or 0)
    except (TypeError, ValueError):
        return 0.0


def _same(fieldname: str, current: Any, desired: Any) -> bool:
    if fieldname in NUMERIC_FIELDS:
        return _number(current) == _number(desired)

    if fieldname == "published_on":
        if not current and not desired:
            return True
        try:
            return get_datetime(current) == get_datetime(desired)
        except (TypeError, ValueError):
            return _text(current) == _text(desired)

    return _text(current) == _text(desired)


def _desired(article) -> dict[str, Any]:
    return {
        "article_id": article.article_id,
        "app_defaults_managed": 1,
        "title": article.title,
        "category": article.category,
        "summary": article.summary,
        "content": article.content,
        "cover_image": article.cover_image,
        "is_featured": int(article.is_featured),
        "sort_order": int(article.sort_order),
        "status": article.status,
        "published_on": article.published_on,
    }


def _changes(
    current: dict[str, Any],
    desired: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    result = {}

    for fieldname in MANAGED_FIELDS:
        current_value = current.get(fieldname)
        desired_value = desired.get(fieldname)
        if _same(fieldname, current_value, desired_value):
            continue
        result[fieldname] = {
            "current": current_value,
            "desired": desired_value,
        }

    return result


def _can_adopt(article_id: str, current: dict[str, Any]) -> bool:
    baseline = ADOPTABLE_BASELINES.get(article_id)
    if not baseline:
        return False

    return all(
        _same(fieldname, current.get(fieldname), expected)
        for fieldname, expected in baseline.items()
    )


def _empty_preview(
    manifest: dict[str, Any],
    blockers: list[dict[str, Any]],
    conflicts: list[dict[str, Any]],
) -> dict[str, Any]:
    summary = {
        "create": 0,
        "adopt": 0,
        "update": 0,
        "archive": 0,
        "unchanged": 0,
        "ignored_unmanaged": 0,
        "ignored_archived_managed": 0,
        "conflicts": len(conflicts),
        "blockers": len(blockers),
    }
    return {
        "manifest": manifest,
        "create": [],
        "adopt": [],
        "update": [],
        "archive": [],
        "unchanged": [],
        "ignored_unmanaged": [],
        "ignored_archived_managed": [],
        "conflicts": conflicts,
        "blockers": blockers,
        "summary": summary,
        "safe_to_sync": False,
        "converged": False,
    }


def preview_knowledge_articles() -> dict[str, Any]:
    blockers = []
    conflicts = []

    try:
        manifest = validate_knowledge_manifest()
    except Exception as exc:
        manifest = {
            "articles": len(KNOWLEDGE_ARTICLES),
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
        return _empty_preview(manifest, blockers, conflicts)

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
    by_id = {
        _text(row.article_id): dict(row)
        for row in rows
        if _text(row.article_id)
    }
    desired_by_id = {
        article.article_id: _desired(article)
        for article in KNOWLEDGE_ARTICLES
    }

    create = []
    update = []
    adopt = []
    archive = []
    unchanged = []
    ignored_unmanaged = []
    ignored_archived_managed = []

    for article_id, desired in desired_by_id.items():
        current = by_id.get(article_id)
        if not current:
            create.append(
                {
                    "article_id": article_id,
                    "desired": desired,
                }
            )
            continue

        is_managed = bool(
            int(_number(current.get("app_defaults_managed")))
        )
        changes = _changes(current, desired)

        if not is_managed:
            if _can_adopt(article_id, current):
                adopt.append(
                    {
                        "article_id": article_id,
                        "name": current["name"],
                        "changes": changes,
                        "desired": desired,
                    }
                )
            else:
                conflicts.append(
                    {
                        "type": "managed_article_id_owned_by_unmanaged_row",
                        "article_id": article_id,
                        "name": current.get("name"),
                    }
                )
            continue

        if changes:
            update.append(
                {
                    "article_id": article_id,
                    "name": current["name"],
                    "changes": changes,
                    "desired": desired,
                }
            )
        else:
            unchanged.append(
                {
                    "article_id": article_id,
                    "name": current["name"],
                }
            )

    desired_ids = set(desired_by_id)
    for row in rows:
        article_id = _text(row.article_id)
        if article_id in desired_ids:
            continue

        is_managed = bool(int(_number(row.app_defaults_managed)))
        if not is_managed:
            ignored_unmanaged.append(
                {
                    "article_id": article_id,
                    "name": row.name,
                    "status": row.status or "",
                }
            )
            continue

        if _text(row.status) != "Archived":
            archive.append(
                {
                    "article_id": article_id,
                    "name": row.name,
                    "current_status": row.status or "",
                }
            )
        else:
            ignored_archived_managed.append(
                {
                    "article_id": article_id,
                    "name": row.name,
                }
            )

    summary = {
        "create": len(create),
        "adopt": len(adopt),
        "update": len(update),
        "archive": len(archive),
        "unchanged": len(unchanged),
        "ignored_unmanaged": len(ignored_unmanaged),
        "ignored_archived_managed": len(ignored_archived_managed),
        "conflicts": len(conflicts),
        "blockers": len(blockers),
    }
    safe_to_sync = not conflicts and not blockers
    converged = (
        safe_to_sync
        and not create
        and not adopt
        and not update
        and not archive
    )

    return {
        "manifest": manifest,
        "create": create,
        "adopt": adopt,
        "update": update,
        "archive": archive,
        "unchanged": unchanged,
        "ignored_unmanaged": ignored_unmanaged,
        "ignored_archived_managed": ignored_archived_managed,
        "conflicts": conflicts,
        "blockers": blockers,
        "summary": summary,
        "safe_to_sync": safe_to_sync,
        "converged": converged,
    }


def validate_knowledge_articles() -> dict[str, Any]:
    preview = preview_knowledge_articles()
    return {
        "valid": bool(preview.get("converged")),
        "safe_to_sync": bool(preview.get("safe_to_sync")),
        "manifest": preview.get("manifest", {}),
        "summary": preview.get("summary", {}),
        "conflicts": preview.get("conflicts", []),
        "blockers": preview.get("blockers", []),
    }


def sync_knowledge_articles(*, commit: bool = True) -> dict[str, Any]:
    preview = preview_knowledge_articles()
    if not preview.get("safe_to_sync"):
        frappe.throw(
            "Knowledge Article synchronization is blocked: "
            + frappe.as_json(
                {
                    "conflicts": preview.get("conflicts", []),
                    "blockers": preview.get("blockers", []),
                }
            ),
            frappe.ValidationError,
        )

    created = 0
    adopted = 0
    updated = 0
    archived = 0

    for item in preview["create"]:
        frappe.get_doc(
            {
                "doctype": DOCTYPE,
                **item["desired"],
            }
        ).insert(ignore_permissions=True)
        created += 1

    for bucket, is_adoption in (("adopt", True), ("update", False)):
        for item in preview[bucket]:
            doc = frappe.get_doc(DOCTYPE, item["name"])
            for fieldname, value in item["desired"].items():
                doc.set(fieldname, value)
            doc.save(ignore_permissions=True)
            if is_adoption:
                adopted += 1
            else:
                updated += 1

    for item in preview["archive"]:
        doc = frappe.get_doc(DOCTYPE, item["name"])
        doc.status = "Archived"
        doc.save(ignore_permissions=True)
        archived += 1

    validation = validate_knowledge_articles()
    if not validation["valid"]:
        frappe.throw(
            "Knowledge Articles failed post-sync validation: "
            + frappe.as_json(validation),
            frappe.ValidationError,
        )

    if commit:
        frappe.db.commit()

    return {
        "created": created,
        "adopted": adopted,
        "updated": updated,
        "archived": archived,
        "validation": validation,
    }
