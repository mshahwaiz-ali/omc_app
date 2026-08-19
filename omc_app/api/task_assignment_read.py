from __future__ import annotations

import frappe

from omc_app.api import capabilities as capability_policy
from omc_app.api import identity


DEFAULT_LIMIT = 50
MAX_LIMIT = 100


def _limit(value):
    try:
        return min(max(int(value or DEFAULT_LIMIT), 1), MAX_LIMIT)
    except (TypeError, ValueError):
        frappe.throw("Invalid assignee limit.", frappe.ValidationError)


def _eligible_target(user):
    user = str(user or "").strip()
    if not user or not identity.user_is_enabled(user):
        return False
    values = capability_policy.effective(user)
    return bool(
        values.get("can_manage_tasks")
        or values.get("can_manage_assigned_tasks")
    )


def _user_label(user):
    row = frappe.db.get_value(
        "User",
        user,
        ["full_name", "email"],
        as_dict=True,
    )
    if not row:
        return user
    return str(row.get("full_name") or row.get("email") or user).strip()


@frappe.whitelist()
def get_task_assignee_options(search=None, limit=50):
    """Return only approved OMC staff who are eligible to own service tasks."""
    capability_policy.require("can_manage_tasks")
    search_text = str(search or "").strip().lower()
    page_limit = _limit(limit)

    rows = frappe.get_all(
        "OMC Staff Access",
        filters={
            "access_status": "Approved",
            "reconciliation_status": "Current",
        },
        fields=["user", "primary_role"],
        order_by="modified desc",
        limit_page_length=MAX_LIMIT * 2,
    )

    options = []
    seen = set()
    for row in rows:
        user = str(row.user or "").strip()
        if not user or user in seen or not _eligible_target(user):
            continue
        label = _user_label(user)
        if search_text and search_text not in f"{label} {user}".lower():
            continue
        seen.add(user)
        options.append(
            {
                "user": user,
                "label": label,
                "primary_role": str(row.primary_role or "").strip(),
            }
        )
        if len(options) >= page_limit:
            break

    options.sort(key=lambda item: (item["label"].lower(), item["user"].lower()))
    return {"assignees": options}
