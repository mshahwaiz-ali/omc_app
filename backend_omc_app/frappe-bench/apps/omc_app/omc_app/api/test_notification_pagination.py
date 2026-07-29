from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import mobile


class TestNotificationPagination(FrappeTestCase):
    def test_page_values_are_clamped(self):
        self.assertEqual(
            mobile._notification_page_value(
                "bad",
                default=50,
                minimum=1,
                maximum=100,
            ),
            50,
        )
        self.assertEqual(
            mobile._notification_page_value(
                -4,
                default=0,
                minimum=0,
                maximum=100000,
            ),
            0,
        )
        self.assertEqual(
            mobile._notification_page_value(
                999,
                default=50,
                minimum=1,
                maximum=100,
            ),
            100,
        )

    @patch("omc_app.api.mobile._notification_mobile_route", return_value="")
    @patch("omc_app.api.mobile._format_datetime", return_value="now")
    @patch("omc_app.api.mobile.frappe.get_all")
    @patch("omc_app.api.mobile._doctype_has_field", return_value=True)
    @patch("omc_app.api.mobile._assert_approved_customer")
    @patch("omc_app.api.mobile._can_access_internal_workspace", return_value=False)
    @patch("omc_app.api.mobile._current_user", return_value="customer@example.com")
    def test_list_is_bounded_and_returns_pagination_metadata(
        self,
        current_user,
        internal,
        approved_customer,
        has_field,
        get_all,
        format_datetime,
        mobile_route,
    ):
        approved_customer.return_value = SimpleNamespace(name="CUST-1")
        get_all.return_value = [
            SimpleNamespace(
                name=f"NOTIF-{index}",
                title="Update",
                message="Message",
                notification_type="General",
                reference_doctype="",
                reference_name="",
                is_read=0,
                creation=None,
                read_on=None,
                mobile_route="",
            )
            for index in range(3)
        ]

        result = mobile.get_notifications(start="4", limit="2")

        self.assertEqual(len(result["notifications"]), 2)
        self.assertTrue(result["has_more"])
        self.assertEqual(result["next_start"], 6)
        self.assertEqual(result["start"], 4)
        self.assertEqual(result["limit"], 2)
        self.assertEqual(get_all.call_args.kwargs["limit_start"], 4)
        self.assertEqual(get_all.call_args.kwargs["limit_page_length"], 3)

    @patch("omc_app.api.mobile._current_user", return_value="Guest")
    def test_guest_response_keeps_pagination_contract(self, current_user):
        result = mobile.get_notifications(start="-8", limit="500")
        self.assertEqual(result["notifications"], [])
        self.assertEqual(result["start"], 0)
        self.assertEqual(result["limit"], 100)
        self.assertFalse(result["has_more"])
        self.assertIsNone(result["next_start"])
