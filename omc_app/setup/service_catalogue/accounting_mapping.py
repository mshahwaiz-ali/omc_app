from __future__ import annotations

from typing import Any

import frappe

from omc_app.setup.service_catalogue.manifest import SERVICES


# Preferred ERPNext Sales Items for the currently published OMC services.
# These are references to client-owned ERP masters. OMC never creates or
# mutates Item records here. Existing valid service-level overrides are kept.
ERP_INVOICE_ITEM_BY_SERVICE_ID = {
    "aop-firm-registration-service": "AOP Firm Registration Service",
    "business-tax-filing": "Business Tax Filing",
    "family-contribute": "Family Contribution Tax Filing",
    "fbr-pos-challan": "FBR POS Challan",
    "gst-registration": "GST Registration",
    "house-wife-filing": "House Wife Filing",
    "nrp-tax-return-filing": "NRP Tax Return Filing",
    "ntn-modification": "NTN Modification",
    "ntn-registration": "NTN Registration",
    "other-services": "Other Services",
    "other-sources": "Other Sources",
    "p-s-w-registration-service": "PSW Registration",
    "password-reset": "Password Reset",
    "pensioner-filing": "Pensioner Filing",
    "pvt-registration-services": "PVT Registration Services",
    "salaried-tax-filing": "Salaried Tax Filing",
    "srb-registration": "SRB Registration",
}


def _text(value: Any) -> str:
    return str(value or "").strip()


def _row_value(row: Any, key: str, default=None):
    if row is None:
        return default
    if isinstance(row, dict):
        return row.get(key, default)
    return getattr(row, key, default)


def assess_invoice_item(item_name: str) -> dict[str, Any]:
    """Read-only safety classification for an ERP invoice Item."""
    name = _text(item_name)
    result = {
        "item": name,
        "valid": False,
        "reason": "",
    }
    if not name:
        result["reason"] = "missing_mapping"
        return result

    if not frappe.db.exists("Item", name):
        result["reason"] = "item_not_found"
        return result

    item = frappe.db.get_value(
        "Item",
        name,
        ["disabled", "is_sales_item", "is_stock_item"],
        as_dict=True,
    )
    if not item:
        result["reason"] = "item_not_found"
        return result
    if int(_row_value(item, "disabled", 0) or 0):
        result["reason"] = "item_disabled"
        return result
    if not int(_row_value(item, "is_sales_item", 0) or 0):
        result["reason"] = "not_sales_item"
        return result
    if int(_row_value(item, "is_stock_item", 0) or 0):
        result["reason"] = "stock_item_not_allowed"
        return result

    result["valid"] = True
    result["reason"] = "valid_non_stock_sales_item"
    return result


def assert_valid_invoice_item(item_name: str) -> None:
    assessment = assess_invoice_item(item_name)
    if assessment["valid"]:
        return

    reason = assessment["reason"]
    messages = {
        "item_not_found": "ERP Invoice Item does not exist.",
        "item_disabled": "ERP Invoice Item must be enabled.",
        "not_sales_item": "ERP Invoice Item must be a sales item.",
        "stock_item_not_allowed": "ERP Invoice Item must be a non-stock sales item.",
        "missing_mapping": "ERP Invoice Item is required.",
    }
    frappe.throw(
        messages.get(reason, "ERP Invoice Item is not valid for OMC service accounting."),
        frappe.ValidationError,
    )


def _managed_service_rows() -> dict[str, dict[str, Any]]:
    service_ids = [spec.service_id for spec in SERVICES]
    rows = frappe.get_all(
        "OMC Service",
        filters={"service_id": ["in", service_ids]},
        fields=["name", "service_id", "title", "is_active", "erp_invoice_item"],
        limit_page_length=1000,
    )
    return {
        _text(_row_value(row, "service_id")): dict(row)
        for row in rows
        if _text(_row_value(row, "service_id"))
    }


def _active_specs():
    return [spec for spec in SERVICES if bool(spec.is_active)]


