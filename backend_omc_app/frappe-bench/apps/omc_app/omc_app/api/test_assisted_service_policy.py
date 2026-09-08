from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import assisted_service_policy


class TestAssistedServicePolicy(FrappeTestCase):
    def test_selection_filters_retired_modes_and_preserves_active_capabilities(self):
        backend_response = {
            "modes": ["My Referral", "Existing Customer", "Walk-in Customer"],
            "items": [],
            "capabilities": {
                "can_create_service_for_customer": True,
                "can_use_walk_in_customers": True,
            },
        }

        with patch.object(
            assisted_service_policy.assisted_service,
            "get_customer_selection_options",
            return_value=backend_response,
        ):
            result = assisted_service_policy.get_customer_selection_options()

        self.assertEqual(result["modes"], ["My Referral", "Existing Customer"])
        self.assertTrue(result["capabilities"]["can_use_my_referrals"])
        self.assertTrue(result["capabilities"]["can_search_all_customers"])
        self.assertNotIn("can_use_walk_in_customers", result["capabilities"])

    def test_retired_walk_in_mode_is_rejected_before_low_level_lookup(self):
        with (
            patch.object(
                assisted_service_policy.assisted_service,
                "get_customer_selection_options",
            ) as lookup,
            self.assertRaises(frappe.PermissionError),
        ):
            assisted_service_policy.get_customer_selection_options(
                customer_mode="Walk-in Customer"
            )

        lookup.assert_not_called()

    def test_existing_customer_mode_is_forwarded(self):
        backend_response = {
            "modes": ["Existing Customer"],
            "items": [],
            "capabilities": {},
        }
        with patch.object(
            assisted_service_policy.assisted_service,
            "get_customer_selection_options",
            return_value=backend_response,
        ) as lookup:
            result = assisted_service_policy.get_customer_selection_options(
                customer_mode="Existing Customer",
                search="Ali",
                limit_start=10,
                limit_page_length=25,
            )

        lookup.assert_called_once_with(
            customer_mode="Existing Customer",
            search="Ali",
            limit_start=10,
            limit_page_length=25,
        )
        self.assertEqual(result["modes"], ["Existing Customer"])
        self.assertTrue(result["capabilities"]["can_search_all_customers"])
