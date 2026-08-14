from __future__ import annotations

import frappe

from omc_app.referral_automation import ensure_referral_code_for_user


def execute():
    users = frappe.get_all(
        "User",
        filters={"enabled": 1, "user_type": "System User"},
        pluck="name",
    )

    for user in users:
        ensure_referral_code_for_user(user)

    owners = frappe.get_all(
        "OMC Referral",
        filters={"referrer_user": ["is", "set"]},
        pluck="referrer_user",
    )
    for user in set(owners):
        if not frappe.db.exists("User", user):
            continue
        ensure_referral_code_for_user(user)

    frappe.clear_cache()
