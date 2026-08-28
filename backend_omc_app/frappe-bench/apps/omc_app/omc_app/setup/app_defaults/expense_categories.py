from __future__ import annotations

from typing import Any

import frappe

from omc_app.api.expense import DEFAULT_EXPENSE_CATEGORIES


DOCTYPE = "OMC Expense Category"

MANAGED_FIELDS = (
    "title",
    "transaction_type",
    "icon",
    "color",
    "is_default",
    "is_tax_relevant",
    "business_default",
    "sort_order",
    "enabled",
)

NUMERIC_FIELDS = {
    "is_default",
    "is_tax_relevant",
    "business_default",
    "sort_order",
    "enabled",
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


def _desired(
    category: dict[str, Any],
) -> dict[str, Any]:
    return {
        "title": category["title"],
        "transaction_type": category["transaction_type"],
        "icon": category.get("icon") or "category",
        "color": category.get("color") or "",
        "is_default": 1,
        "is_tax_relevant": int(
            category.get("is_tax_relevant") or 0
        ),
        "business_default": int(
            category.get("business_default") or 0
        ),
        "sort_order": int(
            category.get("sort_order") or 0
        ),
        "enabled": 1,
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


def preview_expense_categories() -> dict[str, Any]:
    if not frappe.db.exists(
        "DocType",
        DOCTYPE,
    ):
        return {
            "create": [],
            "update": [],
            "unchanged": [],
            "ignored_custom": [],
            "conflicts": [],
            "blockers": [
                {
                    "type": "missing_doctype",
                    "doctype": DOCTYPE,
                }
            ],
            "summary": {
                "create": 0,
                "update": 0,
                "unchanged": 0,
                "ignored_custom": 0,
                "conflicts": 0,
                "blockers": 1,
            },
            "safe_to_sync": False,
            "converged": False,
        }

    rows = frappe.get_all(
        DOCTYPE,
        fields=["name", *MANAGED_FIELDS],
        limit_page_length=1000,
    )

    by_title = {
        _text(row.title): dict(row)
        for row in rows
        if _text(row.title)
    }

    desired_titles = {
        category["title"]
        for category in DEFAULT_EXPENSE_CATEGORIES
    }

    create = []
    update = []
    unchanged = []
    ignored_custom = []
    conflicts = []
    blockers = []

    for category in DEFAULT_EXPENSE_CATEGORIES:
        desired = _desired(category)
        title = desired["title"]
        current = by_title.get(title)

        if not current:
            create.append(
                {
                    "title": title,
                    "desired": desired,
                }
            )
            continue

        if not int(
            _number(
                current.get("is_default")
            )
        ):
            conflicts.append(
                {
                    "type": (
                        "canonical_title_owned_by_custom_row"
                    ),
                    "title": title,
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
                    "title": title,
                    "name": current["name"],
                    "changes": changes,
                    "desired": desired,
                }
            )
        else:
            unchanged.append(
                {
                    "title": title,
                    "name": current["name"],
                }
            )

    for row in rows:
        title = _text(row.title)

        if title in desired_titles:
            continue

        ignored_custom.append(
            {
                "title": title,
                "name": row.name,
                "is_default": int(
                    row.is_default or 0
                ),
                "enabled": int(
                    row.enabled or 0
                ),
            }
        )

    summary = {
        "create": len(create),
        "update": len(update),
        "unchanged": len(unchanged),
        "ignored_custom": len(ignored_custom),
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
    )

    return {
        "create": create,
        "update": update,
        "unchanged": unchanged,
        "ignored_custom": ignored_custom,
        "conflicts": conflicts,
        "blockers": blockers,
        "summary": summary,
        "safe_to_sync": safe_to_sync,
        "converged": converged,
    }


def validate_expense_categories() -> dict[str, Any]:
    preview = preview_expense_categories()

    return {
        "valid": bool(
            preview.get("converged")
        ),
        "safe_to_sync": bool(
            preview.get("safe_to_sync")
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


def sync_expense_categories(
    *,
    commit: bool = True,
) -> dict[str, Any]:
    preview = preview_expense_categories()

    if not preview.get("safe_to_sync"):
        frappe.throw(
            "Expense Category synchronization "
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

    for item in preview["create"]:
        doc = frappe.get_doc(
            {
                "doctype": DOCTYPE,
                **item["desired"],
            }
        )

        doc.insert(
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

    validation = validate_expense_categories()

    if not validation["valid"]:
        frappe.throw(
            "Expense Categories failed "
            "post-sync validation: "
            + frappe.as_json(validation),
            frappe.ValidationError,
        )

    if commit:
        frappe.db.commit()

    return {
        "created": created,
        "updated": updated,
        "validation": validation,
    }
