from __future__ import annotations

from omc_app.setup.operations import initialize_site, validate_site


def before_install():
    return validate_site()


def after_install():
    # Installing the app is an explicit operator action, so one-time OMC setup
    # is appropriate here. Normal migrate/sync never invokes these mutations.
    return initialize_site(commit=False)


def after_migrate():
    """Normal migrate is validation-only: no roles, branding or Desk rewrites."""
    return validate_site()
