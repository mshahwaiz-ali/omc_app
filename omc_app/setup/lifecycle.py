from omc_app.branding import apply_branding
from omc_app.setup.desk_metadata import sync_desk_metadata
from omc_app.setup.erp_contract import validate_client_erp_contract
from omc_app.setup.roles import sync_canonical_roles
from omc_app.setup.referral_workspace import ensure_referral_workspace_links


def before_install():
    validate_client_erp_contract()


def after_install():
    sync_canonical_roles()
    sync_desk_metadata()
    ensure_referral_workspace_links()
    apply_branding()


def after_sync():
    """Re-apply OMC Desk links after fixtures/dashboard metadata are synced."""
    sync_desk_metadata()
    ensure_referral_workspace_links()


def after_migrate():
    validate_client_erp_contract()
    sync_canonical_roles()
    sync_desk_metadata()
    ensure_referral_workspace_links()
    apply_branding()
