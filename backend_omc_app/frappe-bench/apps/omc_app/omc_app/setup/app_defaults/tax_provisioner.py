from __future__ import annotations

import json
from typing import Any

import frappe

from omc_app.setup.app_defaults.tax_manifest import (
    DEFAULT_TAX_YEAR,
    TAX_INPUT_FIELDS,
    TAX_YEARS,
    VERIFIED_ON,
    validate_tax_manifest,
)


YEAR_DOCTYPE = "OMC Tax Year"
INPUT_DOCTYPE = "OMC Tax Input Field"
SETTINGS_DOCTYPE = "OMC Tax Calculator Settings"

YEAR_FIELDS = (
    "tax_year",
    "app_defaults_managed",
    "title",
    "country",
    "currency",
    "effective_from",
    "effective_to",
    "status",
    "is_active",
    "section_4ab_threshold",
    "salary_surcharge_percent",
    "non_salaried_surcharge_percent",
    "source_reference",
    "last_verified_on",
    "public_note",
)

SLAB_FIELDS = (
    "income_type",
    "filer_status",
    "taxpayer_type",
    "from_amount",
    "to_amount",
    "fixed_tax",
    "rate_percent",
    "amount_over",
    "sort_order",
    "label",
)

INPUT_FIELDS = (
    "tax_year",
    "field_key",
    "app_defaults_managed",
    "label",
    "input_type",
    "income_type",
    "mode",
    "is_required",
    "is_active",
    "default_value",
    "options_json",
    "help_text",
    "sort_order",
)

NUMERIC_YEAR_FIELDS = {
    "app_defaults_managed",
    "is_active",
    "section_4ab_threshold",
    "salary_surcharge_percent",
    "non_salaried_surcharge_percent",
}
NUMERIC_SLAB_FIELDS = {
    "from_amount",
    "to_amount",
    "fixed_tax",
    "rate_percent",
    "amount_over",
    "sort_order",
}
NUMERIC_INPUT_FIELDS = {
    "app_defaults_managed",
    "is_required",
    "is_active",
    "sort_order",
}

SETTINGS_VALUES = {
    "calculator_enabled": 1,
    "allow_guest_calculation": 1,
    "default_tax_year": DEFAULT_TAX_YEAR,
    # Advanced inputs remain hidden until every adjustment rule is separately
    # source-verified. This prevents a visible field from implying a tax effect
    # that the backend does not yet model.
    "show_advanced_mode": 0,
    "show_breakdown": 1,
    # Filer status affects many withholding/transaction rates, not the ordinary
    # annual progressive schedule. A generic annual filer-vs-non-filer comparison
    # would therefore be misleading.
    "show_filer_comparison": 0,
    "show_tax_health_score": 1,
    "allow_pdf_for_guest": 0,
    "save_logged_in_calculations": 1,
    "verified_badge_label": "FBR-source verified",
    "result_disclaimer": (
        "Estimate only, based on OMC's source-verified ordinary progressive "
        "individual tax schedules for the selected year. It is not a tax return, "
        "legal opinion or final assessment. Special/final regimes, exemptions, "
        "tax credits, super tax and transaction-specific withholding may require "
        "separate review."
    ),
    "filing_deadline_alert": "",
    "recommended_next_steps": json.dumps(
        [
            "Verify the selected tax year, income type and filer status.",
            "Keep source records and tax deduction evidence available for review.",
            "Use OMC support or a filing service when your case includes special regimes, credits or exemptions.",
        ]
    ),
    "required_documents_json": json.dumps(
        [
            "CNIC or identity record",
            "Income evidence for the selected year",
            "Relevant bank or transaction records",
            "Tax deduction or withholding certificates, if applicable",
        ]
    ),
    "guest_cta_title": "Create an account to save and review this estimate",
    "guest_cta_button": "Create Account",
    "customer_cta_title": "Need OMC to review or file this tax position?",
    "customer_cta_button": "Start Tax Filing Service",
}

