from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import assisted_service


class TestAssistedServiceAuthority(FrappeTestCase):
    def test_duplicate_response_exposes_normalized_request_identity(self):
        active = SimpleNamespace(
            name="REQ-1",
            status="Open",
            service="SERVICE-1",
            service_title="Tax Filing",
            modified="2026-08-04 12:00:00",
        )

        response = assisted_service._duplicate_response(
            active,
            allow_parallel=False,
        )

        self.assertEqual(response["request_id"], "REQ-1")
        self.assertEqual(response["case_id"], "REQ-1")
        self.assertFalse(response["created"])
        self.assertTrue(response["duplicate"])

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
                assisted_service,
                "_manual_customer_duplicate_matches",
                return_value=[],
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

    def test_walk_in_tax_id_maps_to_cnic(self):
        manual = MagicMock()
        manual.name = "MC-1"

        with (
            patch.object(
                assisted_service,
                "_roles",
                return_value={"OMC Support Agent"},
            ),
            patch.object(
                assisted_service,
                "_manual_customer_duplicate_matches",
                return_value=[],
            ),
            patch.object(
                assisted_service.frappe,
                "new_doc",
                return_value=manual,
            ),
        ):
            assisted_service._create_manual_customer(
                "staff@example.com",
                {
                    "full_name": "Walk In Customer",
                    "phone": "03001234567",
                    "tax_id": "42101-1234567-1",
                },
            )

        self.assertEqual(manual.cnic, "4210112345671")
        self.assertEqual(manual.ntn, "")

    def test_walk_in_tax_id_maps_to_ntn(self):
        manual = MagicMock()
        manual.name = "MC-1"

        with (
            patch.object(
                assisted_service,
                "_roles",
                return_value={"OMC Support Agent"},
            ),
            patch.object(
                assisted_service,
                "_manual_customer_duplicate_matches",
                return_value=[],
            ),
            patch.object(
                assisted_service.frappe,
                "new_doc",
                return_value=manual,
            ),
        ):
            assisted_service._create_manual_customer(
                "staff@example.com",
                {
                    "full_name": "Walk In Customer",
                    "phone": "03001234567",
                    "tax_id": "1234567",
                },
            )

        self.assertEqual(manual.cnic, "")
        self.assertEqual(manual.ntn, "1234567")

    def test_walk_in_invalid_tax_id_is_rejected(self):
        with (
            patch.object(
                assisted_service,
                "_roles",
                return_value={"OMC Support Agent"},
            ),
            patch.object(
                assisted_service.frappe,
                "new_doc",
            ) as new_doc,
            self.assertRaisesRegex(
                frappe.ValidationError,
                "valid 13-digit CNIC or 7 to 9-digit NTN",
            ),
        ):
            assisted_service._create_manual_customer(
                "staff@example.com",
                {
                    "full_name": "Walk In Customer",
                    "phone": "03001234567",
                    "tax_id": "12345",
                },
            )

        new_doc.assert_not_called()

    def test_walk_in_duplicate_identity_is_rejected(self):
        with (
            patch.object(
                assisted_service,
                "_roles",
                return_value={"OMC Support Agent"},
            ),
            patch.object(
                assisted_service,
                "_manual_customer_duplicate_matches",
                return_value=["MC-EXISTING"],
            ),
            patch.object(
                assisted_service.frappe,
                "new_doc",
            ) as new_doc,
            self.assertRaises(frappe.ValidationError),
        ):
            assisted_service._create_manual_customer(
                "staff@example.com",
                {
                    "full_name": "Walk In Customer",
                    "phone": "03001234567",
                },
            )

        new_doc.assert_not_called()

    def test_manual_duplicate_matcher_checks_non_archived_identity(self):
        def get_all(_doctype, *, filters, **_kwargs):
            if "email" in filters:
                return ["MC-1"]
            return []

        with patch.object(
            assisted_service.frappe,
            "get_all",
            side_effect=get_all,
        ) as get_all:
            matches = assisted_service._manual_customer_duplicate_matches(
                mobile="",
                email="Customer@Example.com",
                cnic="",
            )

        self.assertEqual(matches, ["MC-1"])
        filters = get_all.call_args.kwargs["filters"]
        self.assertEqual(filters["email"], "customer@example.com")
        self.assertEqual(
            filters["conversion_status"],
            ["!=", "Archived"],
        )

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

    def test_customer_selection_modes_follow_role_scope(self):
        with (
            patch.object(
                assisted_service,
                "_current_user",
                return_value="consultant@example.com",
            ),
            patch.object(
                assisted_service,
                "_roles",
                return_value={"OMC Consultant"},
            ),
            patch.object(
                assisted_service,
                "_require_internal_assist",
                return_value={"can_create_service_for_customer": True},
            ),
        ):
            result = assisted_service.get_customer_selection_options()

        self.assertEqual(
            result["modes"],
            ["My Referral", "Walk-in Customer"],
        )
        self.assertTrue(result["capabilities"]["can_use_my_referrals"])
        self.assertFalse(result["capabilities"]["can_search_all_customers"])

    def test_referral_picker_is_scoped_and_consented(self):
        with (
            patch.object(
                assisted_service,
                "_current_user",
                return_value="consultant@example.com",
            ),
            patch.object(
                assisted_service,
                "_roles",
                return_value={"OMC Consultant"},
            ),
            patch.object(
                assisted_service,
                "_require_internal_assist",
                return_value={"can_create_service_for_customer": True},
            ),
            patch.object(
                assisted_service.frappe,
                "get_all",
                return_value=[],
            ) as get_all,
        ):
            assisted_service.get_customer_selection_options(
                customer_mode="My Referral",
                search="Ayesha",
            )

        filters = get_all.call_args.kwargs["filters"]
        self.assertEqual(filters["referred_by"], "consultant@example.com")
        self.assertEqual(filters["referral_assistance_consent"], 1)
        self.assertEqual(filters["is_active"], 1)

    def test_specialist_cannot_search_all_customers(self):
        with (
            patch.object(
                assisted_service,
                "_current_user",
                return_value="consultant@example.com",
            ),
            patch.object(
                assisted_service,
                "_roles",
                return_value={"OMC Consultant"},
            ),
            patch.object(
                assisted_service,
                "_require_internal_assist",
                return_value={"can_create_service_for_customer": True},
            ),
            self.assertRaises(frappe.PermissionError),
        ):
            assisted_service.get_customer_selection_options(
                customer_mode="Existing Customer"
            )

    def test_specialist_walk_in_list_is_creator_scoped(self):
        with (
            patch.object(
                assisted_service,
                "_current_user",
                return_value="support@example.com",
            ),
            patch.object(
                assisted_service,
                "_roles",
                return_value={"OMC Support Agent"},
            ),
            patch.object(
                assisted_service,
                "_require_internal_assist",
                return_value={"can_create_service_for_customer": True},
            ),
            patch.object(
                assisted_service.frappe,
                "get_all",
                return_value=[],
            ) as get_all,
        ):
            assisted_service.get_customer_selection_options(
                customer_mode="Walk-in Customer"
            )

        self.assertEqual(
            get_all.call_args.kwargs["filters"],
            {"created_by_user": "support@example.com"},
        )

    def test_manual_customer_conversion_requires_admin_role(self):
        with (
            patch.object(
                assisted_service,
                "_current_user",
                return_value="support@example.com",
            ),
            patch.object(
                assisted_service,
                "_roles",
                return_value={"OMC Support Agent"},
            ),
            self.assertRaises(frappe.PermissionError),
        ):
            assisted_service.convert_manual_customer(
                manual_customer="MC-1",
                request_name="REQ-1",
            )

    def test_manual_customer_conversion_requires_real_email(self):
        manual = SimpleNamespace(
            name="MC-1",
            full_name="Walk In Customer",
            email="",
            mobile="03001234567",
            cnic="",
            address="",
            linked_customer_profile="",
        )
        request = SimpleNamespace(
            name="REQ-1",
            manual_customer="MC-1",
        )

        def get_doc(doctype, _name):
            if doctype == "OMC Manual Customer":
                return manual
            return request

        with (
            patch.object(
                assisted_service,
                "_current_user",
                return_value="manager@example.com",
            ),
            patch.object(
                assisted_service,
                "_roles",
                return_value={"OMC Manager"},
            ),
            patch.object(
                assisted_service.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                assisted_service.frappe,
                "get_doc",
                side_effect=get_doc,
            ),
            self.assertRaises(frappe.ValidationError),
        ):
            assisted_service.convert_manual_customer(
                manual_customer="MC-1",
                request_name="REQ-1",
            )

    def test_manual_customer_conversion_waits_for_paid_activation(self):
        manual = MagicMock()
        manual.name = "MC-1"
        manual.full_name = "Walk In Customer"
        manual.email = "walkin@example.com"
        manual.mobile = "03001234567"
        manual.cnic = "4210112345671"
        manual.address = "Karachi"
        manual.linked_customer_profile = ""

        request = MagicMock()
        request.name = "REQ-1"
        request.manual_customer = "MC-1"
        request.service = "SERVICE-1"

        profile = MagicMock()
        profile.name = "OMC-CUST-1"
        profile.full_name = ""
        profile.phone = ""
        profile.cnic = ""
        profile.address = ""

        def get_doc(doctype, _name):
            return {
                "OMC Manual Customer": manual,
                "OMC Service Request": request,
            }[doctype]

        def exists(doctype, filters=None):
            if doctype == "OMC Service Payment":
                return False
            return True

        with (
            patch.object(
                assisted_service,
                "_current_user",
                return_value="manager@example.com",
            ),
            patch.object(
                assisted_service,
                "_roles",
                return_value={"OMC Manager"},
            ),
            patch.object(
                assisted_service.frappe.db,
                "exists",
                side_effect=exists,
            ),
            patch.object(
                assisted_service.frappe,
                "get_doc",
                side_effect=get_doc,
            ),
            patch.object(
                assisted_service.frappe,
                "new_doc",
                return_value=profile,
            ),
            patch.object(
                assisted_service,
                "_manual_customer_profile_matches",
                return_value=[],
            ),
            patch.object(
                assisted_service.erp_customer_resolver,
                "resolve_profile_customer",
                return_value={
                    "status": "Created",
                    "customer": "ERP-CUST-1",
                    "created": True,
                    "reason": "",
                },
            ),
        ):
            result = assisted_service.convert_manual_customer(
                manual_customer="MC-1",
                request_name="REQ-1",
            )

        self.assertEqual(result["customer_profile"], "OMC-CUST-1")
        self.assertEqual(result["erp_customer"], "ERP-CUST-1")
        self.assertEqual(result["erp_service"], "")
        self.assertEqual(result["erp_task"], "")
        self.assertEqual(result["erp_sync_status"], "")
        self.assertTrue(result["activation_pending_payment"])
        self.assertEqual(
            result["reason"],
            "Operational activation waits for confirmed payment.",
        )

        self.assertEqual(manual.verification_status, "Verified")
        self.assertEqual(manual.conversion_status, "Linked")
        self.assertEqual(
            manual.linked_customer_profile,
            "OMC-CUST-1",
        )
        self.assertEqual(request.customer_profile, "OMC-CUST-1")

        profile.insert.assert_called_once_with(ignore_permissions=True)
        profile.save.assert_called_once_with(ignore_permissions=True)
        manual.save.assert_called_once_with(ignore_permissions=True)

    def test_manual_customer_conversion_requires_cnic_or_ntn(self):
        manual = SimpleNamespace(
            name="MC-1",
            full_name="Walk In Customer",
            email="walkin@example.com",
            mobile="03001234567",
            cnic="",
            ntn="",
            address="",
            linked_customer_profile="",
        )
        request = SimpleNamespace(
            name="REQ-1",
            manual_customer="MC-1",
        )

        def get_doc(doctype, _name):
            if doctype == "OMC Manual Customer":
                return manual
            return request

        with (
            patch.object(
                assisted_service,
                "_current_user",
                return_value="manager@example.com",
            ),
            patch.object(
                assisted_service,
                "_roles",
                return_value={"OMC Manager"},
            ),
            patch.object(
                assisted_service.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                assisted_service.frappe,
                "get_doc",
                side_effect=get_doc,
            ),
            self.assertRaisesRegex(
                frappe.ValidationError,
                "CNIC or NTN is required",
            ),
        ):
            assisted_service.convert_manual_customer(
                manual_customer="MC-1",
                request_name="REQ-1",
            )
