from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import Mock, patch
import frappe
from omc_app.api import notification_channels, fcm_http


class TestNotificationDeliveryFix(TestCase):
    def test_every_category_and_independent_channels(self):
        for category, field in notification_channels.CATEGORY_FIELDS.items():
            for enabled in (0, 1):
                for inbox in (0, 1):
                    for push in (0, 1):
                        db = SimpleNamespace(get_value=Mock(return_value={field: enabled, 'in_app_notifications_enabled': inbox, 'push_notifications_enabled': push}))
                        with patch.object(frappe, 'db', db):
                            self.assertEqual(notification_channels.channels_for_customer('owned', category), (bool(enabled and inbox), bool(enabled and push)))
    def test_staff_does_not_read_customer_preferences(self):
        db = SimpleNamespace(get_value=Mock(side_effect=AssertionError))
        with patch.object(frappe, 'db', db):
            self.assertEqual(notification_channels.channels_for_customer(None, 'Task'), (True, True))
    def test_http_v1_payload_and_error_classification(self):
        response = Mock(ok=False, status_code=404, headers={})
        response.json.return_value = {"error": {"details": [{
            "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError", "errorCode": "UNREGISTERED",
        }]}}
        conf = SimpleNamespace(omc_fcm_credentials_file="/not-read", omc_fcm_project_id="project-test")
        # send() deliberately imports Google Auth lazily. Patch the actual import
        # targets, not obsolete fcm_http module attributes. No network/key reads.
        with patch.object(fcm_http, "operational", return_value=True), \
                patch.object(frappe, "conf", conf), \
                patch("google.oauth2.service_account.Credentials.from_service_account_file"), \
                patch("google.auth.transport.requests.AuthorizedSession") as session:
            transport = session.return_value.__enter__.return_value
            transport.post.return_value = response
            with self.assertRaises(fcm_http.SendFailure) as error:
                fcm_http.send("private-token", "notification", "binding")
            self.assertEqual(error.exception.code, "UNREGISTERED")
            request = transport.post.call_args.kwargs
            self.assertFalse(request["allow_redirects"])
            self.assertEqual(request["timeout"], (5, 20))
            payload = request["json"]["message"]
            self.assertEqual(payload["data"], {"notification_id": "notification", "binding_id": "binding"})
            self.assertEqual(payload["android"]["notification"]["channel_id"], "omc_updates")
            # A generic/untyped 404 must not revoke a registered token.
            response.json.return_value = {"error": {"details": [{"errorCode": "UNREGISTERED"}]}}
            with self.assertRaises(fcm_http.SendFailure) as error:
                fcm_http.send("private-token", "notification", "binding")
            self.assertNotEqual(error.exception.code, "UNREGISTERED")
            self.assertFalse(error.exception.retryable)
            response.status_code = 400
            response.json.return_value = {"error": {"status": "INVALID_ARGUMENT"}}
            with self.assertRaises(fcm_http.SendFailure) as error:
                fcm_http.send("private-token", "notification", "binding")
            self.assertNotEqual(error.exception.code, "UNREGISTERED")
            self.assertFalse(error.exception.retryable)
            response.status_code = 503
            response.headers = {"Retry-After": "120"}
            with self.assertRaises(fcm_http.SendFailure) as error:
                fcm_http.send("private-token", "notification", "binding")
            self.assertTrue(error.exception.retryable)
            self.assertEqual(error.exception.retry_after, 120)