NUMERIC_SETTINGS_FIELDS = {
    "calculator_enabled",
    "allow_guest_calculation",
    "show_advanced_mode",
    "show_breakdown",
    "show_filer_comparison",
    "show_tax_health_score",
    "allow_pdf_for_guest",
    "save_logged_in_calculations",
}


def _text(value: Any) -> str:
    return str(value or "").strip()


def _number(value: Any) -> float:
    try:
        return float(value or 0)
    except (TypeError, ValueError):
        return 0.0


def _same(fieldname: str, current: Any, desired: Any, numeric_fields: set[str]) -> bool:
    if fieldname in numeric_fields:
        return abs(_number(current) - _number(desired)) <= 0.000001
    return _text(current) == _text(desired)


def _changes(
    current: dict[str, Any],
    desired: dict[str, Any],
    fields: tuple[str, ...],
    numeric_fields: set[str],
) -> dict[str, dict[str, Any]]:
    result = {}
    for fieldname in fields:
        if _same(fieldname, current.get(fieldname), desired.get(fieldname), numeric_fields):
            continue
        result[fieldname] = {
            "current": current.get(fieldname),
            "desired": desired.get(fieldname),
        }
    return result


def _amount_label(from_amount: float, to_amount: float | None) -> str:
    if to_amount is None:
        return f"Above PKR {from_amount:,.0f}"
    if from_amount == 0:
        return f"Up to PKR {to_amount:,.0f}"
    return f"PKR {from_amount:,.0f} to PKR {to_amount:,.0f}"


def _desired_slabs(year) -> list[dict[str, Any]]:
    result = []
    groups = (
        ("Salary", year.salary_slabs, 100),
        ("Business", year.non_salaried_slabs, 200),
        ("Rental", year.non_salaried_slabs, 300),
    )
    for income_type, slabs, base_order in groups:
        for index, slab in enumerate(slabs, start=1):
            result.append(
                {
                    "income_type": income_type,
                    "filer_status": "Active Filer",
                    "taxpayer_type": "Individual",
                    "from_amount": slab.from_amount,
                    "to_amount": slab.to_amount,
                    "fixed_tax": slab.fixed_tax,
                    "rate_percent": slab.rate_percent,
                    "amount_over": slab.amount_over,
                    "sort_order": base_order + index,
                    "label": (
                        f"{income_type} · Base annual schedule · "
                        f"{_amount_label(slab.from_amount, slab.to_amount)}"
                    ),
                }
            )
    return result


def _desired_year(year) -> dict[str, Any]:
    return {
        "tax_year": year.tax_year,
        "app_defaults_managed": 1,
        "title": year.title,
        "country": "Pakistan",
        "currency": "PKR",
        "effective_from": year.effective_from,
        "effective_to": year.effective_to,
        "status": "Published",
        "is_active": 1,
        "section_4ab_threshold": year.surcharge_threshold,
        "salary_surcharge_percent": year.salary_surcharge_percent,
        "non_salaried_surcharge_percent": year.non_salaried_surcharge_percent,
        "source_reference": year.source_reference,
        "last_verified_on": VERIFIED_ON,
        "public_note": year.public_note,
        "slabs": _desired_slabs(year),
    }


def _desired_input(row) -> dict[str, Any]:
    return {
        "tax_year": "",
        "field_key": row.field_key,
        "app_defaults_managed": 1,
        "label": row.label,
        "input_type": row.input_type,
        "income_type": row.income_type,
        "mode": row.mode,
        "is_required": int(row.is_required),
        "is_active": 1,
        "default_value": row.default_value,
        "options_json": row.options_json,
        "help_text": row.help_text,
        "sort_order": row.sort_order,
    }


