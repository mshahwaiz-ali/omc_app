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
    owner_persona_snapshot: str = "",
):
    if attribution_type not in {"Acquisition", "Service Request"}:
        frappe.throw("Invalid referral attribution type.", frappe.ValidationError)
    registry = frappe.get_doc("OMC Referral", referral_registry)
    account = frappe.get_doc("OMC Customer Account", customer_account)
    staff = identity.get_staff_access(registry.referrer_user)
    if not staff or staff.access_status != "Approved" or staff.reconciliation_status != "Current":
        frappe.throw("Referral owner is not eligible.", frappe.PermissionError)
    allowed_personas = {
        "Consultant", "Tax Associate", "Tax Associates", "Business Partner",
        "OMC Consultant", "OMC Tax Associate", "OMC Business Partner",
    }

    current_persona = _text(staff.persona_snapshot)
    if current_persona not in allowed_personas:
        frappe.throw(
            "Referral owner is not eligible.",
            frappe.PermissionError,
        )

    persona = (
        _text(owner_persona_snapshot)
        or current_persona
    )
    if persona not in allowed_personas:
        frappe.throw(
            "Invalid referral persona snapshot.",
            frappe.ValidationError,
        )
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
            persona,
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



def create_historical_acquisition_snapshot(
    *,
    referral_registry: str,
    erp_customer: str,
    historical_persona: str,
):
    """Create immutable ERP-provenance acquisition attribution."""

    erp_customer = _text(erp_customer)
    persona = _text(historical_persona)

    if not erp_customer or not frappe.db.exists(
        "Customer", erp_customer
    ):
        frappe.throw(
            "Historical ERP customer is invalid.",
            frappe.ValidationError,
        )

    if persona not in {
        "Consultant",
        "Tax Associate",
        "Tax Associates",
        "Business Partner",
    }:
        frappe.throw(
            "Historical referral persona is invalid.",
            frappe.ValidationError,
        )

    registry = frappe.get_doc(
        "OMC Referral",
        referral_registry,
    )

    staff = identity.get_staff_access(
        registry.referrer_user
    )
    if (
        not staff
        or staff.access_status != "Approved"
        or staff.reconciliation_status != "Current"
    ):
        frappe.throw(
            "Referral owner is not eligible.",
            frappe.PermissionError,
        )

    existing_rows = frappe.get_all(
        "OMC Referral Attribution",
        filters={
            "attribution_type": "Acquisition",
            "erp_customer": erp_customer,
        },
        fields=["name"],
        limit_page_length=2,
    )

    if len(existing_rows) > 1:
        frappe.throw(
            "Historical acquisition attribution is ambiguous.",
            frappe.ValidationError,
        )

    if existing_rows:
        existing = frappe.get_doc(
            "OMC Referral Attribution",
            existing_rows[0].name,
        )

        exact = (
            _text(existing.referral_registry)
            == registry.name
            and _text(existing.owner_user)
            == registry.referrer_user
            and _text(existing.owner_persona_snapshot)
            == persona
            and _text(existing.erp_customer)
            == erp_customer
            and _text(existing.consent_status)
            == "Not Applicable"
        )

        if exact:
            return existing

        frappe.throw(
            "Conflicting acquisition attribution already exists.",
            frappe.ValidationError,
        )

    attribution_key = _key(
        "Acquisition",
        registry.name,
        erp_customer,
        "historical",
    )

    doc = frappe.get_doc({
        "doctype": "OMC Referral Attribution",
        "attribution_key": attribution_key,
        "attribution_type": "Acquisition",
        "referral_registry": registry.name,
        "referral_code_snapshot": registry.referral_code,
        "owner_user": registry.referrer_user,
        "owner_persona_snapshot": persona,
        "customer_account": None,
        "erp_customer": erp_customer,
        "service_request": None,
        "consent_status": "Not Applicable",
        "consent_version": "historical-erp-referral-v1",
        "attributed_at": now_datetime(),
        "source_version": identity.source_version(
            registry.name,
            registry.referral_code,
            registry.modified,
            staff.name,
            staff.source_version,
            erp_customer,
            persona,
        ),
    })

    try:
        doc.insert(ignore_permissions=True)
    except frappe.DuplicateEntryError:
        name = frappe.db.get_value(
            "OMC Referral Attribution",
            {"attribution_key": attribution_key},
            "name",
        )
        if name:
            return frappe.get_doc(
                "OMC Referral Attribution",
                name,
            )
        raise

    return doc


def request_snapshot(*, request, account, referral_registry: str):
    historical_persona = ""

    erp_customer = _text(
        getattr(account, "erp_customer", "")
    )
    if erp_customer:
        rows = frappe.get_all(
            "OMC Referral Attribution",
            filters={
                "attribution_type": "Acquisition",
                "referral_registry": referral_registry,
                "erp_customer": erp_customer,
                "consent_status": "Not Applicable",
            },
            fields=["name"],
            limit_page_length=2,
        )

        if len(rows) > 1:
            frappe.throw(
                "Historical acquisition attribution is ambiguous.",
                frappe.ValidationError,
            )

        if rows:
            acquisition = frappe.get_doc(
                "OMC Referral Attribution",
                rows[0].name,
            )
            historical_persona = _text(
                acquisition.owner_persona_snapshot
            )

    kwargs = {
        "referral_registry": referral_registry,
        "customer_account": account.name,
        "attribution_type": "Service Request",
        "service_request": request.name,
    }

    if historical_persona:
        kwargs["owner_persona_snapshot"] = historical_persona

    return create_snapshot(**kwargs)
