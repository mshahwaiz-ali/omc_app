from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import access, access_v2
from omc_app.setup.roles import ADMIN_ROLE, CUSTOMER_ROLE, MANAGER_ROLE, SYSTEM_ROLE


class TestCanonicalAccessCapabilities(FrappeTestCase):
    def test_guest_capabilities_are_public_only(self):
        with patch.object(access, "_roles", return_value=set()):
            capabilities = access.get_mobile_capabilities(user="Guest")

        self.assertEqual(capabilities["access_state"], "guest")
        self.assertTrue(capabilities["can_view_public_catalogue"])
        self.assertTrue(capabilities["can_view_public_content"])
        self.assertTrue(capabilities["can_use_tax_calculator"])
        self.assertFalse(capabilities["can_create_service_request"])
        self.assertFalse(capabilities["can_access_internal_workspace"])

    def test_admin_has_internal_management_capabilities(self):
        with patch.object(access, "_roles", return_value={ADMIN_ROLE}):
            capabilities = access.get_mobile_capabilities(user="admin@example.com")

        self.assertEqual(capabilities["access_state"], "internal")
        self.assertTrue(capabilities["can_access_internal_workspace"])
        self.assertTrue(capabilities["can_manage_customers"])
        self.assertTrue(capabilities["can_manage_leads"])
        self.assertTrue(capabilities["can_manage_tasks"])
        self.assertTrue(capabilities["can_manage_settings"])
        self.assertFalse(capabilities["can_create_service_request"])

    def test_manager_has_operational_capabilities(self):
        with patch.object(access, "_roles", return_value={MANAGER_ROLE}):
            capabilities = access.get_mobile_capabilities(user="manager@example.com")

        self.assertEqual(capabilities["access_state"], "internal")
        self.assertTrue(capabilities["can_update_service_status"])
        self.assertTrue(capabilities["can_review_documents"])
        self.assertTrue(capabilities["can_review_payments"])
        self.assertTrue(capabilities["can_update_support_ticket_status"])
        self.assertTrue(capabilities["can_manage_settings"])

    def test_system_manager_is_internal_admin(self):
        with patch.object(access, "_roles", return_value={SYSTEM_ROLE}):
            capabilities = access.get_mobile_capabilities(user="system@example.com")

        self.assertEqual(capabilities["access_state"], "internal")
        self.assertTrue(capabilities["can_access_internal_workspace"])
        self.assertTrue(capabilities["can_manage_settings"])

    def test_customer_uses_mobile_profile_capabilities(self):
        expected = {
            "access_state": "approved",
            "can_create_service_request": True,
            "can_access_internal_workspace": False,
        }
        with (
            patch.object(access, "_roles", return_value={CUSTOMER_ROLE}),
            patch.object(
                access.mobile,
                "_get_mobile_capabilities",
                return_value=expected,
            ) as mobile_capabilities,
        ):
            capabilities = access.get_mobile_capabilities(user="customer@example.com")

        self.assertEqual(capabilities, expected)
        mobile_capabilities.assert_called_once_with(user="customer@example.com")


class TestAccessV2Compatibility(FrappeTestCase):
    def test_access_v2_delegates_to_canonical_access(self):
        expected = {
            "access_state": "pending",
            "can_access_internal_workspace": False,
        }
        with patch.object(
            access_v2.canonical_access,
            "get_mobile_capabilities",
            return_value=expected,
        ) as canonical_capabilities:
            capabilities = access_v2._capabilities(
                user="pending@example.com",
                profile=object(),
            )

        self.assertEqual(capabilities, expected)
        canonical_capabilities.assert_called_once_with(user="pending@example.com")