def _normalized_slabs(rows) -> list[dict[str, Any]]:
    normalized = []
    for row in rows or []:
        current = row.as_dict() if hasattr(row, "as_dict") else dict(row)
        item = {}
        for fieldname in SLAB_FIELDS:
            value = current.get(fieldname)
            item[fieldname] = _number(value) if fieldname in NUMERIC_SLAB_FIELDS else _text(value)
        normalized.append(item)
    return sorted(normalized, key=lambda item: (item["sort_order"], item["income_type"], item["from_amount"]))


def _slabs_match(current_rows, desired_rows: list[dict[str, Any]]) -> bool:
    return _normalized_slabs(current_rows) == _normalized_slabs(desired_rows)


def _schema_blockers() -> list[dict[str, Any]]:
    blockers = []
    for doctype in (YEAR_DOCTYPE, INPUT_DOCTYPE, SETTINGS_DOCTYPE):
        if not frappe.db.exists("DocType", doctype):
            blockers.append({"type": "missing_doctype", "doctype": doctype})

    if blockers:
        return blockers

    for doctype, fields in (
        (
            YEAR_DOCTYPE,
            (
                "app_defaults_managed",
                "section_4ab_threshold",
                "salary_surcharge_percent",
                "non_salaried_surcharge_percent",
            ),
        ),
        (INPUT_DOCTYPE, ("app_defaults_managed",)),
    ):
        meta = frappe.get_meta(doctype)
        for fieldname in fields:
            if not meta.has_field(fieldname):
                blockers.append(
                    {
                        "type": "schema_not_migrated",
                        "doctype": doctype,
                        "field": fieldname,
                    }
                )
    return blockers


