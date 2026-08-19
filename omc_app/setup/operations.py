from __future__ import annotations

import frappe

from omc_app.branding import apply_branding
from omc_app.setup.desk_metadata import sync_desk_metadata
from omc_app.setup.erp_contract import validate_client_erp_contract
from omc_app.setup.referral_workspace import ensure_referral_workspace_links
from omc_app.setup.roles import sync_canonical_roles


def _commit_if_requested(commit: bool) -> None:
    if commit:
        frappe.db.commit()


def validate_site() -> dict[str, object]:
    """Read-only compatibility validation safe to run during migrate."""
    return validate_client_erp_contract()


def repair_permissions(*, commit: bool = True) -> dict[str, object]:
    """Deliberately rebuild the OMC-owned role/DocPerm model.

    CLI example:
        bench --site <site> execute omc_app.setup.operations.repair_permissions
    """
    sync_canonical_roles()
    _commit_if_requested(commit)
    return {"ok": True, "operation": "repair_permissions"}


def sync_desk_configuration(*, commit: bool = True) -> dict[str, object]:
    """Deliberately reconcile OMC Desk/workspace metadata from source control."""
    sync_desk_metadata()
    ensure_referral_workspace_links()
    _commit_if_requested(commit)
    return {"ok": True, "operation": "sync_desk_configuration"}


def apply_site_branding(*, commit: bool = True) -> dict[str, object]:
    """Deliberately apply OMC branding to Frappe Website Settings."""
    result = apply_branding(_trusted_internal_call=True)
    _commit_if_requested(commit)
    return {"ok": bool(result.get("ok")), "operation": "apply_site_branding", **result}


def initialize_site(*, commit: bool = True) -> dict[str, object]:
    """Explicit, idempotent OMC site initialization/repair entrypoint.

    This function intentionally performs business-facing setup and therefore is
    never called by the normal migrate/sync lifecycle. It may be invoked after
    a fresh install or deliberately by an operator:

        bench --site <site> execute omc_app.setup.operations.initialize_site
    """
    contract = validate_site()
    sync_canonical_roles()
    sync_desk_metadata()
    ensure_referral_workspace_links()
    branding = apply_branding(_trusted_internal_call=True)
    _commit_if_requested(commit)
    return {
        "ok": True,
        "operation": "initialize_site",
        "erp_contract": contract,
        "permissions": "synchronized",
        "desk_metadata": "synchronized",
        "branding": branding,
    }
