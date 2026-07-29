from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import dashboard, mobile


class TestNotificationIntegrity(FrappeTestCase):
    @patch("omc_app.api.mobile.frappe.db.exists")
    def test_stale_supported_reference_has_no_mobile_route(self, exists):
        exists.return_value = False
        notification = SimpleNamespace(
            mobile_route="/documents/DOC-404",
            reference_doctype="OMC Service Document",
            reference_name="DOC-404",
        )
        self.assertEqual(mobile._notification_mobile_route(notification), "")

    @patch("omc_app.api.mobile.frappe.db.exists")
    def test_existing_supported_reference_keeps_route(self, exists):
        exists.return_value = True
        notification = SimpleNamespace(
            mobile_route="",
            reference_doctype="OMC Support Ticket",
            reference_name="SUP-1",
        )
        self.assertEqual(
            mobile._notification_mobile_route(notification),
            "/support-tickets/SUP-1",
        )

    @patch("omc_app.api.mobile.frappe.utils.add_to_date")
    @patch("omc_app.api.mobile.frappe.get_doc")
    @patch("omc_app.api.mobile.frappe.db.exists")
    @patch("omc_app.api.mobile._notification_preference_enabled")
    def test_canonical_creation_suppresses_exact_recent_duplicate(
        self,
        preference_enabled,
        exists,
        get_doc,
        add_to_date,
    ):
        preference_enabled.return_value = True
        add_to_date.return_value = "2026-07-29 20:00:00"
        exists.return_value = "NOTIF-1"
        existing = MagicMock()
        get_doc.return_value = existing

        result = mobile._create_customer_notification(
            customer_profile="CUST-1",
            title="Payment update",
            message="Payment received.",
            notification_type="Payment",
            reference_doctype="OMC Service Payment",
            reference_name="PAY-1",
        )

        self.assertIs(result, existing)
        self.assertEqual(exists.call_args.args[0], "OMC Notification")
        filters = exists.call_args.args[1]
        self.assertEqual(filters["customer_profile"], "CUST-1")
        self.assertEqual(filters["notification_type"], "Payment")

    @patch("omc_app.api.mobile.frappe.db.commit")
    @patch("omc_app.api.mobile.frappe.delete_doc")
    @patch("omc_app.api.mobile.frappe.get_all")
    def test_cleanup_is_bounded_and_deduplicates_overlapping_rows(
        self,
        get_all,
        delete_doc,
        commit,
    ):
        get_all.side_effect = [
            ["EXP-1", "BOTH-1"],
            ["DIS-1", "BOTH-1"],
            ["READ-1"],
        ]

        result = mobile.cleanup_notifications()

        self.assertEqual(result["total"], 4)
        self.assertEqual(delete_doc.call_count, 4)
        commit.assert_called_once_with()
        for invocation in get_all.call_args_list:
            self.assertEqual(invocation.kwargs["limit_page_length"], 500)

    @patch("omc_app.api.mobile.frappe.db.commit")
    @patch("omc_app.api.mobile.frappe.db.set_value")
    @patch("omc_app.api.mobile.frappe.get_all")
    @patch("omc_app.api.mobile._doctype_has_field")
    @patch("omc_app.api.mobile._assert_approved_customer")
    @patch("omc_app.api.mobile._can_access_internal_workspace")
    @patch("omc_app.api.mobile._current_user")
    def test_mark_all_excludes_dismissed_rows(
        self,
        current_user,
        can_access_internal,
        approved_customer,
        has_field,
        get_all,
        set_value,
        commit,
    ):
        current_user.return_value = "customer@example.com"
        can_access_internal.return_value = False
        approved_customer.return_value = SimpleNamespace(name="CUST-1")
        has_field.return_value = True
        get_all.return_value = []

        mobile.mark_all_notifications_read()

        self.assertEqual(
            get_all.call_args.kwargs["filters"]["is_dismissed"],
            0,
        )
        set_value.assert_not_called()
        commit.assert_not_called()

    def test_dashboard_unread_count_excludes_dismissed(self):
        source = Path(dashboard.__file__).read_text(encoding="utf-8")
        expected = (
            '"notifications": _count(\n'
            '            "OMC Notification",\n'
            '            {\n'
            '                **({"customer_profile": profile.name} if profile else {}),\n'
            '                "visible_to_customer": 1,\n'
            '                "is_read": 0,\n'
            '                "is_dismissed": 0,\n'
            '            },\n'
            '        ),'
        )
        self.assertIn(expected, source)