def preview_tax_defaults() -> dict[str, Any]:
    conflicts = []
    blockers = []
    try:
        manifest = validate_tax_manifest()
    except Exception as exc:
        manifest = {"valid": False}
        blockers.append({"type": "invalid_manifest", "message": str(exc)})

    blockers.extend(_schema_blockers())
    if blockers:
        return _preview_result(
            manifest=manifest,
            conflicts=conflicts,
            blockers=blockers,
        )

    create_years = []
    update_years = []
    archive_years = []
    unchanged_years = []
    ignored_years = []

    desired_year_ids = {row.tax_year for row in TAX_YEARS}
    all_year_rows = frappe.get_all(
        YEAR_DOCTYPE,
        fields=["name", "tax_year", "app_defaults_managed", "status", "is_active"],
        limit_page_length=1000,
    )
    rows_by_id = {_text(row.tax_year): row for row in all_year_rows if _text(row.tax_year)}

    for spec in TAX_YEARS:
        desired = _desired_year(spec)
        current_row = rows_by_id.get(spec.tax_year)
        if not current_row:
            create_years.append({"tax_year": spec.tax_year, "desired": desired})
            continue

        if not int(_number(current_row.app_defaults_managed)):
            conflicts.append(
                {
                    "type": "managed_tax_year_owned_by_unmanaged_row",
                    "tax_year": spec.tax_year,
                    "name": current_row.name,
                }
            )
            continue

        doc = frappe.get_doc(YEAR_DOCTYPE, current_row.name)
        current = {fieldname: doc.get(fieldname) for fieldname in YEAR_FIELDS}
        changes = _changes(current, desired, YEAR_FIELDS, NUMERIC_YEAR_FIELDS)
        slabs_changed = not _slabs_match(doc.slabs, desired["slabs"])
        if changes or slabs_changed:
            update_years.append(
                {
                    "tax_year": spec.tax_year,
                    "name": doc.name,
                    "changes": changes,
                    "slabs_changed": slabs_changed,
                    "desired": desired,
                }
            )
        else:
            unchanged_years.append({"tax_year": spec.tax_year, "name": doc.name})

    for row in all_year_rows:
        tax_year = _text(row.tax_year)
        if tax_year in desired_year_ids:
            continue
        if not int(_number(row.app_defaults_managed)):
            ignored_years.append({"tax_year": tax_year, "name": row.name})
            continue
        if _text(row.status) != "Archived" or int(_number(row.is_active)):
            archive_years.append({"tax_year": tax_year, "name": row.name})

    create_inputs = []
    update_inputs = []
    deactivate_inputs = []
    unchanged_inputs = []
    ignored_inputs = []

    desired_input_keys = {row.field_key for row in TAX_INPUT_FIELDS}
    all_input_rows = frappe.get_all(
        INPUT_DOCTYPE,
        fields=["name", *INPUT_FIELDS],
        limit_page_length=1000,
    )
    inputs_by_key = {_text(row.field_key): row for row in all_input_rows if _text(row.field_key)}

    for spec in TAX_INPUT_FIELDS:
        desired = _desired_input(spec)
        current = inputs_by_key.get(spec.field_key)
        if not current:
            create_inputs.append({"field_key": spec.field_key, "desired": desired})
            continue
        if not int(_number(current.app_defaults_managed)):
            conflicts.append(
                {
                    "type": "managed_tax_input_owned_by_unmanaged_row",
                    "field_key": spec.field_key,
                    "name": current.name,
                }
            )
            continue
        current_dict = dict(current)
        changes = _changes(current_dict, desired, INPUT_FIELDS, NUMERIC_INPUT_FIELDS)
        if changes:
            update_inputs.append(
                {
                    "field_key": spec.field_key,
                    "name": current.name,
                    "changes": changes,
                    "desired": desired,
                }
            )
        else:
            unchanged_inputs.append({"field_key": spec.field_key, "name": current.name})

    for row in all_input_rows:
        key = _text(row.field_key)
        if key in desired_input_keys:
            continue
        if not int(_number(row.app_defaults_managed)):
            ignored_inputs.append({"field_key": key, "name": row.name})
            continue
        if int(_number(row.is_active)):
            deactivate_inputs.append({"field_key": key, "name": row.name})

    settings = frappe.get_single(SETTINGS_DOCTYPE)
    settings_changes = {}
    for fieldname, desired in SETTINGS_VALUES.items():
        if _same(
            fieldname,
            settings.get(fieldname),
            desired,
            NUMERIC_SETTINGS_FIELDS,
        ):
            continue
        settings_changes[fieldname] = {
            "current": settings.get(fieldname),
            "desired": desired,
        }

    create_count = len(create_years) + len(create_inputs)
    update_count = len(update_years) + len(update_inputs) + len(settings_changes)
    archive_count = len(archive_years)
    deactivate_count = len(deactivate_inputs)
    summary = {
        "create": create_count,
        "update": update_count,
        "archive": archive_count,
        "deactivate": deactivate_count,
        "unchanged": len(unchanged_years) + len(unchanged_inputs),
        "ignored_unmanaged": len(ignored_years) + len(ignored_inputs),
        "conflicts": len(conflicts),
        "blockers": len(blockers),
        "tax_years_create": len(create_years),
        "tax_years_update": len(update_years),
        "tax_years_archive": len(archive_years),
        "input_fields_create": len(create_inputs),
        "input_fields_update": len(update_inputs),
        "input_fields_deactivate": len(deactivate_inputs),
        "settings_fields_update": len(settings_changes),
    }
    safe_to_sync = not conflicts and not blockers
    converged = (
        safe_to_sync
        and not create_count
        and not update_count
        and not archive_count
        and not deactivate_count
    )
    return {
        "manifest": manifest,
        "create_years": create_years,
        "update_years": update_years,
        "archive_years": archive_years,
        "unchanged_years": unchanged_years,
        "ignored_years": ignored_years,
        "create_inputs": create_inputs,
        "update_inputs": update_inputs,
        "deactivate_inputs": deactivate_inputs,
        "unchanged_inputs": unchanged_inputs,
        "ignored_inputs": ignored_inputs,
        "settings_changes": settings_changes,
        "conflicts": conflicts,
        "blockers": blockers,
        "summary": summary,
        "safe_to_sync": safe_to_sync,
        "converged": converged,
    }


