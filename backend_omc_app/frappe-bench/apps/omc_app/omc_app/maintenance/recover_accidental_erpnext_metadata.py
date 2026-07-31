from __future__ import annotations

from typing import Any

import frappe


INVALID_PATCHES = {
    "omc_app.patches.remove_abandoned_gst_category_fields",
    "omc_app.patches.remove_abandoned_sales_invoice_scenario_fields",
}

EXPECTED_COLUMNS = {
    ("Sales Invoice", "custom_scenario_id"),
    ("Customer", "custom_gst_category"),
    ("Supplier", "custom_gst_category"),
}

CUSTOM_FIELDS = (
    {
        "doctype": "Custom Field",
        "name": "Sales Invoice-custom_scenario_id",
        "dt": "Sales Invoice",
        "fieldname": "custom_scenario_id",
        "fieldtype": "Link",
        "label": "Scenario Id",
        "options": "Scenario ID",
        "insert_after": "customer",
        "idx": 12,
        "owner": "Administrator",
        "modified_by": "Administrator",
        "creation": "2025-07-15 01:21:13.251407",
        "modified": "2025-07-15 01:21:13.251407",
    },
    {
        "doctype": "Custom Field",
        "name": "Sales Invoice-custom_column_break_jfsld",
        "dt": "Sales Invoice",
        "fieldname": "custom_column_break_jfsld",
        "fieldtype": "Column Break",
        "insert_after": "custom_scenario_id",
        "idx": 12,
        "owner": "Administrator",
        "modified_by": "Administrator",
        "creation": "2025-07-21 00:18:34.964117",
        "modified": "2025-07-21 00:18:34.964117",
    },
    {
        "doctype": "Custom Field",
        "name": "Customer-custom_gst_category",
        "dt": "Customer",
        "fieldname": "custom_gst_category",
        "fieldtype": "Data",
        "label": "Gst Category",
        "insert_after": "tax_category",
        "idx": 124,
        "owner": "Administrator",
        "modified_by": "Administrator",
        "creation": "2025-07-19 22:04:14.551443",
        "modified": "2025-07-19 22:04:14.551443",
    },
)

COMPARISON_FIELDS = (
    "dt",
    "fieldname",
    "fieldtype",
    "label",
    "options",
    "insert_after",
    "idx",
)


def _normalized(value: Any) -> Any:
    return None if value in ("", None) else value


def _assert_column_exists(doctype: str, fieldname: str) -> None:
    table = f"tab{doctype}"
    exists = frappe.db.sql(
        """
        SELECT 1
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = %s
          AND COLUMN_NAME = %s
        LIMIT 1
        """,
        (table, fieldname),
    )
    if not exists:
        frappe.throw(
            "Recovery aborted: expected existing column "
            f"{table}.{fieldname} was not found."
        )


def _expected_subset(definition: dict[str, Any]) -> dict[str, Any]:
    return {
        field: _normalized(definition.get(field))
        for field in COMPARISON_FIELDS
    }


def _current_custom_field(
    definition: dict[str, Any],
) -> dict[str, Any] | None:
    name = definition["name"]
    dt = definition["dt"]
    fieldname = definition["fieldname"]

    by_name = frappe.db.get_value(
        "Custom Field",
        name,
        list(COMPARISON_FIELDS),
        as_dict=True,
    )
    by_identity = frappe.db.get_value(
        "Custom Field",
        {"dt": dt, "fieldname": fieldname},
        ["name", *COMPARISON_FIELDS],
        as_dict=True,
    )

    if by_name and by_identity and by_identity.name != name:
        frappe.throw(
            "Recovery aborted: conflicting Custom Field records for "
            f"{dt}.{fieldname}: by_name={by_name}, "
            f"by_identity={by_identity}"
        )

    current = by_name or by_identity
    return dict(current) if current else None


def _assert_existing_field_matches(
    definition: dict[str, Any],
    current: dict[str, Any],
) -> None:
    actual = {
        field: _normalized(current.get(field))
        for field in COMPARISON_FIELDS
    }
    expected = _expected_subset(definition)

    if actual != expected:
        frappe.throw(
            "Recovery aborted: existing Custom Field does not match "
            f"the proven historical definition for "
            f"{definition['dt']}.{definition['fieldname']}. "
            f"Current={actual}, expected={expected}"
        )


def _preflight_custom_fields() -> list[dict[str, Any]]:
    missing: list[dict[str, Any]] = []

    for definition in CUSTOM_FIELDS:
        current = _current_custom_field(definition)
        if current:
            _assert_existing_field_matches(definition, current)
        else:
            missing.append(definition)

    return missing


def _restore_custom_fields(
    missing: list[dict[str, Any]],
) -> None:
    for definition in missing:
        doc = frappe.get_doc(definition)
        doc.flags.ignore_permissions = True
        doc.flags.ignore_mandatory = True
        doc.db_insert()


def _supplier_field() -> dict[str, Any] | None:
    field = frappe.db.get_value(
        "DocField",
        {
            "parent": "Supplier",
            "fieldname": "custom_gst_category",
        },
        ["fieldtype", "label", "options", "reqd"],
        as_dict=True,
    )
    return dict(field) if field else None


def _supplier_field_matches(field: dict[str, Any]) -> bool:
    expected = {
        "fieldtype": "Link",
        "label": "GST Category",
        "options": "GST Category",
        "reqd": 1,
    }
    return field == expected


def _restore_supplier_metadata_if_needed() -> None:
    current = _supplier_field()
    if current:
        if not _supplier_field_matches(current):
            frappe.throw(
                "Recovery aborted: unexpected existing Supplier "
                f"GST metadata: {current}"
            )
        return

    # ERPNext source was independently verified as restored and Git-clean.
    # Reload only this exact DocType. Do not run migrate or broad model sync.
    frappe.reload_doc("buying", "doctype", "supplier", force=True)

    restored = _supplier_field()
    if not restored or not _supplier_field_matches(restored):
        frappe.throw(
            "Recovery aborted: Supplier.custom_gst_category was not "
            f"restored exactly. Current={restored}"
        )


def _remove_invalid_patch_logs() -> None:
    rows = frappe.get_all(
        "Patch Log",
        filters={"patch": ["in", sorted(INVALID_PATCHES)]},
        fields=["name", "patch"],
    )

    seen: dict[str, list[str]] = {}
    for row in rows:
        seen.setdefault(row.patch, []).append(row.name)

    duplicates = {
        patch: names
        for patch, names in seen.items()
        if len(names) > 1
    }
    if duplicates:
        frappe.throw(
            "Recovery aborted: duplicate invalid Patch Log rows found: "
            f"{duplicates}"
        )

    for row in rows:
        frappe.db.delete(
            "Patch Log",
            {"name": row.name, "patch": row.patch},
        )


def execute() -> None:
    try:
        for doctype, fieldname in sorted(EXPECTED_COLUMNS):
            _assert_column_exists(doctype, fieldname)

        missing_custom_fields = _preflight_custom_fields()

        _restore_custom_fields(missing_custom_fields)
        _restore_supplier_metadata_if_needed()
        _remove_invalid_patch_logs()

        frappe.clear_cache(doctype="Sales Invoice")
        frappe.clear_cache(doctype="Customer")
        frappe.clear_cache(doctype="Supplier")

        frappe.db.commit()
    except Exception:
        frappe.db.rollback()
        raise

    print(
        "ERPNext metadata recovery completed. "
        f"Custom Fields inserted={len(missing_custom_fields)}."
    )
