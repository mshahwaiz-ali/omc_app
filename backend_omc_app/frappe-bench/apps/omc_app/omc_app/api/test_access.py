from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import access, access_v2
from omc_app.setup.roles import (
    ADMIN_ROLE,
    BUSINESS_PARTNER_ROLE,
    CONSULTANT_ROLE,
    CUSTOMER_ROLE,
    DOCUMENT_REVIEWER_ROLE,
    FINANCE_REVIEWER_ROLE,
    MANAGER_ROLE,
    SUPPORT_AGENT_ROLE,
    SYSTEM_ROLE,
    TAX_ASSOCIATE_ROLE,
)


class TestCanonicalAccessCapabilities(FrappeTestCase):
    def _capabilities_for(self, role):
        with patch.object(access, "_roles", return_value={role}):
            return access.get_mobile_capabilities(user=f"{role}@example.com")

    def test_guest_capabilities_are_public_only(self):
        with patch.object(access, "_roles", return_value=set()):
            capabilities = access.get_mobile_capabilities(user="Guest")

        self.assertEqual(capabilities["access_state"], "guest")
        self.assertTrue(capabilities["can_view_public_catalogue"])
        self.assertTrue(capabilities["can_view_public_content"])
        self.assertTrue(capabilities["can_use_tax_calculator"])
        self.assertFalse(capabilities["can_create_service_request"])
        self.assertFalse(capabilities["can_access_internal_workspace"])

    def test_admin_has_full_internal_capabilities(self):
        capabilities = self._capabilities_for(ADMIN_ROLE)
        self.assertTrue(capabilities["can_manage_customers"])
        self.assertTrue(capabilities["can_review_documents"])
        self.assertTrue(capabilities["can_review_payments"])
        self.assertTrue(capabilities["can_manage_settings"])

    def test_manager_has_operations_but_not_settings(self):
        capabilities = self._capabilities_for(MANAGER_ROLE)
        self.assertTrue(capabilities["can_update_service_status"])
        self.assertTrue(capabilities["can_review_documents"])
        self.assertTrue(capabilities["can_review_payments"])
        self.assertFalse(capabilities["can_manage_settings"])

    def test_support_agent_is_support_scoped(self):
        capabilities = self._capabilities_for(SUPPORT_AGENT_ROLE)
        self.assertTrue(capabilities["can_reply_support_tickets"])
        self.assertTrue(capabilities["can_manage_leads"])
        self.assertFalse(capabilities["can_review_documents"])
        self.assertFalse(capabilities["can_review_payments"])

    def test_document_reviewer_is_document_scoped(self):
        capabilities = self._capabilities_for(DOCUMENT_REVIEWER_ROLE)
        self.assertTrue(capabilities["can_view_document_queue"])
        self.assertTrue(capabilities["can_review_documents"])
        self.assertFalse(capabilities["can_review_payments"])
        self.assertFalse(capabilities["can_manage_leads"])

    def test_finance_reviewer_is_payment_scoped(self):
        capabilities = self._capabilities_for(FINANCE_REVIEWER_ROLE)
        self.assertTrue(capabilities["can_view_payment_queue"])
        self.assertTrue(capabilities["can_review_payments"])
        self.assertFalse(capabilities["can_review_documents"])
        self.assertFalse(capabilities["can_manage_leads"])

    def test_assignment_scoped_roles_share_consultant_baseline(self):
        for role in (CONSULTANT_ROLE, TAX_ASSOCIATE_ROLE, BUSINESS_PARTNER_ROLE):
            with self.subTest(role=role):
                capabilities = self._capabilities_for(role)
                self.assertTrue(capabilities["can_view_assigned_service_cases"])
                self.assertTrue(capabilities["can_update_assigned_service_status"])
                self.assertTrue(capabilities["can_manage_assigned_tasks"])
                self.assertFalse(capabilities["can_view_all_service_cases"])
                self.assertFalse(capabilities["can_manage_settings"])

    def test_system_manager_is_internal_admin(self):
        capabilities = self._capabilities_for(SYSTEM_ROLE)
        self.assertTrue(capabilities["can_access_internal_workspace"])
        self.assertTrue(capabilities["can_manage_settings"])
        self.assertTrue(capabilities["can_review_documents"])
        self.assertTrue(capabilities["can_review_payments"])

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
