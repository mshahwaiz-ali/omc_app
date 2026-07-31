"""Canonical ERP Customer resolver for approved OMC customer profiles."""

from __future__ import annotations

from typing import Any

import frappe


def _text(value: Any) -> str:
    return str(value or "").strip()


def _profile_user(profile) -> str:
    return _text(
        getattr(profile, "linked_app_user", None)
        or getattr(profile, "user", None)
    )


def _valid_link(profile) -> str:
    customer = _text(getattr(profile, "linked_erpnext_customer", None))
    if customer and frappe.db.exists("Customer", customer):
        return customer
    return ""


def _customer_matches(profile, user: str) -> list[str]:
    meta = frappe.get_meta("Customer")
    identity_fields = (
        ("user_link", user),
        ("email_id", getattr(profile, "email", None)),
        ("mobile_no", getattr(profile, "phone", None)),
        ("tax_id", getattr(profile, "ntn", None)),
    )

    matches: set[str] = set()
    for fieldname, raw_value in identity_fields:
        value = _text(raw_value)
        if not value or not meta.get_field(fieldname):
            continue

        rows = frappe.get_all(
            "Customer",
            filters={fieldname: value},
            pluck="name",
            limit=3,
        )
        matches.update(_text(name) for name in rows if _text(name))
        if len(matches) > 1:
            break

    return sorted(matches)


def _default_value(fieldname: str) -> str:
    return _text(frappe.db.get_single_value("Selling Settings", fieldname))


def _set_if_field(doc, fieldname: str, value: Any) -> None:
    if value not in (None, "") and doc.meta.get_field(fieldname):
        doc.set(fieldname, value)


def _link_profile(profile, customer: str) -> None:
    profile.set("linked_erpnext_customer", customer)
    frappe.db.set_value(
        profile.doctype,
        profile.name,
        "linked_erpnext_customer",
        customer,
        update_modified=False,
    )


def _create_customer(profile, user: str):
    full_name = _text(getattr(profile, "full_name", None))
    if not full_name:
        return None, "customer profile has no full name"

    customer_group = _default_value("customer_group")
    territory = _default_value("territory")
    if not customer_group or not territory:
        return None, "ERP Selling Settings require customer group and territory"

    customer = frappe.new_doc("Customer")
    customer.customer_name = full_name
    customer.customer_type = "Individual"
    customer.customer_group = customer_group
    customer.territory = territory

    _set_if_field(customer, "user_link", user)
    _set_if_field(customer, "mobile_no", getattr(profile, "phone", None))
    _set_if_field(customer, "email_id", getattr(profile, "email", None))
    _set_if_field(customer, "tax_id", getattr(profile, "ntn", None))

    customer.insert(ignore_permissions=True)
    return customer, ""


def resolve_profile_customer(profile, *, create_if_missing: bool = True) -> dict[str, Any]:
    if not profile:
        return {
            "status": "Pending Configuration",
            "customer": "",
            "created": False,
            "reason": "customer profile is required",
        }

    linked = _valid_link(profile)
    if linked:
        return {
            "status": "Resolved",
            "customer": linked,
            "created": False,
            "reason": "",
        }

    if _text(getattr(profile, "approval_status", None)) != "Approved":
        return {
            "status": "Pending Configuration",
            "customer": "",
            "created": False,
            "reason": "customer profile is not approved",
        }

    if not int(getattr(profile, "is_active", 0) or 0):
        return {
            "status": "Pending Configuration",
            "customer": "",
            "created": False,
            "reason": "customer profile is inactive",
        }

    user = _profile_user(profile)
    if not user:
        return {
            "status": "Pending Configuration",
            "customer": "",
            "created": False,
            "reason": "customer profile has no linked app user",
        }

    matches = _customer_matches(profile, user)
    if len(matches) > 1:
        return {
            "status": "Ambiguous",
            "customer": "",
            "created": False,
            "reason": "multiple ERP Customers match this customer identity",
        }

    if len(matches) == 1:
        _link_profile(profile, matches[0])
        return {
            "status": "Resolved",
            "customer": matches[0],
            "created": False,
            "reason": "",
        }

    if not create_if_missing:
        return {
            "status": "Pending Configuration",
            "customer": "",
            "created": False,
            "reason": "no ERP Customer is linked to this profile",
        }

    customer, error = _create_customer(profile, user)
    if not customer:
        return {
            "status": "Pending Configuration",
            "customer": "",
            "created": False,
            "reason": error,
        }

    _link_profile(profile, customer.name)
    return {
        "status": "Created",
        "customer": customer.name,
        "created": True,
        "reason": "",
    }
