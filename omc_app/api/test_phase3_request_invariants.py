from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.omc_app.doctype.omc_service_request.omc_service_request import (
    OMCServiceRequest,
)


class TestPhase3RequestIdentityInvariant(FrappeTestCase):
    def _request(self, *, profile="", state="Pending Payment"):
        request = object.__new__(OMCServiceRequest)
        request.customer_profile = profile
        request.request_state = state
        request.erp_customer = ""
        request.customer_account = ""
        request.is_new = lambda: True
        return request

    def test_new_operational_request_requires_profile(self):
        request = self._request(profile="")

        with (
            patch(
                "omc_app.omc_app.doctype.omc_service_request.omc_service_request."
                "customer_authority.enforce_request_customer",
                return_value="ERP-CUST-1",
            ),
            self.assertRaises(frappe.ValidationError),
        ):
            request._enforce_customer_authority()

    def test_new_operational_request_requires_erp_customer(self):
        request = self._request(profile="PROFILE-1")

        with (
            patch.object(
                frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                frappe,
                "get_doc",
                return_value=SimpleNamespace(
                    linked_erpnext_customer=""
                ),
            ),
            patch(
                "omc_app.omc_app.doctype.omc_service_request.omc_service_request."
                "customer_authority.enforce_request_customer",
                return_value="",
            ),
            self.assertRaises(frappe.ValidationError),
        ):
            request._enforce_customer_authority()

    def test_new_operational_request_projects_canonical_customer(self):
        request = self._request(profile="PROFILE-1")

        with (
            patch.object(
                frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                frappe,
                "get_doc",
                return_value=SimpleNamespace(
                    linked_erpnext_customer="ERP-CUST-1"
                ),
            ),
            patch(
                "omc_app.omc_app.doctype.omc_service_request.omc_service_request."
                "customer_authority.enforce_request_customer",
                return_value="ERP-CUST-1",
            ),
        ):
            customer=request._enforce_customer_authority()

        self.assertEqual(customer,"ERP-CUST-1")
        self.assertEqual(request.erp_customer,"ERP-CUST-1")

    def test_historical_import_is_not_forced_into_new_identity_invariant(self):
        request=self._request(profile="",state="Historical")

        with patch(
            "omc_app.omc_app.doctype.omc_service_request.omc_service_request."
            "customer_authority.enforce_request_customer",
            return_value="",
        ):
            self.assertEqual(
                request._enforce_customer_authority(),
                "",
            )
