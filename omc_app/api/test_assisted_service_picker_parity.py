from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import assisted_service


class TestAssistedServicePickerParity(FrappeTestCase):
    def test_existing_customer_picker_uses_erp_backed_profiles_without_account_gate(self):
        calls = []

        def get_all(doctype, **kwargs):
            calls.append((doctype, kwargs))

            if doctype == "OMC Customer Profile":
                self.assertEqual(
                    kwargs["filters"],
                    {
                        "is_active": 1,
                        "linked_erpnext_customer": ["!=", ""],
                    },
                )
                self.assertIn(
                    "linked_erpnext_customer",
                    kwargs["fields"],
                )
                return []

            self.fail(f"Unexpected doctype: {doctype}")

        with (
            patch.object(
                assisted_service,
                "_current_user",
                return_value="admin@example.com",
            ),
            patch.object(
                assisted_service,
                "_require_internal_assist",
                return_value={
                    "can_create_service_for_customer": True,
                    "can_view_all_customers": True,
                },
            ),
            patch.object(
                assisted_service.frappe,
                "get_all",
                side_effect=get_all,
            ),
        ):
            result = assisted_service.get_customer_selection_options(
                customer_mode="Existing Customer",
            )

        self.assertEqual(result["items"], [])
        self.assertEqual(
            [doctype for doctype, _ in calls],
            ["OMC Customer Profile"],
        )

    def test_accountless_business_profile_is_serviceable(self):
        profile = type(
            "Profile",
            (),
            {
                "name": "PROFILE-BUSINESS-ONLY",
                "linked_erpnext_customer": "ERP-CUST-1",
            },
        )()

        with (
            patch.object(
                assisted_service.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                assisted_service.frappe,
                "get_all",
                return_value=[],
            ),
        ):
            customer = assisted_service._profile_erp_customer(profile)
            account = assisted_service._request_account_for_profile(
                profile,
                erp_customer=customer,
            )

        self.assertEqual(customer, "ERP-CUST-1")
        self.assertIsNone(account)
