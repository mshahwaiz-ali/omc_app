from __future__ import annotations

import hashlib

import frappe
from frappe.utils import now_datetime

from omc_app.api import identity


def _text(value) -> str:
    return str(value or "").strip()


def _key(*values) -> str:
    return hashlib.sha256("|".join(_text(value) for value in values).encode()).hexdigest()


def create_snapshot(
    *,
    referral_registry: str,
    customer_account: str,
    attribution_type: str,
    service_request: str = "",
    consent_status: str = "Granted",
):
    if attribution_type not in {"Acquisition", "Service Request"}:
        frappe.throw("Invalid referral attribution type.", frappe.ValidationError)
    registry = frappe.get_doc("OMC Referral", referral_registry)
    account = frappe.get_doc("OMC Customer Account", customer_account)
    staff = identity.get_staff_access(registry.referrer_user)
    if not staff or staff.access_status != "Approved" or staff.reconciliation_status != "Current":
        frappe.throw("Referral owner is not eligible.", frappe.PermissionError)
    persona = _text(staff.persona_snapshot)
    if persona not in {
        "Consultant", "Tax Associate", "Tax Associates", "Business Partner",
        "OMC Consultant", "OMC Tax Associate", "OMC Business Partner",
    }:
        frappe.throw("Referral owner is not eligible.", frappe.PermissionError)
    attribution_key = _key(
        attribution_type,
        registry.name,
        account.name,
        service_request if attribution_type == "Service Request" else "acquisition",
    )
    existing = frappe.db.get_value(
        "OMC Referral Attribution", {"attribution_key": attribution_key}, "name"
    )
    if existing:
        return frappe.get_doc("OMC Referral Attribution", existing)
    doc = frappe.get_doc({
        "doctype": "OMC Referral Attribution",
        "attribution_key": attribution_key,
        "attribution_type": attribution_type,
        "referral_registry": registry.name,
        "referral_code_snapshot": registry.referral_code,
        "owner_user": registry.referrer_user,
        "owner_persona_snapshot": persona,
        "customer_account": account.name,
        "erp_customer": account.erp_customer,
        "service_request": service_request or None,
        "consent_status": consent_status,
        "consent_version": "omc-referral-consent-v1",
        "attributed_at": now_datetime(),
        "source_version": identity.source_version(
            registry.name, registry.referral_code, registry.modified,
            staff.name, staff.source_version, account.source_version,
        ),
    })
    try:
        doc.insert(ignore_permissions=True)
    except frappe.DuplicateEntryError:
        return frappe.get_doc(
            "OMC Referral Attribution",
            frappe.db.get_value(
                "OMC Referral Attribution", {"attribution_key": attribution_key}, "name"
            ),
        )
    return doc


def request_snapshot(*, request, account, referral_registry: str):
    return create_snapshot(
        referral_registry=referral_registry,
        customer_account=account.name,
        attribution_type="Service Request",
        service_request=request.name,
    )
