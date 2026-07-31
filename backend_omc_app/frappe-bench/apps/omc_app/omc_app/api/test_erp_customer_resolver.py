from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import erp_customer_resolver


class TestErpCustomerResolver(FrappeTestCase):
    def _profile(self):
        profile = SimpleNamespace(
            doctype="OMC Customer Profile",
            name="OMC-CUST-1",
            linked_erpnext_customer="",
            linked_app_user="customer@example.com",
            user="customer@example.com",
            full_name="Test Customer",
            email="customer@example.com",
            phone="03001234567",
            ntn="1234567",
            approval_status="Approved",
            is_active=1,
        )
        profile.set = MagicMock()
        return profile

    def test_valid_existing_link_is_reused(self):
        profile = self._profile()
        profile.linked_erpnext_customer = "ERP-CUST-1"

        with patch.object(
            erp_customer_resolver.frappe.db,
            "exists",
            return_value=True,
        ):
            result = erp_customer_resolver.resolve_profile_customer(profile)

        self.assertEqual(result["status"], "Resolved")
        self.assertEqual(result["customer"], "ERP-CUST-1")
        self.assertFalse(result["created"])

    def test_exact_user_match_relinks_without_creation(self):
        profile = self._profile()

        with (
            patch.object(
                erp_customer_resolver,
                "_valid_link",
                return_value="",
            ),
            patch.object(
                erp_customer_resolver,
                "_customer_matches",
                return_value=["ERP-CUST-1"],
            ),
            patch.object(
                erp_customer_resolver,
                "_link_profile",
            ) as link_profile,
            patch.object(
                erp_customer_resolver,
                "_create_customer",
            ) as create_customer,
        ):
            result = erp_customer_resolver.resolve_profile_customer(profile)

        self.assertEqual(result["customer"], "ERP-CUST-1")
        self.assertFalse(result["created"])
        link_profile.assert_called_once_with(profile, "ERP-CUST-1")
        create_customer.assert_not_called()

    def test_multiple_user_matches_are_not_guessed(self):
        profile = self._profile()

        with (
            patch.object(
                erp_customer_resolver,
                "_valid_link",
                return_value="",
            ),
            patch.object(
                erp_customer_resolver,
                "_customer_matches",
                return_value=["ERP-CUST-1", "ERP-CUST-2"],
            ),
            patch.object(
                erp_customer_resolver,
                "_create_customer",
            ) as create_customer,
        ):
            result = erp_customer_resolver.resolve_profile_customer(profile)

        self.assertEqual(result["status"], "Ambiguous")
        self.assertFalse(result["created"])
        create_customer.assert_not_called()

    def test_identity_matcher_unions_supported_customer_fields(self):
        profile = self._profile()
        customer_meta = MagicMock()
        customer_meta.get_field.side_effect = lambda fieldname: fieldname in {
            "user_link",
            "email_id",
            "mobile_no",
            "tax_id",
        }

        results = {
            "user_link": [],
            "email_id": ["ERP-CUST-1"],
            "mobile_no": ["ERP-CUST-1"],
            "tax_id": [],
        }

        def get_all(_doctype, *, filters, **_kwargs):
            fieldname = next(iter(filters))
            return results[fieldname]

        with (
            patch.object(
                erp_customer_resolver.frappe,
                "get_meta",
                return_value=customer_meta,
            ),
            patch.object(
                erp_customer_resolver.frappe,
                "get_all",
                side_effect=get_all,
            ),
        ):
            matches = erp_customer_resolver._customer_matches(
                profile,
                "customer@example.com",
            )

        self.assertEqual(matches, ["ERP-CUST-1"])

    def test_identity_matcher_stops_on_ambiguous_union(self):
        profile = self._profile()
        customer_meta = MagicMock()
        customer_meta.get_field.return_value = True

        results = {
            "user_link": ["ERP-CUST-1"],
            "email_id": ["ERP-CUST-2"],
        }

        def get_all(_doctype, *, filters, **_kwargs):
            fieldname = next(iter(filters))
            return results.get(fieldname, [])

        with (
            patch.object(
                erp_customer_resolver.frappe,
                "get_meta",
                return_value=customer_meta,
            ),
            patch.object(
                erp_customer_resolver.frappe,
                "get_all",
                side_effect=get_all,
            ),
        ):
            matches = erp_customer_resolver._customer_matches(
                profile,
                "customer@example.com",
            )

        self.assertEqual(
            matches,
            ["ERP-CUST-1", "ERP-CUST-2"],
        )

    def test_unapproved_profile_does_not_create_customer(self):
        profile = self._profile()
        profile.approval_status = "Pending Review"

        with (
            patch.object(
                erp_customer_resolver,
                "_valid_link",
                return_value="",
            ),
            patch.object(
                erp_customer_resolver,
                "_create_customer",
            ) as create_customer,
        ):
            result = erp_customer_resolver.resolve_profile_customer(profile)

        self.assertEqual(result["status"], "Pending Configuration")
        self.assertIn("not approved", result["reason"])
        create_customer.assert_not_called()

    def test_approved_profile_creates_and_links_once(self):
        profile = self._profile()
        customer = SimpleNamespace(name="ERP-CUST-NEW")

        with (
            patch.object(
                erp_customer_resolver,
                "_valid_link",
                return_value="",
            ),
            patch.object(
                erp_customer_resolver,
                "_customer_matches",
                return_value=[],
            ),
            patch.object(
                erp_customer_resolver,
                "_create_customer",
                return_value=(customer, ""),
            ) as create_customer,
            patch.object(
                erp_customer_resolver,
                "_link_profile",
            ) as link_profile,
        ):
            result = erp_customer_resolver.resolve_profile_customer(profile)

        self.assertEqual(result["status"], "Created")
        self.assertEqual(result["customer"], "ERP-CUST-NEW")
        self.assertTrue(result["created"])
        create_customer.assert_called_once_with(
            profile,
            "customer@example.com",
        )
        link_profile.assert_called_once_with(profile, "ERP-CUST-NEW")
