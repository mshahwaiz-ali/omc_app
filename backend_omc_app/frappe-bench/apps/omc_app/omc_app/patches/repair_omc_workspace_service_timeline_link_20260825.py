from __future__ import annotations

import frappe


LEGACY_TARGET = "OMC ServiceTimeline"
CANONICAL_TARGET = "OMC Service Timeline"


def execute():
    """Repair the legacy malformed OMC Service Timeline workspace target."""
    rows = frappe.get_all(
        "Workspace Link",
        filters={
            "parent": "OMC App",
            "parenttype": "Workspace",
            "link_to": LEGACY_TARGET,
        },
        pluck="name",
    )
    for name in rows:
        frappe.db.set_value(
            "Workspace Link",
            name,
            "link_to",
            CANONICAL_TARGET,
            update_modified=False,
        )
