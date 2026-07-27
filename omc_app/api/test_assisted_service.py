from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import assisted_service


class TestAssistedServiceAuthority(FrappeTestCase):
    def test_my_referral_rejects_unowned_customer(self):
        profile = SimpleNamespace(
            referred_by="other@example.com",
            referral_record="REF-1",
            referral_assistance_consent=1,
            is_active=1,
        )
        with (
            patch.object(assisted_service, "_profile", return_value=profile),
            self.assertRaises(frappe.PermissionError),
        ):
            assisted_service._resolve_my_referral(
                "staff@example.com",
                "CUST-1",
            )

    def test_my_referral_requires_consent(self):
        profile = SimpleNamespace(
            referred_by="staff@example.com",
            referral_record="REF-1",
            referral_assistance_consent=0,
            is_active=1,
        )
        with (
            patch.object(assisted_service, "_profile", return_value=profile),
            self.assertRaises(frappe.PermissionError),
        ):
            assisted_service._resolve_my_referral(
                "staff@example.com",
                "CUST-1",
            )

    def test_existing_customer_requires_admin_role(self):
        with (
            patch.object(
                assisted_service,
                "_roles",
                return_value={"OMC Consultant"},
            ),
            self.assertRaises(frappe.PermissionError),
        ):
            assisted_service._resolve_existing_customer(
                "consultant@example.com",
                "CUST-1",
                "CONSENT-1",
            )

    def test_existing_customer_requires_consent_reference(self):
        with (
            patch.object(
                assisted_service,
                "_roles",
                return_value={"OMC Admin"},
            ),
            self.assertRaises(frappe.ValidationError),
        ):
            assisted_service._resolve_existing_customer(
                "admin@example.com",
                "CUST-1",
                "",
            )

    def test_walk_in_creation_sets_audit_fields(self):
        manual = MagicMock()
        manual.name = "MC-1"
        with (
            patch.object(
                assisted_service,
                "_roles",
                return_value={"OMC Support Agent"},
            ),
            patch.object(
                assisted_service.frappe,
                "new_doc",
                return_value=manual,
            ),
        ):
            result = assisted_service._create_manual_customer(
                "staff@example.com",
                {
                    "full_name": "Walk In Customer",
                    "phone": "03001234567",
                    "city": "Karachi",
                },
            )

        self.assertIs(result, manual)
        self.assertEqual(manual.created_by_user, "staff@example.com")
        self.assertEqual(manual.referral_owner, "staff@example.com")
        self.assertEqual(manual.customer_origin, "Walk-in")
        manual.insert.assert_called_once_with(ignore_permissions=True)

    def test_internal_request_requires_explicit_customer_mode(self):
        service = SimpleNamespace(
            name="SERVICE-1",
            title="Tax Service",
        )
        with (
            patch.object(
                assisted_service,
                "_current_user",
                return_value="staff@example.com",
            ),
            patch.object(
                assisted_service.mobile,
                "_can_access_internal_workspace",
                return_value=True,
            ),
            patch.object(
                assisted_service,
                "_service_doc",
                return_value=service,
            ),
            patch.object(
                assisted_service,
                "_require_internal_assist",
                return_value={},
            ),
            self.assertRaises(frappe.ValidationError),
        ):
            assisted_service.create_request(service_id="SERVICE-1")
