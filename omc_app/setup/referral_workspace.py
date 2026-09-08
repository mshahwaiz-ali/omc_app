from __future__ import annotations

import frappe


_TARGETS = (
    {
        "hidden": 0,
        "is_query_report": 1,
        "label": "My Referrals",
        "link_count": 0,
        "link_to": "My Referrals",
        "link_type": "Report",
        "onboard": 0,
        "type": "Link",
    },
    {
        "hidden": 0,
        "is_query_report": 0,
        "label": "Referral Codes",
        "link_count": 0,
        "link_to": "OMC Referral",
        "link_type": "DocType",
        "onboard": 0,
        "type": "Link",
    },
)

_REFERRAL_LABELS = {"Referrals", "My Referrals", "Referral Codes"}
_REFERRAL_TARGETS = {"My Referrals", "OMC Referral"}
_SECTION_LABEL = "Customers & Referrals"
_ANCHOR_LABEL = "Customer Profiles"
_MY_REFERRALS_REPORT_ROLES = (
    "Consultant",
    "OMC Consultant",
    "Tax Associates",
    "OMC Tax Associate",
    "Business Partner",
    "OMC Business Partner",
    "OMC Admin",
    "OMC Manager",
)


def _row_payload(row) -> dict:
    payload = {}
    for field in row.meta.fields:
        fieldname = field.fieldname
        if not fieldname:
            continue
        value = row.get(fieldname)
        if value is not None:
            payload[fieldname] = value
    return payload


def _ensure_my_referrals_report_roles() -> None:
    """Replace stale/duplicate Report.roles rows with the source authority."""
    if not frappe.db.exists("Report", "My Referrals"):
        return

    report = frappe.get_doc("Report", "My Referrals")
    current = [
        str(row.get("role") or "").strip()
        for row in report.get("roles") or []
        if str(row.get("role") or "").strip()
    ]
    desired = list(_MY_REFERRALS_REPORT_ROLES)
    if current == desired:
        return

    report.set("roles", [{"role": role} for role in desired])
    report.flags.ignore_permissions = True
    report.save(ignore_permissions=True)


def ensure_referral_workspace_links() -> None:
    """Keep referral report roles and curated workspace links in exact state."""
    _ensure_my_referrals_report_roles()

    if not frappe.db.exists("Workspace", "OMC App"):
        frappe.clear_cache()
        return

    workspace = frappe.get_doc("Workspace", "OMC App")
    preserved = []

    for row in workspace.get("links") or []:
        label = str(row.get("label") or "").strip()
        link_to = str(row.get("link_to") or "").strip()
        if label in _REFERRAL_LABELS or link_to in _REFERRAL_TARGETS:
            continue
        preserved.append(_row_payload(row))

    insert_at = next(
        (
            index + 1
            for index, row in enumerate(preserved)
            if str(row.get("label") or "").strip() == _ANCHOR_LABEL
        ),
        None,
    )
    if insert_at is None:
        insert_at = next(
            (
                index + 1
                for index, row in enumerate(preserved)
                if str(row.get("label") or "").strip() == _SECTION_LABEL
            ),
            len(preserved),
        )

    preserved[insert_at:insert_at] = [dict(item) for item in _TARGETS]
    workspace.set("links", preserved)
    workspace.flags.ignore_permissions = True
    workspace.save(ignore_permissions=True)
    frappe.clear_cache()
