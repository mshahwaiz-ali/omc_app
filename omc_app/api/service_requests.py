"""Unified mobile service request APIs.

Customers create requests for their own approved profile. Internal assisted
requests are delegated to the shared assisted-service authority so referral,
consent, and customer-mode rules are enforced consistently.
"""

import frappe

from omc_app.api import assisted_service, payment_opening


@frappe.whitelist(methods=["POST"])
def create_service(**kwargs):
    response = assisted_service.create_request(**kwargs)
    if not isinstance(response, dict) or response.get("duplicate"):
        return response
    request_name = (
        response.get("service_request")
        or response.get("request_id")
        or response.get("name")
    )
    if request_name and frappe.db.exists("OMC Service Request", request_name):
        response["payment_id"] = payment_opening.ensure_service_payment(request_name)
    return response
