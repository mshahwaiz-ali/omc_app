from __future__ import annotations

from typing import Any

import frappe


RETIRED_EXTERNAL_ROLES = (
    "OMC Consultant",
    "OMC Tax Associate",
    "OMC Business Partner",
    "OMC Employee",
)

RETIRED_STAFF_PERSONAS = (
    "OMC Consultant",
    "OMC Tax Associate",
    "OMC Business Partner",
)


def _text(value: Any) -> str:
    return str(value or "").strip()


def _doctype_exists(doctype: str) -> bool:
    try:
        return bool(frappe.db.exists("DocType", doctype))
    except Exception:
        return False


def _retired_user_role_assignments() -> list[dict[str, Any]]:
    """Return only actual User role assignments, never Report.roles rows."""
    if not _doctype_exists("Has Role"):
        return []

    rows = frappe.get_all(
        "Has Role",
        filters={
            "role": ["in", list(RETIRED_EXTERNAL_ROLES)],
            "parenttype": "User",
        },
        fields=["name", "parent", "parenttype", "parentfield", "role"],
        order_by="role asc, parent asc",
        limit_page_length=1000,
    )
    return [dict(row) for row in rows]


def _referral_report_role_rows() -> list[dict[str, Any]]:
    """Expose My Referrals role metadata separately; these are not user roles."""
    if not _doctype_exists("Has Role"):
        return []

    rows = frappe.get_all(
        "Has Role",
        filters={
            "parent": "My Referrals",
            "parenttype": "Report",
            "parentfield": "roles",
        },
        fields=["name", "parent", "parenttype", "parentfield", "role"],
        order_by="role asc",
        limit_page_length=100,
    )
    return [dict(row) for row in rows]


def _retired_staff_personas() -> list[dict[str, Any]]:
    if not _doctype_exists("OMC Staff Access"):
        return []

    rows = frappe.get_all(
        "OMC Staff Access",
        filters={"persona_snapshot": ["in", list(RETIRED_STAFF_PERSONAS)]},
        fields=[
            "name",
            "user",
            "employee",
            "access_status",
            "persona_snapshot",
            "persona_source",
            "reconciliation_status",
        ],
        order_by="persona_snapshot asc, user asc",
        limit_page_length=1000,
    )
    return [dict(row) for row in rows]


def _customer_professional_rows() -> list[dict[str, Any]]:
    if not _doctype_exists("OMC Customer Profile"):
        return []

    rows = frappe.get_all(
        "OMC Customer Profile",
        fields=[
            "name",
            "full_name",
            "user",
            "linked_app_user",
            "education",
            "experience",
            "remarks",
        ],
        limit_page_length=100000,
    )

    result = []
    for row in rows:
        data = dict(row)
        if not any(
            _text(data.get(fieldname))
            for fieldname in ("education", "experience", "remarks")
        ):
            continue
        result.append(
            {
                "name": _text(data.get("name")),
                "full_name": _text(data.get("full_name")),
                "user": _text(data.get("user")),
                "linked_app_user": _text(data.get("linked_app_user")),
                "education": _text(data.get("education")),
                "experience": _text(data.get("experience")),
                "remarks": _text(data.get("remarks")),
            }
        )

    return result


def preview_retirement_blockers() -> dict[str, Any]:
    """Return exact records relevant to the final compatibility cleanup.

    This function is intentionally read-only. Report role rows are reported
    separately and never treated as User role assignments or retirement blockers.
    """
    user_role_rows = _retired_user_role_assignments()
    referral_report_roles = _referral_report_role_rows()
    staff_persona_rows = _retired_staff_personas()
    professional_rows = _customer_professional_rows()

    return {
        "read_only": True,
        "retired_user_role_assignments": user_role_rows,
        "retired_user_role_assignment_count": len(user_role_rows),
        "my_referrals_report_roles": referral_report_roles,
        "my_referrals_report_role_count": len(referral_report_roles),
        "retired_staff_personas": staff_persona_rows,
        "retired_staff_persona_count": len(staff_persona_rows),
        "customer_professional_rows": professional_rows,
        "customer_professional_row_count": len(professional_rows),
    }
