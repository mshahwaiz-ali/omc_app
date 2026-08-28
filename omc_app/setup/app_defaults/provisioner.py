from __future__ import annotations

from collections.abc import Callable
from typing import Any

import frappe

from omc_app.setup.app_defaults.banner_provisioner import preview_banners, sync_banners, validate_banners
from omc_app.setup.app_defaults.expense_categories import preview_expense_categories, sync_expense_categories, validate_expense_categories
from omc_app.setup.app_defaults.faq_provisioner import preview_faqs, sync_faqs, validate_faqs
from omc_app.setup.app_defaults.knowledge_provisioner import preview_knowledge_articles, sync_knowledge_articles, validate_knowledge_articles
from omc_app.setup.app_defaults.mobile_settings import preview_mobile_settings, sync_mobile_settings, validate_mobile_settings
from omc_app.setup.app_defaults.onboarding_provisioner import preview_onboarding_slides, sync_onboarding_slides, validate_onboarding_slides
from omc_app.setup.app_defaults.quick_action_provisioner import preview_quick_actions, sync_quick_actions, validate_quick_actions
from omc_app.setup.app_defaults.stage_provisioner import preview_stage_defaults, sync_stage_defaults, validate_stage_defaults
from omc_app.setup.app_defaults.tax_provisioner import preview_tax_defaults, sync_tax_defaults, validate_tax_defaults

PreviewFn = Callable[[], dict[str, Any]]
ValidateFn = Callable[[], dict[str, Any]]
SyncFn = Callable[..., dict[str, Any]]

COMPONENTS: tuple[tuple[str, PreviewFn, SyncFn, ValidateFn], ...] = (
    ("stage_templates", preview_stage_defaults, sync_stage_defaults, validate_stage_defaults),
    ("mobile_settings", preview_mobile_settings, sync_mobile_settings, validate_mobile_settings),
    ("expense_categories", preview_expense_categories, sync_expense_categories, validate_expense_categories),
    ("onboarding_slides", preview_onboarding_slides, sync_onboarding_slides, validate_onboarding_slides),
    ("faqs", preview_faqs, sync_faqs, validate_faqs),
    ("knowledge_articles", preview_knowledge_articles, sync_knowledge_articles, validate_knowledge_articles),
    ("quick_actions", preview_quick_actions, sync_quick_actions, validate_quick_actions),
    ("banners", preview_banners, sync_banners, validate_banners),
    ("tax_defaults", preview_tax_defaults, sync_tax_defaults, validate_tax_defaults),
)

MUTATION_KEYS = ("create", "adopt", "update", "deactivate", "archive")


def _component_preview(report: dict[str, Any]) -> dict[str, Any]:
    summary = dict(report.get("summary") or {})
    if not summary and isinstance(report.get("changes"), dict):
        summary = {"update": len(report.get("changes") or {}), "blockers": len(report.get("blockers") or [])}
    mutations = sum(int(summary.get(key) or 0) for key in MUTATION_KEYS)
    return {
        "safe_to_sync": bool(report.get("safe_to_sync")),
        "converged": bool(report.get("converged")),
        "pending_mutations": mutations,
        "summary": summary,
        "manifest": report.get("manifest", {}),
        "conflicts": report.get("conflicts", []),
        "blockers": report.get("blockers", []),
    }


def preview_app_defaults() -> dict[str, Any]:
    components = {}
    total_mutations = 0
    safe_to_sync = True
    converged = True
    for name, preview, _sync, _validate in COMPONENTS:
        report = _component_preview(preview())
        components[name] = report
        total_mutations += int(report["pending_mutations"])
        safe_to_sync = safe_to_sync and bool(report["safe_to_sync"])
        converged = converged and bool(report["converged"])
    return {
        "components": components,
        "summary": {
            "components": len(COMPONENTS),
            "pending_mutations": total_mutations,
            "unsafe_components": sum(1 for report in components.values() if not report["safe_to_sync"]),
            "non_converged_components": sum(1 for report in components.values() if not report["converged"]),
        },
        "safe_to_sync": safe_to_sync,
        "converged": safe_to_sync and converged,
    }


def validate_app_defaults() -> dict[str, Any]:
    components = {}
    valid = True
    for name, _preview, _sync, validate in COMPONENTS:
        report = validate()
        components[name] = report
        valid = valid and bool(report.get("valid"))
    return {
        "valid": valid,
        "components": components,
        "summary": {"components": len(COMPONENTS), "invalid_components": sum(1 for report in components.values() if not report.get("valid"))},
    }


def sync_app_defaults(*, commit: bool = True) -> dict[str, Any]:
    preview = preview_app_defaults()
    if not preview.get("safe_to_sync"):
        frappe.throw("App-ready defaults synchronization is blocked: " + frappe.as_json(preview), frappe.ValidationError)

    savepoint = "omc_app_ready_defaults_sync"
    frappe.db.savepoint(savepoint)
    try:
        results = {}
        for name, _preview, sync, _validate in COMPONENTS:
            results[name] = sync(commit=False)
        validation = validate_app_defaults()
        if not validation.get("valid"):
            frappe.throw("App-ready defaults failed post-sync validation: " + frappe.as_json(validation), frappe.ValidationError)
        if commit:
            frappe.db.commit()
        return {"ok": True, "committed": bool(commit), "results": results, "validation": validation}
    except Exception:
        frappe.db.rollback(save_point=savepoint)
        raise
