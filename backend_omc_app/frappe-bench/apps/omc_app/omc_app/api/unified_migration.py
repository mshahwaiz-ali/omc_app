"""Explicit OMC business-data migration orchestration.

Normal ``bench migrate`` remains schema/patch oriented. Operators run this
module explicitly to preflight and apply customer, staff, referral, historical
service, and historical commission reconciliation under one transaction owner.
"""

from __future__ import annotations

import frappe

from omc_app.api import customer_migration, historical_commission_migration


APPLY_CONFIRMATION = customer_migration.APPLY_CONFIRMATION


def preflight():
    """Read-only unified preflight, including historical commissions."""
    customer = customer_migration.preflight()
    commissions = historical_commission_migration.preflight()
    return {
        "read_only": True,
        "mode": "unified",
        "customer_migration": customer,
        "historical_commission_migration": commissions,
    }


def apply(
    confirm=None,
    limit=0,
    batch_size=100,
    commit=True,
):
    """Apply all explicit OMC migration phases without ERP schema mutation.

    ``customer_migration.apply`` is deliberately invoked with ``commit=False``
    so this orchestrator owns the transaction boundary across the historical
    commission phase as well. Safe reruns reuse deterministic OMC records.
    """
    if str(confirm or "") != APPLY_CONFIRMATION:
        frappe.throw(
            "Explicit customer migration confirmation is required.",
            frappe.ValidationError,
        )

    if isinstance(commit, str):
        commit = commit.strip().lower() not in {"0", "false", "no", "off"}
    else:
        commit = bool(commit)

    customer = customer_migration.apply(
        confirm=confirm,
        limit=limit,
        batch_size=batch_size,
        commit=False,
    )
    commissions = historical_commission_migration.apply(commit=False)

    if commit:
        frappe.db.commit()

    return {
        "confirmation": APPLY_CONFIRMATION,
        "commit": commit,
        "mode": "unified",
        "customer_migration": customer,
        "historical_commission_migration": commissions,
    }
