"""Focused mocked authority tests; execute through the local Frappe bench."""
from unittest import TestCase
from unittest.mock import patch

import frappe
from omc_app.api import push_access

BINDING = "0123456789abcdef0123456789abcdef"


class TestBoundPushAccess(TestCase):
    def setUp(self):
        self.user_patch = patch.object(frappe, "session", frappe._dict(user="customer@example.test"))
        self.user_patch.start()
        self.addCleanup(self.user_patch.stop)
        self.notification = frappe._dict(name="N-1", expires_on=None, in_app_delivery_enabled=0)

    def test_malformed_binding_is_rejected_before_query(self):
        with patch.object(frappe.db, "exists") as exists:
            with self.assertRaises(frappe.PermissionError):
                push_access.assert_bound_push_access(self.notification, "bad")
            exists.assert_not_called()

    def test_wrong_or_revoked_binding_is_rejected(self):
        with patch.object(frappe.db, "exists", return_value=False):
            with self.assertRaises(frappe.PermissionError):
                push_access.assert_bound_push_access(self.notification, BINDING)

    def test_push_only_record_uses_current_binding_and_reference_authority(self):
        with patch.object(frappe.db, "exists", return_value=True) as exists, patch(
            "omc_app.api.push_delivery._authorized", return_value=True
        ) as authorized:
            push_access.assert_bound_push_access(self.notification, BINDING)
            self.assertEqual(exists.call_args.args[1]["user"], "customer@example.test")
            self.assertEqual(exists.call_args.args[1]["binding_id"], BINDING)
            authorized.assert_called_once_with(self.notification, "customer@example.test")

    def test_revoked_reference_is_rejected(self):
        with patch.object(frappe.db, "exists", return_value=True), patch(
            "omc_app.api.push_delivery._authorized", return_value=False
        ):
            with self.assertRaises(frappe.PermissionError):
                push_access.assert_bound_push_access(self.notification, BINDING)

    def test_expired_notification_is_rejected(self):
        self.notification.expires_on = "2000-01-01 00:00:00"
        with patch.object(frappe.db, "exists", return_value=True):
            with self.assertRaises(frappe.DoesNotExistError):
                push_access.assert_bound_push_access(self.notification, BINDING)
