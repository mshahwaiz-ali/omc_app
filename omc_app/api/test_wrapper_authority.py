from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app import hooks
from omc_app.api import access_v2, secured_mobile


class TestAccessV2GuestBootstrap(FrappeTestCase):
    @patch("omc_app.api.access_v2.mobile.get_session_user")
    def test_guest_session_user_is_public_safe(self, get_session_user):
        get_session_user.return_value = {
            "user": "Guest",
            "is_guest": True,
            "roles": [],
            "access_state": "guest",
            "capabilities": {"access_state": "guest"},
        }

        result = access_v2.get_session_user()

        self.assertEqual(result["user"], "Guest")
        self.assertTrue(result["is_guest"])
        self.assertEqual(result["access_state"], "guest")
        self.assertEqual(result["capabilities"]["access_state"], "guest")

    @patch("omc_app.api.access_v2._capabilities")
    def test_guest_capabilities_endpoint_returns_public_contract(self, capabilities):
        capabilities.return_value = {
            "access_state": "guest",
            "can_browse_services": True,
            "can_create_service_request": False,
        }

        result = access_v2.get_mobile_capabilities()

        self.assertEqual(result["access_state"], "guest")
        self.assertTrue(result["can_browse_services"])
        self.assertFalse(result["can_create_service_request"])


class TestLegacyMutationHookAuthority(FrappeTestCase):
    def test_service_case_status_legacy_path_is_overridden(self):
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.mobile.update_service_case_status"
            ],
            "omc_app.api.secured_mobile.update_service_case_status",
        )

    def test_document_status_legacy_path_is_overridden(self):
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.mobile.update_service_document_status"
            ],
            "omc_app.api.secured_mobile.update_service_document_status",
        )

    @patch("omc_app.api.secured_mobile.mobile.update_service_case_status")
    @patch("omc_app.api.secured_mobile._require_capability")
    def test_secured_case_status_requires_capability_before_delegation(
        self,
        require_capability,
        update_status,
    ):
        update_status.return_value = {"updated": True, "status": "In Progress"}

        result = secured_mobile.update_service_case_status(
            case_id="CASE-0001",
            status="In Progress",
        )

        require_capability.assert_called_once_with(
            "can_update_service_status",
            "can_update_assigned_service_status",
            message="You do not have permission to update service case status.",
        )
        update_status.assert_called_once_with(
            case_id="CASE-0001",
            status="In Progress",
            note=None,
            expected_completion_date=None,
        )
        self.assertTrue(result["updated"])

    @patch("omc_app.api.secured_mobile.mobile.update_service_document_status")
    @patch("omc_app.api.secured_mobile._require_capability")
    def test_secured_document_status_requires_capability_before_delegation(
        self,
        require_capability,
        update_status,
    ):
        update_status.return_value = {"updated": True, "status": "Approved"}

        result = secured_mobile.update_service_document_status(
            document_id="DOC-0001",
            status="Approved",
            remarks="Verified",
        )

        require_capability.assert_called_once()
        update_status.assert_called_once_with(
            document_id="DOC-0001",
            status="Approved",
            remarks="Verified",
        )
        self.assertTrue(result["updated"])
