"""Canonical ERP Customer authority for OMC service-request flows.

OMC Customer Account is the application access/link authority for current
requests. Its ``erp_customer`` must therefore agree with any denormalized
``OMC Service Request.erp_customer`` value before ERP operational records are
created. Legacy requests that pre-date Customer Account remain readable and
repairable through their existing request/profile links.
"""
from __future__ import annotations

from typing import Any

import frappe


def _text(value: Any) -> str:
    return str(value or "").strip()


def _valid_erp_customer(customer: str) -> bool:
    customer = _text(customer)
    return bool(customer and frappe.db.exists("Customer", customer))


def resolve_request_customer(request, *, profile=None) -> str:
    """Return the ERP Customer that may own this request's ERP work.

    Current requests with ``customer_account`` fail closed if the account is
    missing, has no valid ERP Customer, or conflicts with the request's cached
    ERP Customer. Requests without a Customer Account retain the legacy
    request/profile fallback so historical data does not require a destructive
    migration merely to remain operable.
    """

    account_name = _text(getattr(request, "customer_account", None))
    request_customer = _text(getattr(request, "erp_customer", None))

    if account_name:
        if not frappe.db.exists("OMC Customer Account", account_name):
            frappe.throw(
                f"Linked OMC Customer Account {account_name} does not exist.",
                frappe.ValidationError,
            )

        account_customer = _text(
            frappe.db.get_value(
                "OMC Customer Account",
                account_name,
                "erp_customer",
            )
        )
        if not _valid_erp_customer(account_customer):
            frappe.throw(
                f"OMC Customer Account {account_name} is not linked to a valid ERP Customer.",
                frappe.ValidationError,
            )

        if request_customer and request_customer != account_customer:
            frappe.throw(
                "Service Request ERP Customer conflicts with the linked OMC Customer Account.",
                frappe.ValidationError,
            )

        return account_customer

    # Backward-compatible authority for requests created before Customer
    # Account became the canonical mobile/customer access boundary.
    if _valid_erp_customer(request_customer):
        return request_customer

    profile_customer = (
        _text(getattr(profile, "linked_erpnext_customer", None))
        if profile
        else ""
    )
    return profile_customer if _valid_erp_customer(profile_customer) else ""


def enforce_request_customer(request, *, profile=None) -> str:
    """Validate authority and project the canonical account Customer to request.

    The projection mutates only the in-memory request document. Its normal
    save/insert transaction persists the value; this helper never commits or
    writes ERP records directly.
    """

    customer = resolve_request_customer(request, profile=profile)
    account_name = _text(getattr(request, "customer_account", None))

    if account_name and customer:
        setter = getattr(request, "set", None)
        if callable(setter):
            setter("erp_customer", customer)
        else:
            setattr(request, "erp_customer", customer)

    return customer
