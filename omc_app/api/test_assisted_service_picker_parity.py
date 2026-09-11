from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import assisted_service


class TestAssistedServicePickerParity(FrappeTestCase):
    def test_existing_customer_picker_uses_submit_eligible_accounts(self):
        calls = []

        def get_all(doctype, **kwargs):
            calls.append((doctype, kwargs))

            if doctype == "OMC Customer Account":
                self.assertEqual(
                    kwargs["filters"],
                    {
                        "identity_proof_status": "Verified",
                        "account_link_status": "Linked",
                        "service_access_status": "Approved",
                    },
                )
                return ["OMC-CUST-APPROVED"]

            if doctype == "OMC Customer Profile":
                self.assertEqual(
                    kwargs["filters"]["name"],
                    ["in", ["OMC-CUST-APPROVED"]],
                )
                self.assertEqual(
                    kwargs["filters"]["is_active"],
                    1,
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
            ["OMC Customer Account", "OMC Customer Profile"],
        )
