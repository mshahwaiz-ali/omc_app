from omc_app.branding import apply_branding
from omc_app.setup.desk_metadata import sync_desk_metadata
from omc_app.setup.roles import sync_canonical_roles


def after_install():
    sync_canonical_roles()
    sync_desk_metadata()
    apply_branding()


def after_migrate():
    sync_canonical_roles()
    sync_desk_metadata()
    apply_branding()
