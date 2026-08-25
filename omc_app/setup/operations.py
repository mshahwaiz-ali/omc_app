from __future__ import annotations

import frappe

from omc_app.branding import _apply_branding
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
    result = _apply_branding()
    _commit_if_requested(commit)
    return {"operation": "apply_site_branding", **result}


def seed_tax_calculator_defaults(*, commit: bool = True) -> dict[str, object]:
    """Deliberately install the optional tax-calculator UI defaults."""
    from omc_app.patches import seed_tax_calculator_defaults as seed_patch

    seed_patch.execute()
    _commit_if_requested(commit)
    return {"ok": True, "operation": "seed_tax_calculator_defaults"}


def seed_business_rental_tax_slabs() -> dict[str, object]:
    """Deliberately install the optional Business/Rental tax schedules."""
    from omc_app.patches import seed_business_rental_tax_slabs as seed_patch

    # The retained historical seed performs and verifies its own commit.
    seed_patch.execute()
    return {"ok": True, "operation": "seed_business_rental_tax_slabs"}


def sync_service_task_type_mappings(*, commit: bool = True) -> dict[str, object]:
    """Deliberately map OMC Services to ERP Task Types that already exist."""
    from omc_app.patches import seed_erp_task_types_and_service_mappings as seed_patch

    seed_patch.execute()
    _commit_if_requested(commit)
    return {"ok": True, "operation": "sync_service_task_type_mappings"}


def preview_service_catalogue() -> dict[str, object]:
    """Read-only preview of the complete source-controlled OMC catalogue.

    Customer-facing copy and the Employee assignment default are sourced from
    the same catalogue manifest and are surfaced here so operators see those
    intended changes before any synchronization occurs.
    """
    from omc_app.setup.service_catalogue.presentation import (
        preview_service_presentation,
    )
    from omc_app.setup.service_catalogue.provisioner import (
        preview_service_catalogue as preview,
    )

    result = preview()
    return {
        **result,
        "presentation": preview_service_presentation(),
    }


def validate_service_catalogue() -> dict[str, object]:
    """Read-only exact-state validation of catalogue rows and service copy."""
    from omc_app.setup.service_catalogue.presentation import (
        validate_service_presentation,
    )
    from omc_app.setup.service_catalogue.provisioner import (
        validate_service_catalogue as validate,
    )

    result = validate()
    presentation = validate_service_presentation()
    return {
        **result,
        "valid": bool(result.get("valid") and presentation.get("valid")),
        "presentation": presentation,
    }


def sync_service_catalogue(*, commit: bool = True) -> dict[str, object]:
    """Atomically sync catalogue rows, customer copy and Employee defaults.

    All managed customer-facing presentation values originate in the catalogue
    manifest. The compatibility presentation reconciler runs inside the same
    transaction as the established catalogue provisioner so deployments cannot
    leave newly-created services partially configured.
    """
    from omc_app.setup.service_catalogue.presentation import (
        sync_service_presentation,
    )
    from omc_app.setup.service_catalogue.provisioner import (
        sync_service_catalogue as sync,
    )

    savepoint = "omc_catalogue_and_presentation_sync"
    frappe.db.savepoint(savepoint)
    try:
        result = sync(commit=False)
        presentation = sync_service_presentation(commit=False)
        if commit:
            frappe.db.commit()
        return {
            **result,
            "committed": bool(commit),
            "presentation": presentation,
        }
    except Exception:
        frappe.db.rollback(save_point=savepoint)
        raise


def initialize_site(*, commit: bool = True) -> dict[str, object]:
    """Explicit, idempotent OMC site initialization/repair entrypoint.

    This function intentionally performs site-facing setup and therefore is
    never called by the normal migrate/sync lifecycle. Optional business data
    seeds remain separate operations and are not installed implicitly.

        bench --site <site> execute omc_app.setup.operations.initialize_site
    """
    contract = validate_site()
    sync_canonical_roles()
    sync_desk_metadata()
    ensure_referral_workspace_links()
    branding = _apply_branding()
    _commit_if_requested(commit)
    return {
        "ok": True,
        "operation": "initialize_site",
        "erp_contract": contract,
        "permissions": "synchronized",
        "desk_metadata": "synchronized",
        "branding": branding,
    }
