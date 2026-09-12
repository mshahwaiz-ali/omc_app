from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import customer_authority, erp_service_task_adapter


class TestCustomerAuthority(FrappeTestCase):
    def _exists(self, doctype, name):
        return (doctype, name) in {
            ("OMC Customer Account", "ACC-0001"),
            ("Customer", "CUST-0001"),
            ("Customer", "CUST-LEGACY"),
            ("Customer", "CUST-PROFILE"),
        }

    def test_account_customer_is_canonical_when_request_cache_is_blank(self):
        request = SimpleNamespace(
            customer_account="ACC-0001",
            erp_customer="",
        )
        with patch.object(
            customer_authority.frappe.db,
            "exists",
            side_effect=self._exists,
        ), patch.object(
            customer_authority.frappe.db,
            "get_value",
            return_value="CUST-0001",
        ):
            customer = customer_authority.resolve_request_customer(request)

        self.assertEqual(customer, "CUST-0001")

    def test_account_customer_conflict_fails_closed(self):
        request = SimpleNamespace(
            customer_account="ACC-0001",
            erp_customer="CUST-LEGACY",
        )
        with patch.object(
            customer_authority.frappe.db,
            "exists",
            side_effect=self._exists,
        ), patch.object(
            customer_authority.frappe.db,
            "get_value",
            return_value="CUST-0001",
        ):
            with self.assertRaises(frappe.ValidationError):
                customer_authority.resolve_request_customer(request)

    def test_missing_customer_account_fails_closed(self):
        request = SimpleNamespace(
            customer_account="ACC-MISSING",
            erp_customer="CUST-LEGACY",
        )
        with patch.object(
            customer_authority.frappe.db,
            "exists",
            side_effect=self._exists,
        ):
            with self.assertRaises(frappe.ValidationError):
                customer_authority.resolve_request_customer(request)

    def test_account_without_valid_erp_customer_fails_closed(self):
        request = SimpleNamespace(
            customer_account="ACC-0001",
            erp_customer="",
        )
        with patch.object(
            customer_authority.frappe.db,
            "exists",
            side_effect=self._exists,
        ), patch.object(
            customer_authority.frappe.db,
            "get_value",
            return_value="CUST-MISSING",
        ):
            with self.assertRaises(frappe.ValidationError):
                customer_authority.resolve_request_customer(request)

    def test_accountless_legacy_request_keeps_existing_erp_customer(self):
        request = SimpleNamespace(
            customer_account="",
            erp_customer="CUST-LEGACY",
        )
        profile = SimpleNamespace(linked_erpnext_customer="CUST-PROFILE")
        with patch.object(
            customer_authority.frappe.db,
            "exists",
            side_effect=self._exists,
        ):
            customer = customer_authority.resolve_request_customer(
                request,
                profile=profile,
            )

        self.assertEqual(customer, "CUST-LEGACY")

    def test_accountless_legacy_request_can_fall_back_to_profile(self):
        request = SimpleNamespace(
            customer_account="",
            erp_customer="",
        )
        profile = SimpleNamespace(linked_erpnext_customer="CUST-PROFILE")
        with patch.object(
            customer_authority.frappe.db,
            "exists",
            side_effect=self._exists,
        ):
            customer = customer_authority.resolve_request_customer(
                request,
                profile=profile,
            )

        self.assertEqual(customer, "CUST-PROFILE")

    def test_enforce_projects_account_customer_to_request(self):
        class Request(SimpleNamespace):
            def set(self, fieldname, value):
                setattr(self, fieldname, value)

        request = Request(
            customer_account="ACC-0001",
            erp_customer="",
        )
        with patch.object(
            customer_authority,
            "resolve_request_customer",
            return_value="CUST-0001",
        ):
            customer = customer_authority.enforce_request_customer(request)

        self.assertEqual(customer, "CUST-0001")
        self.assertEqual(request.erp_customer, "CUST-0001")

    def test_erp_bridge_delegates_customer_resolution_to_authority(self):
        request = SimpleNamespace(
            customer_account="ACC-0001",
            erp_customer="CUST-0001",
        )
        profile = SimpleNamespace(linked_erpnext_customer="CUST-0001")
        with patch.object(
            customer_authority,
            "resolve_request_customer",
            return_value="CUST-0001",
        ) as resolve:
            customer = erp_service_task_adapter._linked_customer(
                request,
                profile,
            )

        self.assertEqual(customer, "CUST-0001")
        resolve.assert_called_once_with(request, profile=profile)
