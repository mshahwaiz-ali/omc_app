"""Canonical ERP Customer authority for OMC service-request flows.

ERP Customer is the canonical business identity.

OMC Customer Profile is the OMC workflow/application projection.
OMC Customer Account is optional app-access/link authority and must never
define whether the underlying business customer exists or is serviceable.

Where request, Profile and Account links coexist they must all agree with the
same ERP Customer. Conflicts fail closed before ERP operational work occurs.
"""
from __future__ import annotations

from typing import Any

import frappe


def _text(value: Any) -> str:
    return str(value or "").strip()


def _valid_erp_customer(customer: str) -> bool:
    customer = _text(customer)
    return bool(
        customer
        and frappe.db.exists("Customer", customer)
    )


def _validated_customer(
    customer: str,
    *,
    source: str,
) -> str:
    customer = _text(customer)

    if not customer:
        return ""

    if not _valid_erp_customer(customer):
        frappe.throw(
            f"{source} is not linked to a valid ERP Customer.",
            frappe.ValidationError,
        )

    return customer


def _account_customer(account_name: str) -> str:
    account_name = _text(account_name)

    if not account_name:
        return ""

    if not frappe.db.exists(
        "OMC Customer Account",
        account_name,
    ):
        frappe.throw(
            f"Linked OMC Customer Account {account_name} does not exist.",
            frappe.ValidationError,
        )

    customer = _text(
        frappe.db.get_value(
            "OMC Customer Account",
            account_name,
            "erp_customer",
        )
    )

    if not _valid_erp_customer(customer):
        frappe.throw(
            f"OMC Customer Account {account_name} is not linked "
            "to a valid ERP Customer.",
            frappe.ValidationError,
        )

    return customer


def resolve_request_customer(request, *, profile=None) -> str:
    """Return the canonical ERP Customer for request ERP work.

    ERP Customer is authoritative when already projected onto the request.

    Profile and Customer Account links remain important consistency evidence,
    but Customer Account is not required for a valid business customer.

    Legacy requests may still resolve from Profile or Account when the request
    itself predates the ERP Customer projection.
    """

    request_customer = _validated_customer(
        getattr(request, "erp_customer", None),
        source="Service Request ERP Customer",
    )

    profile_customer = _validated_customer(
        getattr(profile, "linked_erpnext_customer", None)
        if profile
        else "",
        source="OMC Customer Profile",
    )

    account_customer = _account_customer(
        getattr(request, "customer_account", None)
    )

    customer = (
        request_customer
        or profile_customer
        or account_customer
    )

    if not customer:
        return ""

    links = (
        ("Service Request", request_customer),
        ("OMC Customer Profile", profile_customer),
        ("OMC Customer Account", account_customer),
    )

    for source, linked_customer in links:
        if (
            linked_customer
            and linked_customer != customer
        ):
            frappe.throw(
                f"{source} ERP Customer conflicts with the "
                "canonical ERP Customer.",
                frappe.ValidationError,
            )

    return customer


def enforce_request_customer(request, *, profile=None) -> str:
    """Validate authority and project the ERP Customer onto the request.

    The helper mutates only the in-memory Service Request. Its normal insert
    or save transaction persists the projection. It never commits and never
    creates ERP accounting or operational records.
    """

    customer = resolve_request_customer(
        request,
        profile=profile,
    )

    if customer:
        setter = getattr(request, "set", None)

        if callable(setter):
            setter("erp_customer", customer)
        else:
            setattr(request, "erp_customer", customer)

    return customer
