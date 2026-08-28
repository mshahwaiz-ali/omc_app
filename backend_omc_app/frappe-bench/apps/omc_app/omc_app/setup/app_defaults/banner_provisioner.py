from __future__ import annotations

from typing import Any

import frappe

from omc_app.setup.app_defaults.banners import BANNERS, validate_banner_manifest

DOCTYPE = "OMC App Banner"
MANAGED_FIELDS = ("banner_id", "app_defaults_managed", "title", "subtitle", "image", "action_label", "mobile_route", "starts_on", "ends_on", "sort_order", "status")
NUMERIC_FIELDS = {"app_defaults_managed", "sort_order"}
ADOPTABLE_BASELINES = {
    "omc-home-services": {"title": "Your business services, all in one place", "mobile_route": "/services", "status": "Published"},
    "omc-home-business-ready": {"title": "Stay ready for your next filing", "mobile_route": "/knowledge", "status": "Published"},
}


def _text(value: Any) -> str:
    return str(value or "").strip()


def _number(value: Any) -> float:
    try:
        return float(value or 0)
    except (TypeError, ValueError):
        return 0.0


def _same(fieldname: str, current: Any, desired: Any) -> bool:
    return _number(current) == _number(desired) if fieldname in NUMERIC_FIELDS else _text(current) == _text(desired)


def _desired(banner) -> dict[str, Any]:
    return {"banner_id": banner.banner_id, "app_defaults_managed": 1, "title": banner.title, "subtitle": banner.subtitle, "image": banner.image, "action_label": banner.action_label, "mobile_route": banner.mobile_route, "starts_on": banner.starts_on, "ends_on": banner.ends_on, "sort_order": int(banner.sort_order), "status": banner.status}


def _changes(current, desired):
    return {fieldname: {"current": current.get(fieldname), "desired": desired.get(fieldname)} for fieldname in MANAGED_FIELDS if not _same(fieldname, current.get(fieldname), desired.get(fieldname))}


def _can_adopt(banner_id, current):
    baseline = ADOPTABLE_BASELINES.get(banner_id)
    return bool(baseline) and all(_same(fieldname, current.get(fieldname), expected) for fieldname, expected in baseline.items())


def _empty_preview(manifest, blockers, conflicts):
    summary = {"create": 0, "adopt": 0, "update": 0, "archive": 0, "unchanged": 0, "ignored_unmanaged": 0, "ignored_archived_managed": 0, "conflicts": len(conflicts), "blockers": len(blockers)}
    return {"manifest": manifest, "create": [], "adopt": [], "update": [], "archive": [], "unchanged": [], "ignored_unmanaged": [], "ignored_archived_managed": [], "conflicts": conflicts, "blockers": blockers, "summary": summary, "safe_to_sync": False, "converged": False}


def preview_banners() -> dict[str, Any]:
    blockers, conflicts = [], []
    try:
        manifest = validate_banner_manifest()
    except Exception as exc:
        manifest = {"banners": len(BANNERS), "valid": False}
        blockers.append({"type": "invalid_manifest", "message": str(exc)})

    if not frappe.db.exists("DocType", DOCTYPE):
        blockers.append({"type": "missing_doctype", "doctype": DOCTYPE})
        return _empty_preview(manifest, blockers, conflicts)
    if not frappe.get_meta(DOCTYPE).has_field("app_defaults_managed"):
        blockers.append({"type": "missing_management_field", "fieldname": "app_defaults_managed"})

    rows = frappe.get_all(DOCTYPE, fields=["name", *MANAGED_FIELDS], limit_page_length=1000)
    by_id = {_text(row.banner_id): dict(row) for row in rows if _text(row.banner_id)}
    desired_by_id = {banner.banner_id: _desired(banner) for banner in BANNERS}
    create, adopt, update, archive, unchanged = [], [], [], [], []
    ignored_unmanaged, ignored_archived_managed = [], []

    for banner_id, desired in desired_by_id.items():
        current = by_id.get(banner_id)
        if not current:
            create.append({"banner_id": banner_id, "desired": desired})
            continue
        is_managed = bool(int(_number(current.get("app_defaults_managed"))))
        changes = _changes(current, desired)
        if not is_managed:
            if _can_adopt(banner_id, current):
                adopt.append({"banner_id": banner_id, "name": current["name"], "changes": changes, "desired": desired})
            else:
                conflicts.append({"type": "managed_banner_id_owned_by_unmanaged_row", "banner_id": banner_id, "name": current.get("name")})
            continue
        if changes:
            update.append({"banner_id": banner_id, "name": current["name"], "changes": changes, "desired": desired})
        else:
            unchanged.append({"banner_id": banner_id, "name": current["name"]})

    desired_ids = set(desired_by_id)
    for row in rows:
        banner_id = _text(row.banner_id)
        if banner_id in desired_ids:
            continue
        if not bool(int(_number(row.app_defaults_managed))):
            ignored_unmanaged.append({"banner_id": banner_id, "name": row.name, "status": row.status or ""})
        elif _text(row.status) != "Archived":
            archive.append({"banner_id": banner_id, "name": row.name, "current_status": row.status or ""})
        else:
            ignored_archived_managed.append({"banner_id": banner_id, "name": row.name})

    summary = {"create": len(create), "adopt": len(adopt), "update": len(update), "archive": len(archive), "unchanged": len(unchanged), "ignored_unmanaged": len(ignored_unmanaged), "ignored_archived_managed": len(ignored_archived_managed), "conflicts": len(conflicts), "blockers": len(blockers)}
    safe_to_sync = not conflicts and not blockers
    converged = safe_to_sync and not create and not adopt and not update and not archive
    return {"manifest": manifest, "create": create, "adopt": adopt, "update": update, "archive": archive, "unchanged": unchanged, "ignored_unmanaged": ignored_unmanaged, "ignored_archived_managed": ignored_archived_managed, "conflicts": conflicts, "blockers": blockers, "summary": summary, "safe_to_sync": safe_to_sync, "converged": converged}


def validate_banners() -> dict[str, Any]:
    preview = preview_banners()
    return {"valid": bool(preview.get("converged")), "safe_to_sync": bool(preview.get("safe_to_sync")), "manifest": preview.get("manifest", {}), "summary": preview.get("summary", {}), "conflicts": preview.get("conflicts", []), "blockers": preview.get("blockers", [])}


def sync_banners(*, commit: bool = True) -> dict[str, Any]:
    preview = preview_banners()
    if not preview.get("safe_to_sync"):
        frappe.throw("App Banner synchronization is blocked: " + frappe.as_json({"conflicts": preview.get("conflicts", []), "blockers": preview.get("blockers", [])}), frappe.ValidationError)

    created = adopted = updated = archived = 0
    for item in preview["create"]:
        frappe.get_doc({"doctype": DOCTYPE, **item["desired"]}).insert(ignore_permissions=True)
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

    validation = validate_banners()
    if not validation["valid"]:
        frappe.throw("App Banners failed post-sync validation: " + frappe.as_json(validation), frappe.ValidationError)
    if commit:
        frappe.db.commit()
    return {"created": created, "adopted": adopted, "updated": updated, "archived": archived, "validation": validation}
