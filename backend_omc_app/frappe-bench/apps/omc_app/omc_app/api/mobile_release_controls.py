"""Pure validation shared by Desk saves and public configuration reads.

This module changes no settings and adds no dependency or migration.
"""
from __future__ import annotations

import re

_SEMVER = re.compile(
    r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-((?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)"
    r"(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?"
    r"(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?"
)


def _flag(value, field):
    if value is None or value == "":
        return False  # Unset Check fields do not activate controls.
    if isinstance(value, bool):
        return value
    if isinstance(value, int) and value in (0, 1):
        return bool(value)
    if isinstance(value, str) and value.strip().lower() in {"0", "1", "true", "false"}:
        return value.strip().lower() in {"1", "true"}
    raise ValueError(f"{field} must be enabled or disabled.")


def validate_release_controls(minimum_app_version=None, force_update=None, maintenance_mode=None):
    if minimum_app_version is not None and not isinstance(minimum_app_version, str):
        raise ValueError("Minimum app version must be a semantic version such as 9.0.0.")
    minimum = (minimum_app_version or "").strip()
    if minimum and (len(minimum) > 128 or not _SEMVER.fullmatch(minimum)):
        raise ValueError("Minimum app version must be a valid semantic version such as 9.0.0.")
    force = _flag(force_update, "Force update")
    maintenance = _flag(maintenance_mode, "Maintenance mode")
    if force and not minimum:
        raise ValueError("A minimum app version is required before forcing an update.")
    return {
        "minimum_app_version": minimum,
        "force_update": force,
        "maintenance_mode": maintenance,
    }
