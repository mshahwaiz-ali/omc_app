from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import customer_profile_resolver


class TestCustomerProfileResolver(FrappeTestCase):
    def test_existing_exact_profile_link_is_reused(self):
        with (
            patch.object(
                customer_profile_resolver,
                "_profile_doctype_available",
                return_value=True,
            ),
            patch.object(
                customer_profile_resolver.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                customer_profile_resolver,
                "_linked_profile_names",
                return_value=["OMC-CUST-1"],
            ),
            patch.object(
                customer_profile_resolver,
                "_create_business_profile",
            ) as create_profile,
        ):
            result = customer_profile_resolver.resolve_for_erp_customer(
                "ERP-CUST-1",
                create_if_missing=True,
            )

        self.assertEqual(result["status"], "Resolved")
        self.assertEqual(result["profile"], "OMC-CUST-1")
        self.assertFalse(result["created"])
        create_profile.assert_not_called()

    def test_multiple_existing_profile_links_fail_closed(self):
        with (
            patch.object(
                customer_profile_resolver,
                "_profile_doctype_available",
                return_value=True,
            ),
            patch.object(
                customer_profile_resolver.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                customer_profile_resolver,
                "_linked_profile_names",
                return_value=["OMC-CUST-1", "OMC-CUST-2"],
            ),
            patch.object(
                customer_profile_resolver,
                "_create_business_profile",
            ) as create_profile,
        ):
            result = customer_profile_resolver.resolve_for_erp_customer(
                "ERP-CUST-1",
                create_if_missing=True,
            )

        self.assertEqual(result["status"], "Ambiguous")
        create_profile.assert_not_called()

    def test_explicit_omc_source_profile_is_linked_not_duplicated(self):
        profile = SimpleNamespace(
            name="OMC-CUST-SOURCE",
            linked_erpnext_customer="",
        )

        with (
            patch.object(
                customer_profile_resolver,
                "_profile_doctype_available",
                return_value=True,
            ),
            patch.object(
                customer_profile_resolver.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                customer_profile_resolver,
                "_linked_profile_names",
                return_value=[],
            ),
            patch.object(
                customer_profile_resolver,
                "_event_source_profile",
                return_value=profile,
            ),
            patch.object(
                customer_profile_resolver.erp_customer_resolver,
                "_link_profile",
            ) as link_profile,
            patch.object(
                customer_profile_resolver,
                "_create_business_profile",
            ) as create_profile,
        ):
            result = customer_profile_resolver.resolve_for_erp_customer(
                "ERP-CUST-1",
                create_if_missing=True,
            )

        self.assertEqual(result["status"], "Resolved")
        self.assertEqual(result["profile"], "OMC-CUST-SOURCE")
        link_profile.assert_called_once_with(
            profile,
            "ERP-CUST-1",
        )
        create_profile.assert_not_called()

    def test_deterministic_unlinked_profile_is_reused(self):
        profile = SimpleNamespace(
            name="OMC-CUST-EXISTING",
        )

        with (
            patch.object(
                customer_profile_resolver,
                "_profile_doctype_available",
                return_value=True,
            ),
            patch.object(
                customer_profile_resolver.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                customer_profile_resolver,
                "_linked_profile_names",
                return_value=[],
            ),
            patch.object(
                customer_profile_resolver,
                "_event_source_profile",
                return_value=None,
            ),
            patch.object(
                customer_profile_resolver,
                "_unlinked_profile_resolution",
                return_value={
                    "status": "Resolved",
                    "profile": "OMC-CUST-EXISTING",
                    "profile_candidates": ["OMC-CUST-EXISTING"],
                    "reason": "",
                },
            ),
            patch.object(
                customer_profile_resolver.frappe,
                "get_doc",
                return_value=profile,
            ),
            patch.object(
                customer_profile_resolver.erp_customer_resolver,
                "_link_profile",
            ) as link_profile,
            patch.object(
                customer_profile_resolver,
                "_create_business_profile",
            ) as create_profile,
        ):
            result = customer_profile_resolver.resolve_for_erp_customer(
                "ERP-CUST-1",
                create_if_missing=True,
            )

        self.assertEqual(result["status"], "Resolved")
        self.assertEqual(
            result["profile"],
            "OMC-CUST-EXISTING",
        )
        link_profile.assert_called_once_with(
            profile,
            "ERP-CUST-1",
        )
        create_profile.assert_not_called()

    def test_ambiguous_unlinked_identity_never_creates_profile(self):
        with (
            patch.object(
                customer_profile_resolver,
                "_profile_doctype_available",
                return_value=True,
            ),
            patch.object(
                customer_profile_resolver.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                customer_profile_resolver,
                "_linked_profile_names",
                return_value=[],
            ),
            patch.object(
                customer_profile_resolver,
                "_event_source_profile",
                return_value=None,
            ),
            patch.object(
                customer_profile_resolver,
                "_unlinked_profile_resolution",
                return_value={
                    "status": "Ambiguous",
                    "profile": "",
                    "profile_candidates": [
                        "OMC-CUST-1",
                        "OMC-CUST-2",
                    ],
                    "reason": "ambiguous",
                },
            ),
            patch.object(
                customer_profile_resolver,
                "_create_business_profile",
            ) as create_profile,
        ):
            result = customer_profile_resolver.resolve_for_erp_customer(
                "ERP-CUST-1",
                create_if_missing=True,
            )

        self.assertEqual(result["status"], "Ambiguous")
        create_profile.assert_not_called()

    def test_new_business_profile_has_no_app_identity(self):
        customer = SimpleNamespace(
            name="ERP-CUST-1",
            customer_name="Business Customer",
        )

        profile = MagicMock()
        profile.meta.has_field.return_value = True
        profile.name = "OMC-CUST-NEW"

        with patch.object(
            customer_profile_resolver.frappe,
            "new_doc",
            return_value=profile,
        ):
            result = (
                customer_profile_resolver
                ._create_business_profile(customer)
            )

        self.assertIs(result, profile)
        self.assertEqual(
            profile.linked_erpnext_customer,
            "ERP-CUST-1",
        )
        self.assertEqual(profile.full_name, "Business Customer")
        self.assertIsNone(profile.user)
        self.assertIsNone(profile.linked_app_user)
        self.assertEqual(profile.customer_status, "Active")
        self.assertEqual(profile.approval_status, "Approved")
        self.assertEqual(profile.is_active, 1)
        profile.insert.assert_called_once_with(
            ignore_permissions=True,
        )
