from __future__ import annotations

import hashlib

import frappe

from omc_app.api import mobile, security


def _token_actor(value) -> str:
    return hashlib.sha256(str(value or "").encode("utf-8")).hexdigest()


@frappe.whitelist(allow_guest=True, methods=["POST"])
def google_mobile_login(id_token=None, **kwargs):
    token = str(id_token or kwargs.get("token") or "").strip()
    security.enforce_rate_limit("login", actor=_token_actor(token))
    return mobile.google_mobile_login(id_token=token, **kwargs)


@frappe.whitelist(methods=["POST"])
def create_lead(**kwargs):
    actor = str(getattr(getattr(frappe, "session", None), "user", None) or "Guest")
    security.enforce_rate_limit("staff_mutation", actor=actor)
    return mobile.create_lead(**kwargs)
