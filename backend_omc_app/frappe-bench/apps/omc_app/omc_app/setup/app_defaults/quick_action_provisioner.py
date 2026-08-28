from __future__ import annotations

from typing import Any

import frappe

from omc_app.setup.app_defaults.quick_actions import QUICK_ACTIONS, validate_quick_action_manifest

DOCTYPE = "OMC Mobile Quick Action"
MANAGED_FIELDS = ("enabled", "app_defaults_key", "app_defaults_managed", "title", "subtitle", "icon_key", "sort_order", "target_type", "target_value", "service", "access_level", "required_capability", "badge_type", "style", "placement", "layout_size", "is_featured", "starts_on", "ends_on", "group", "description_long", "description")
NUMERIC_FIELDS = {"enabled", "app_defaults_managed", "sort_order", "is_featured"}


def _text(value: Any) -> str:
    return str(value or "").strip()


def _number(value: Any) -> float:
    try:
        return float(value or 0)
    except (TypeError, ValueError):
        return 0.0


def _same(fieldname: str, current: Any, desired: Any) -> bool:
    return _number(current) == _number(desired) if fieldname in NUMERIC_FIELDS else _text(current) == _text(desired)


def _desired(action) -> dict[str, Any]:
    return {"enabled": 1, "app_defaults_key": action.key, "app_defaults_managed": 1, "title": action.title, "subtitle": action.subtitle, "icon_key": action.icon_key, "sort_order": int(action.sort_order), "target_type": action.target_type, "target_value": action.target_value, "service": "", "access_level": action.access_level, "required_capability": action.required_capability, "badge_type": action.badge_type, "style": action.style, "placement": action.placement, "layout_size": action.layout_size, "is_featured": int(action.is_featured), "starts_on": "", "ends_on": "", "group": action.group, "description_long": action.description_long, "description": "Source-controlled OMC app-ready default."}


def _changes(current: dict[str, Any], desired: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {fieldname: {"current": current.get(fieldname), "desired": desired.get(fieldname)} for fieldname in MANAGED_FIELDS if not _same(fieldname, current.get(fieldname), desired.get(fieldname))}


def _empty_preview(manifest, blockers, conflicts):
    summary = {"create": 0, "update": 0, "deactivate": 0, "unchanged": 0, "ignored_unmanaged": 0, "ignored_inactive_managed": 0, "conflicts": len(conflicts), "blockers": len(blockers)}
    return {"manifest": manifest, "create": [], "update": [], "deactivate": [], "unchanged": [], "ignored_unmanaged": [], "ignored_inactive_managed": [], "conflicts": conflicts, "blockers": blockers, "summary": summary, "safe_to_sync": False, "converged": False}


def preview_quick_actions() -> dict[str, Any]:
    blockers, conflicts = [], []
    try:
        manifest = validate_quick_action_manifest()
    except Exception as exc:
        manifest = {"actions": len(QUICK_ACTIONS), "valid": False}
        blockers.append({"type": "invalid_manifest", "message": str(exc)})

    if not frappe.db.exists("DocType", DOCTYPE):
        blockers.append({"type": "missing_doctype", "doctype": DOCTYPE})
        return _empty_preview(manifest, blockers, conflicts)

    meta = frappe.get_meta(DOCTYPE)
    for fieldname in ("app_defaults_key", "app_defaults_managed"):
        if not meta.has_field(fieldname):
            blockers.append({"type": "missing_management_field", "fieldname": fieldname})

    rows = frappe.get_all(DOCTYPE, fields=["name", *MANAGED_FIELDS], limit_page_length=1000)
    by_key = {}
    for row in rows:
        key = _text(row.app_defaults_key)
        if key:
            by_key.setdefault(key, []).append(dict(row))

    desired_by_key = {action.key: _desired(action) for action in QUICK_ACTIONS}
    create, update, deactivate, unchanged = [], [], [], []
    ignored_unmanaged, ignored_inactive_managed = [], []

    for key, desired in desired_by_key.items():
        matches = by_key.get(key, [])
        if len(matches) > 1:
            conflicts.append({"type": "duplicate_app_defaults_key", "key": key, "rows": [row.get("name") for row in matches]})
            continue
        if not matches:
            create.append({"key": key, "desired": desired})
            continue
        current = matches[0]
        if not int(_number(current.get("app_defaults_managed"))):
            conflicts.append({"type": "managed_key_owned_by_unmanaged_row", "key": key, "name": current.get("name")})
            continue
        changes = _changes(current, desired)
        if changes:
            update.append({"key": key, "name": current["name"], "changes": changes, "desired": desired})
        else:
            unchanged.append({"key": key, "name": current["name"]})

    desired_keys = set(desired_by_key)
    for row in rows:
        key = _text(row.app_defaults_key)
        if key in desired_keys:
            continue
        is_managed = bool(int(_number(row.app_defaults_managed)))
        if not is_managed:
            ignored_unmanaged.append({"key": key, "name": row.name, "title": row.title or "", "enabled": int(row.enabled or 0)})
        elif int(row.enabled or 0):
            deactivate.append({"key": key, "name": row.name, "title": row.title or ""})
        else:
            ignored_inactive_managed.append({"key": key, "name": row.name})

    summary = {"create": len(create), "update": len(update), "deactivate": len(deactivate), "unchanged": len(unchanged), "ignored_unmanaged": len(ignored_unmanaged), "ignored_inactive_managed": len(ignored_inactive_managed), "conflicts": len(conflicts), "blockers": len(blockers)}
    safe_to_sync = not conflicts and not blockers
    converged = safe_to_sync and not create and not update and not deactivate
    return {"manifest": manifest, "create": create, "update": update, "deactivate": deactivate, "unchanged": unchanged, "ignored_unmanaged": ignored_unmanaged, "ignored_inactive_managed": ignored_inactive_managed, "conflicts": conflicts, "blockers": blockers, "summary": summary, "safe_to_sync": safe_to_sync, "converged": converged}


def validate_quick_actions() -> dict[str, Any]:
    preview = preview_quick_actions()
    return {"valid": bool(preview.get("converged")), "safe_to_sync": bool(preview.get("safe_to_sync")), "manifest": preview.get("manifest", {}), "summary": preview.get("summary", {}), "conflicts": preview.get("conflicts", []), "blockers": preview.get("blockers", [])}


def sync_quick_actions(*, commit: bool = True) -> dict[str, Any]:
    preview = preview_quick_actions()
    if not preview.get("safe_to_sync"):
        frappe.throw("Mobile Quick Action synchronization is blocked: " + frappe.as_json({"conflicts": preview.get("conflicts", []), "blockers": preview.get("blockers", [])}), frappe.ValidationError)

    created = updated = deactivated = 0
    for item in preview["create"]:
        frappe.get_doc({"doctype": DOCTYPE, **item["desired"]}).insert(ignore_permissions=True)
        created += 1
    for item in preview["update"]:
        doc = frappe.get_doc(DOCTYPE, item["name"])
        for fieldname, value in item["desired"].items():
            doc.set(fieldname, value)
        doc.save(ignore_permissions=True)
        updated += 1
    for item in preview["deactivate"]:
        doc = frappe.get_doc(DOCTYPE, item["name"])
        doc.enabled = 0
        doc.save(ignore_permissions=True)
        deactivated += 1

    validation = validate_quick_actions()
    if not validation["valid"]:
        frappe.throw("Mobile Quick Actions failed post-sync validation: " + frappe.as_json(validation), frappe.ValidationError)
    if commit:
        frappe.db.commit()
    return {"created": created, "updated": updated, "deactivated": deactivated, "validation": validation}
