"""Unified mobile service request APIs.

Customers create requests for their own approved profile. Internal assisted
requests are delegated to the shared assisted-service authority so referral,
consent, and customer-mode rules are enforced consistently.
"""

import frappe

from omc_app.api import assisted_service


@frappe.whitelist()
def create_service(**kwargs):
    return assisted_service.create_request(**kwargs)