def preview_service_accounting_mappings() -> dict[str, Any]:
    """Preview safe auto-mapping without changing OMC or ERP records."""
    rows = _managed_service_rows()
    configured: list[dict[str, Any]] = []
    auto_map_ready: list[dict[str, Any]] = []
    unresolved: list[dict[str, Any]] = []
    invalid: list[dict[str, Any]] = []

    for spec in _active_specs():
        row = rows.get(spec.service_id)
        current = _text(_row_value(row, "erp_invoice_item")) if row else ""
        preferred = _text(ERP_INVOICE_ITEM_BY_SERVICE_ID.get(spec.service_id))

        if current:
            assessment = assess_invoice_item(current)
            entry = {
                "service_id": spec.service_id,
                "service": _row_value(row, "name", spec.service_id),
                "item": current,
                "source": "existing_service_mapping",
                "reason": assessment["reason"],
            }
            (configured if assessment["valid"] else invalid).append(entry)
            continue

        if not preferred:
            unresolved.append(
                {
                    "service_id": spec.service_id,
                    "service": _row_value(row, "name", spec.service_id),
                    "reason": "no_preferred_mapping",
                }
            )
            continue

        assessment = assess_invoice_item(preferred)
        entry = {
            "service_id": spec.service_id,
            "service": _row_value(row, "name", spec.service_id),
            "item": preferred,
            "source": "source_controlled_preference",
            "reason": assessment["reason"],
        }
        if assessment["valid"]:
            auto_map_ready.append(entry)
        else:
            invalid.append(entry)

    return {
        "ok": True,
        "read_only": True,
        "operation": "preview_service_accounting_mappings",
        "valid": not unresolved and not invalid and not auto_map_ready,
        "configured": configured,
        "auto_map_ready": auto_map_ready,
        "unresolved": unresolved,
        "invalid": invalid,
        "summary": {
            "active_services": len(_active_specs()),
            "configured": len(configured),
            "auto_map_ready": len(auto_map_ready),
            "unresolved": len(unresolved),
            "invalid": len(invalid),
        },
        "ownership": {
            "creates_erp_items": False,
            "updates_erp_items": False,
            "overwrites_existing_service_mapping": False,
        },
    }


def validate_service_accounting_mappings() -> dict[str, Any]:
    preview = preview_service_accounting_mappings()
    valid = (
        not preview["auto_map_ready"]
        and not preview["unresolved"]
        and not preview["invalid"]
    )
    return {
        **preview,
        "operation": "validate_service_accounting_mappings",
        "valid": valid,
    }


def sync_service_accounting_mappings(*, commit: bool = True) -> dict[str, Any]:
    """Fill only blank OMC invoice-item links when the preferred Item is safe.

    ERP Item masters remain client-owned. Missing, stock, disabled or non-sales
    Items are reported and never created, changed or guessed by this operation.
    """
    rows = _managed_service_rows()
    updated: list[dict[str, str]] = []
    preserved: list[dict[str, str]] = []
    skipped: list[dict[str, str]] = []

    for spec in _active_specs():
        row = rows.get(spec.service_id)
        if not row:
            skipped.append({"service_id": spec.service_id, "reason": "service_not_found"})
            continue

        current = _text(_row_value(row, "erp_invoice_item"))
        if current:
            preserved.append({"service_id": spec.service_id, "item": current})
            continue

        preferred = _text(ERP_INVOICE_ITEM_BY_SERVICE_ID.get(spec.service_id))
        assessment = assess_invoice_item(preferred)
        if not assessment["valid"]:
            skipped.append(
                {
                    "service_id": spec.service_id,
                    "item": preferred,
                    "reason": assessment["reason"],
                }
            )
            continue

        frappe.db.set_value(
            "OMC Service",
            row["name"],
            "erp_invoice_item",
            preferred,
            update_modified=False,
        )
        updated.append({"service_id": spec.service_id, "item": preferred})

    if commit:
        frappe.db.commit()

    validation = validate_service_accounting_mappings()
    return {
        "ok": True,
        "operation": "sync_service_accounting_mappings",
        "committed": bool(commit),
        "updated": updated,
        "preserved": preserved,
        "skipped": skipped,
        "validation": validation,
        "ownership": {
            "creates_erp_items": False,
            "updates_erp_items": False,
            "overwrites_existing_service_mapping": False,
        },
    }
