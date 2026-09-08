from __future__ import annotations

from typing import Any

import frappe


RETIRED_EXTERNAL_ROLES = (
    "OMC Consultant",
    "OMC Tax Associate",
    "OMC Business Partner",
    "OMC Employee",
)

RETIRED_MOBILE_SETTING_FIELDS = (
    "integration_mode",
    "erpnext_integration_enabled",
    "customer_doctype",
    "customer_name_field",
    "customer_email_field",
    "customer_mobile_field",
    "invoice_doctype",
    "invoice_customer_field",
    "invoice_amount_field",
    "invoice_date_field",
    "invoice_status_field",
    "payment_doctype",
    "payment_customer_field",
    "payment_amount_field",
    "payment_date_field",
    "payment_mode_field",
    "is_mobile_backend_active",
    "signup_enabled",
    "require_customer_approval",
    "subscriptions_enabled",
)


def _text(value: Any) -> str:
    return str(value or "").strip()


def _doctype_exists(doctype: str) -> bool:
    try:
        return bool(frappe.db.exists("DocType", doctype))
    except Exception:
        return False


def _field_exists(doctype: str, fieldname: str) -> bool:
    try:
        return _doctype_exists(doctype) and bool(
            frappe.get_meta(doctype).has_field(fieldname)
        )
    except Exception:
        return False


def _count(doctype: str, filters: dict | None = None) -> int:
    if not _doctype_exists(doctype):
        return 0
    return int(frappe.db.count(doctype, filters=filters or {}) or 0)


def _rows(doctype: str, fields: list[str]) -> list[dict[str, Any]]:
    if not _doctype_exists(doctype):
        return []
    available = [field for field in fields if _field_exists(doctype, field)]
    if not available:
        return []
    return [
        dict(row)
        for row in frappe.get_all(
            doctype,
            fields=available,
            limit_page_length=100000,
        )
    ]


def _manual_customer_state() -> dict[str, Any]:
    total = _count("OMC Manual Customer")
    rows = _rows(
        "OMC Manual Customer",
        ["name", "conversion_status", "linked_customer_profile"],
    )
    linked = sum(
        1
        for row in rows
        if _text(row.get("conversion_status")) in {"Linked", "Archived"}
        or _text(row.get("linked_customer_profile"))
    )

    request_refs = 0
    if _field_exists("OMC Service Request", "manual_customer"):
        request_refs = len(
            frappe.get_all(
                "OMC Service Request",
                filters={"manual_customer": ["is", "set"]},
                pluck="name",
                limit_page_length=100000,
            )
        )

    return {
        "doctype_exists": _doctype_exists("OMC Manual Customer"),
        "records": total,
        "linked_or_archived": linked,
        "unresolved": max(total - linked, 0),
        "service_request_references": request_refs,
        "safe_to_drop_now": total == 0 and request_refs == 0,
    }


def _legacy_lead_state() -> dict[str, Any]:
    exists = _doctype_exists("OMC Lead")
    records = _count("OMC Lead") if exists else 0
    return {
        "doctype_exists": exists,
        "records": records,
        "safe_to_drop_now": not exists or records == 0,
    }


def _service_compatibility_state() -> dict[str, Any]:
    rows = _rows(
        "OMC Service",
        [
            "name",
            "default_assignment_role",
            "estimated_duration",
            "completion_time",
        ],
    )

    nonstandard_roles = [
        row.get("name")
        for row in rows
        if _text(row.get("default_assignment_role"))
        not in {"", "Employee"}
    ]
    duration_rows = [
        row.get("name")
        for row in rows
        if _text(row.get("estimated_duration"))
    ]
    duration_mismatches = [
        row.get("name")
        for row in rows
        if _text(row.get("estimated_duration"))
        and _text(row.get("estimated_duration"))
        != _text(row.get("completion_time"))
    ]

    return {
        "services": len(rows),
        "nonstandard_assignment_role_count": len(nonstandard_roles),
        "nonstandard_assignment_role_services": nonstandard_roles,
        "estimated_duration_populated_count": len(duration_rows),
        "estimated_duration_mismatch_count": len(duration_mismatches),
        "estimated_duration_mismatch_services": duration_mismatches,
    }


def _legacy_role_state() -> dict[str, Any]:
    assignments = {}
    if not _doctype_exists("Has Role"):
        return {
            "assignments": assignments,
            "total_assignments": 0,
            "safe_to_remove_role_compatibility": True,
        }

    for role in RETIRED_EXTERNAL_ROLES:
        assignments[role] = int(
            frappe.db.count("Has Role", filters={"role": role}) or 0
        )

    total = sum(assignments.values())
    return {
        "assignments": assignments,
        "total_assignments": total,
        "safe_to_remove_role_compatibility": total == 0,
    }


