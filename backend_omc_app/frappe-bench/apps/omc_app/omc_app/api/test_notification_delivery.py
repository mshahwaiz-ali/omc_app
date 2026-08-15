from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import notification_delivery, notification_events


class TestNotificationDelivery(FrappeTestCase):
    def test_notification_routes_reject_generic_and_external_destinations(self):
        self.assertEqual(
            notification_events.validated_mobile_route("/payments/PAY-1"),
            "/payments/PAY-1",
        )
        self.assertEqual(notification_events.validated_mobile_route("/services"), "")
        self.assertEqual(
            notification_events.validated_mobile_route("https://example.com"), ""
        )

    @patch.object(notification_delivery.frappe, "enqueue")
    def test_unconfigured_provider_never_claims_or_queues_delivery(self, enqueue):
        with patch.object(notification_delivery.frappe, "conf", {}):
            status = notification_delivery.provider_status()
            queued = notification_delivery.enqueue_notification("NOTIF-1")
        self.assertFalse(status.configured)
        self.assertFalse(status.operational)
        self.assertFalse(queued)
        enqueue.assert_not_called()

    @patch("omc_app.api.mobile._active_push_tokens_for_notification")
    @patch.object(notification_delivery.frappe.db, "set_value")
    @patch.object(notification_delivery.frappe.db, "exists", return_value=True)
    @patch.object(notification_delivery.frappe, "get_doc")
    @patch.object(notification_delivery.frappe, "get_attr")
    def test_invalid_provider_tokens_are_deactivated(
        self, get_attr, get_doc, _exists, set_value, active_tokens
    ):
        get_doc.return_value = SimpleNamespace(
            name="NOTIF-1",
            title="Update",
            message="Body",
            notification_type="Payment",
            mobile_route="/payments/PAY-1",
            reference_doctype="OMC Service Payment",
            reference_name="PAY-1",
            customer_profile="CUST-1",
            recipient_user=None,
        )
        active_tokens.return_value = [SimpleNamespace(name="TOKEN-1", token="bad")]
        adapter = MagicMock(return_value={"delivered": 0, "invalid_tokens": ["bad"]})
        get_attr.return_value = adapter
        with patch.object(
            notification_delivery.frappe,
            "conf",
            {"omc_push_provider": "provider.send"},
        ):
            result = notification_delivery.dispatch_notification("NOTIF-1")
        self.assertEqual(result["invalid_tokens"], 1)
        set_value.assert_called_once_with(
            "OMC Push Token", "TOKEN-1", "is_active", 0, update_modified=False
        )
