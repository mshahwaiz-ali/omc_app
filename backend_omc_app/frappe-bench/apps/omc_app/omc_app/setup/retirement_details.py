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


def _retired_role_assignments() -> list[dict[str, Any]]:
    if not _doctype_exists("Has Role"):
        return []

    rows = frappe.get_all(
        "Has Role",
        filters={"role": ["in", list(RETIRED_EXTERNAL_ROLES)]},
        fields=["name", "parent", "parenttype", "parentfield", "role"],
        order_by="role asc, parent asc",
        limit_page_length=1000,
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
    """Return exact records blocking final compatibility-field retirement.

    This function is intentionally read-only. It exists so operators can review
    the very small set of historical exceptions before any destructive cleanup.
    """
    role_rows = _retired_role_assignments()
    staff_persona_rows = _retired_staff_personas()
    professional_rows = _customer_professional_rows()

    return {
        "read_only": True,
        "retired_role_assignments": role_rows,
        "retired_role_assignment_count": len(role_rows),
        "retired_staff_personas": staff_persona_rows,
        "retired_staff_persona_count": len(staff_persona_rows),
        "customer_professional_rows": professional_rows,
        "customer_professional_row_count": len(professional_rows),
    }