def _customer_profile_compatibility_state() -> dict[str, Any]:
    fields = [
        "name",
        "register_as",
        "customer_type",
        "manual_customer_status",
        "linked_app_user",
        "user",
        "education",
        "experience",
        "remarks",
    ]
    rows = _rows("OMC Customer Profile", fields)

    noncustomer_persona = [
        row.get("name")
        for row in rows
        if (
            _text(row.get("register_as"))
            and _text(row.get("register_as")) != "Customer"
        )
        or (
            _text(row.get("customer_type"))
            and _text(row.get("customer_type")) != "Customer"
        )
    ]
    manual_status = [
        row.get("name")
        for row in rows
        if _text(row.get("manual_customer_status"))
    ]
    legacy_link_only = [
        row.get("name")
        for row in rows
        if _text(row.get("linked_app_user"))
        and not _text(row.get("user"))
    ]
    professional_data = [
        row.get("name")
        for row in rows
        if any(
            _text(row.get(fieldname))
            for fieldname in ("education", "experience", "remarks")
        )
    ]

    return {
        "profiles": len(rows),
        "noncustomer_persona_count": len(noncustomer_persona),
        "noncustomer_persona_profiles": noncustomer_persona,
        "manual_status_count": len(manual_status),
        "legacy_link_without_user_count": len(legacy_link_only),
        "customer_profile_professional_data_count": len(professional_data),
        "customer_profile_professional_data_profiles": professional_data,
        "safe_to_remove_customer_persona_fields": len(noncustomer_persona) == 0,
        "safe_to_remove_customer_professional_fields": len(professional_data) == 0,
    }


def _preference_compatibility_state() -> dict[str, Any]:
    pairs = (
        ("notifications_enabled", "service_updates_enabled"),
        ("email_updates_enabled", "email_notifications_enabled"),
        ("payment_reminders_enabled", "payment_alerts_enabled"),
    )
    fields = ["name"] + [field for pair in pairs for field in pair]
    rows = _rows("OMC Customer Preference", fields)

    mismatches = 0
    for row in rows:
        if any(
            field in row
            and canonical in row
            and int(row.get(field) or 0) != int(row.get(canonical) or 0)
            for field, canonical in pairs
        ):
            mismatches += 1

    return {
        "preferences": len(rows),
        "legacy_alias_mismatch_count": mismatches,
        "safe_to_drop_aliases_after_client_cutover": mismatches == 0,
    }


def _support_compatibility_state() -> dict[str, Any]:
    legacy_messages = 0
    if _field_exists("OMC Support Ticket", "message"):
        legacy_messages = len(
            frappe.get_all(
                "OMC Support Ticket",
                filters={"message": ["is", "set"]},
                pluck="name",
                limit_page_length=100000,
            )
        )

    return {
        "legacy_message_rows": legacy_messages,
        "safe_to_drop_message_after_backfill": legacy_messages == 0,
    }


def _mobile_setting_storage_state() -> dict[str, Any]:
    columns = {}
    for fieldname in RETIRED_MOBILE_SETTING_FIELDS:
        try:
            columns[fieldname] = bool(
                frappe.db.has_column("OMC Mobile Settings", fieldname)
            )
        except Exception:
            columns[fieldname] = False

    remaining = [field for field, exists in columns.items() if exists]
    return {
        "retired_columns_still_in_database": remaining,
        "retired_column_count": len(remaining),
        "note": (
            "Frappe may retain physical columns after DocField removal. "
            "They are not runtime configuration once absent from metadata."
        ),
    }


def preview_legacy_retirement() -> dict[str, Any]:
    """Return a read-only inventory for the final destructive cleanup pass.

    This function intentionally mutates nothing. Run it after migrate on a
    representative local/production copy before deleting compatibility fields,
    legacy DocTypes or retired role readers.
    """
    return {
        "read_only": True,
        "manual_customer": _manual_customer_state(),
        "legacy_omc_lead": _legacy_lead_state(),
        "service_compatibility": _service_compatibility_state(),
        "legacy_role_assignments": _legacy_role_state(),
        "customer_profile_compatibility": _customer_profile_compatibility_state(),
        "customer_preference_compatibility": _preference_compatibility_state(),
        "support_ticket_compatibility": _support_compatibility_state(),
        "mobile_settings_storage": _mobile_setting_storage_state(),
    }
