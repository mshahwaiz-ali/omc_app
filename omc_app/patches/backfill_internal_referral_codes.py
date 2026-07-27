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
