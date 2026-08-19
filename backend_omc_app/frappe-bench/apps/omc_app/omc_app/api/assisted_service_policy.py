from __future__ import annotations

import frappe

from omc_app.api import assisted_service


ALLOWED_ASSISTED_MODES = {"My Referral", "Existing Customer"}


def _mode(value) -> str:
    return str(value or "").strip()


def _assert_allowed_assisted_mode(value) -> str:
    mode = _mode(value)
    if mode not in ALLOWED_ASSISTED_MODES:
        frappe.throw(
            "Internal staff can create service requests only for their own referrals or approved existing customers.",
            frappe.PermissionError,
        )
    return mode


@frappe.whitelist()
def get_customer_selection_options(
    customer_mode=None,
    search=None,
    limit_start=0,
    limit_page_length=20,
):
    selected_mode = _mode(customer_mode)
    if selected_mode:
        _assert_allowed_assisted_mode(selected_mode)

    response = assisted_service.get_customer_selection_options(
        customer_mode=selected_mode or None,
        search=search,
        limit_start=limit_start,
        limit_page_length=limit_page_length,
    )

    if not isinstance(response, dict):
        return response

    modes = [
        mode
        for mode in (response.get("modes") or [])
        if mode in ALLOWED_ASSISTED_MODES
    ]
    response["modes"] = modes

    capabilities = dict(response.get("capabilities") or {})
    capabilities["can_search_all_customers"] = False
    capabilities["can_use_my_referrals"] = "My Referral" in modes
    capabilities["can_use_walk_in_customers"] = "Walk-in Customer" in modes
    response["capabilities"] = capabilities
    return response


@frappe.whitelist(methods=["POST"])
def create_request(**kwargs):
    data = dict(kwargs or {})
    data["customer_mode"] = _assert_allowed_assisted_mode(data.get("customer_mode"))
    return assisted_service.create_request(**data)


@frappe.whitelist(methods=["POST"])
def create_service_request_for_customer(**kwargs):
    return create_request(**kwargs)
