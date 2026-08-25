from __future__ import annotations

import frappe

from omc_app.branding import _apply_branding
from omc_app.setup.desk_metadata import sync_desk_metadata
from omc_app.setup.erp_contract import validate_client_erp_contract
from omc_app.setup.referral_workspace import ensure_referral_workspace_links
from omc_app.setup.roles import sync_canonical_roles


def _text(value) -> str:
    return str(value or "").strip()


def _commit_if_requested(commit: bool) -> None:
    if commit:
        frappe.db.commit()


def validate_site() -> dict[str, object]:
    """Read-only compatibility validation safe to run during migrate."""
    return validate_client_erp_contract()


def inspect_erp_customer_defaults() -> dict[str, object]:
    """Read-only Selling Settings readiness for automatic ERP Customer creation.

    The configuration script uses this operation to preserve existing client
    defaults and, when either value is missing, offer only names that already
    exist in the client's ERP database. Nothing is created or guessed here.
    """
    customer_group = _text(
        frappe.db.get_single_value("Selling Settings", "customer_group")
    )
    territory = _text(
        frappe.db.get_single_value("Selling Settings", "territory")
    )

    customer_group_options = frappe.get_all(
        "Customer Group",
        pluck="name",
        order_by="name asc",
        limit_page_length=0,
    )
    territory_options = frappe.get_all(
        "Territory",
        pluck="name",
        order_by="name asc",
        limit_page_length=0,
    )

    return {
        "ok": bool(customer_group and territory),
        "operation": "inspect_erp_customer_defaults",
        "customer_group": customer_group,
        "territory": territory,
        "customer_group_options": customer_group_options,
        "territory_options": territory_options,
    }


def configure_erp_customer_defaults(
    customer_group=None,
    territory=None,
    *,
    commit: bool = True,
) -> dict[str, object]:
    """Set explicit existing ERP defaults required for Customer creation.

    Existing values are preserved unless an explicit replacement is supplied.
    Both final values must already exist in ERPNext; this operation never
    creates Customer Group or Territory records and never guesses names.
    """
    current = inspect_erp_customer_defaults()

    target_customer_group = _text(customer_group) or _text(
        current.get("customer_group")
    )
    target_territory = _text(territory) or _text(current.get("territory"))

    if not target_customer_group:
        frappe.throw(
            "Selling Settings.customer_group is required for automatic ERP Customer creation.",
            frappe.ValidationError,
        )
    if not target_territory:
        frappe.throw(
            "Selling Settings.territory is required for automatic ERP Customer creation.",
            frappe.ValidationError,
        )

    if not frappe.db.exists("Customer Group", target_customer_group):
        frappe.throw(
            f"Customer Group does not exist: {target_customer_group}",
            frappe.ValidationError,
        )
    if not frappe.db.exists("Territory", target_territory):
        frappe.throw(
            f"Territory does not exist: {target_territory}",
            frappe.ValidationError,
        )

    settings = frappe.get_single("Selling Settings")
    changed = False

    if _text(settings.customer_group) != target_customer_group:
        settings.customer_group = target_customer_group
        changed = True

    if _text(settings.territory) != target_territory:
        settings.territory = target_territory
        changed = True

    if changed:
        settings.save(ignore_permissions=True)

    _commit_if_requested(commit)

    return {
        "ok": True,
        "operation": "configure_erp_customer_defaults",
        "changed": changed,
        "customer_group": target_customer_group,
        "territory": target_territory,
    }


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
    """Read-only preview of source-controlled OMC catalogue reconciliation."""
    from omc_app.setup.service_catalogue.provisioner import (
        preview_service_catalogue as preview,
    )

    return preview()


def validate_service_catalogue() -> dict[str, object]:
    """Read-only exact-state validation of the source-controlled catalogue."""
    from omc_app.setup.service_catalogue.provisioner import (
        validate_service_catalogue as validate,
    )

    return validate()


def sync_service_catalogue(*, commit: bool = True) -> dict[str, object]:
    """Explicit atomic reconciliation of the source-controlled catalogue."""
    from omc_app.setup.service_catalogue.provisioner import (
        sync_service_catalogue as sync,
    )

    return sync(commit=commit)


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
