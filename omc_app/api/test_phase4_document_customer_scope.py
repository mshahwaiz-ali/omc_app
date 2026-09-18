from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import service_document_read


class TestPhase4DocumentCustomerScope(FrappeTestCase):
    def test_erp_customer_selector_resolves_single_profile(self):
        with (
            patch.object(
                service_document_read.frappe.db,
                "exists",
                side_effect=lambda doctype, name: (
                    doctype == "Customer"
                    and name == "ERP-CUST-1"
                ),
            ),
            patch.object(
                service_document_read.frappe,
                "get_all",
                return_value=["PROFILE-1"],
            ) as get_all,
        ):
            result = service_document_read._customer_request_scope(
                "ERP-CUST-1"
            )

        self.assertEqual(result, ("ERP-CUST-1", "PROFILE-1"))
        get_all.assert_called_once()

    def test_profile_selector_projects_linked_erp_customer(self):
        with (
            patch.object(
                service_document_read.frappe.db,
                "exists",
                side_effect=lambda doctype, name: (
                    doctype == "OMC Customer Profile"
                    and name == "PROFILE-1"
                ),
            ),
            patch.object(
                service_document_read.frappe.db,
                "get_value",
                return_value="ERP-CUST-1",
            ),
        ):
            result = service_document_read._customer_request_scope(
                "PROFILE-1"
            )

        self.assertEqual(result, ("ERP-CUST-1", "PROFILE-1"))

    def test_ambiguous_customer_projection_fails_closed(self):
        with (
            patch.object(
                service_document_read.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                service_document_read.frappe,
                "get_all",
                return_value=["PROFILE-1", "PROFILE-2"],
            ),
            self.assertRaises(frappe.ValidationError),
        ):
            service_document_read._customer_request_scope(
                "ERP-CUST-1"
            )