def _preview_result(*, manifest, conflicts, blockers) -> dict[str, Any]:
    return {
        "manifest": manifest,
        "create_years": [],
        "update_years": [],
        "archive_years": [],
        "unchanged_years": [],
        "ignored_years": [],
        "create_inputs": [],
        "update_inputs": [],
        "deactivate_inputs": [],
        "unchanged_inputs": [],
        "ignored_inputs": [],
        "settings_changes": {},
        "conflicts": conflicts,
        "blockers": blockers,
        "summary": {
            "create": 0,
            "update": 0,
            "archive": 0,
            "deactivate": 0,
            "unchanged": 0,
            "ignored_unmanaged": 0,
            "conflicts": len(conflicts),
            "blockers": len(blockers),
        },
        "safe_to_sync": False,
        "converged": False,
    }


def validate_tax_defaults() -> dict[str, Any]:
    preview = preview_tax_defaults()
    return {
        "valid": bool(preview.get("converged")),
        "safe_to_sync": bool(preview.get("safe_to_sync")),
        "manifest": preview.get("manifest", {}),
        "summary": preview.get("summary", {}),
        "conflicts": preview.get("conflicts", []),
        "blockers": preview.get("blockers", []),
    }


def _apply_year(doc, desired: dict[str, Any]) -> None:
    for fieldname in YEAR_FIELDS:
        doc.set(fieldname, desired[fieldname])
    doc.set("slabs", [])
    for row in desired["slabs"]:
        doc.append("slabs", row)


def sync_tax_defaults(*, commit: bool = True) -> dict[str, Any]:
    preview = preview_tax_defaults()
    if not preview.get("safe_to_sync"):
        frappe.throw(
            "Tax defaults synchronization is blocked: "
            + frappe.as_json(
                {
                    "conflicts": preview.get("conflicts", []),
                    "blockers": preview.get("blockers", []),
                }
            ),
            frappe.ValidationError,
        )

    created = 0
    updated = 0
    archived = 0
    deactivated = 0

    for item in preview["create_years"]:
        doc = frappe.get_doc({"doctype": YEAR_DOCTYPE})
        _apply_year(doc, item["desired"])
        doc.insert(ignore_permissions=True)
        created += 1

    for item in preview["update_years"]:
        doc = frappe.get_doc(YEAR_DOCTYPE, item["name"])
        _apply_year(doc, item["desired"])
        doc.save(ignore_permissions=True)
        updated += 1

    for item in preview["archive_years"]:
        doc = frappe.get_doc(YEAR_DOCTYPE, item["name"])
        doc.status = "Archived"
        doc.is_active = 0
        doc.save(ignore_permissions=True)
        archived += 1

    for item in preview["create_inputs"]:
        frappe.get_doc(
            {"doctype": INPUT_DOCTYPE, **item["desired"]}
        ).insert(ignore_permissions=True)
        created += 1

    for item in preview["update_inputs"]:
        doc = frappe.get_doc(INPUT_DOCTYPE, item["name"])
        for fieldname, value in item["desired"].items():
            doc.set(fieldname, value)
        doc.save(ignore_permissions=True)
        updated += 1

    for item in preview["deactivate_inputs"]:
        doc = frappe.get_doc(INPUT_DOCTYPE, item["name"])
        doc.is_active = 0
        doc.save(ignore_permissions=True)
        deactivated += 1

    settings = frappe.get_single(SETTINGS_DOCTYPE)
    for fieldname, change in preview["settings_changes"].items():
        settings.set(fieldname, change["desired"])
    if preview["settings_changes"]:
        settings.save(ignore_permissions=True)
        updated += len(preview["settings_changes"])

    validation = validate_tax_defaults()
    if not validation["valid"]:
        frappe.throw(
            "Tax defaults failed post-sync validation: "
            + frappe.as_json(validation),
            frappe.ValidationError,
        )

    if commit:
        frappe.db.commit()

    return {
        "created": created,
        "updated": updated,
        "archived": archived,
        "deactivated": deactivated,
        "validation": validation,
    }
