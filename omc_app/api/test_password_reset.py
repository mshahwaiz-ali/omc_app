from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import password_reset


class TestPasswordReset(FrappeTestCase):
    def setUp(self):
        super().setUp()
        self.created = []
        self.test_user = "password-reset-test@example.com"

        stale_resets = frappe.get_all(
            "OMC Password Reset",
            filters={"user": self.test_user},
            pluck="name",
        )
        for name in stale_resets:
            frappe.delete_doc(
                "OMC Password Reset",
                name,
                force=True,
                ignore_permissions=True,
            )

        if not frappe.db.exists("User", self.test_user):
            user = frappe.get_doc(
                {
                    "doctype": "User",
                    "email": self.test_user,
                    "first_name": "Password Reset",
                    "enabled": 1,
                    "send_welcome_email": 0,
                    "user_type": "Website User",
                }
            )
            user.insert(ignore_permissions=True)

    def tearDown(self):
        for name in self.created:
            if frappe.db.exists("OMC Password Reset", name):
                frappe.delete_doc(
                    "OMC Password Reset",
                    name,
                    force=True,
                    ignore_permissions=True,
                )
        if frappe.db.exists("User", self.test_user):
            frappe.delete_doc(
                "User",
                self.test_user,
                force=True,
                ignore_permissions=True,
            )
        frappe.db.rollback()
        super().tearDown()

    @patch("omc_app.api.password_reset.frappe.sendmail")
    @patch("omc_app.api.password_reset.resolve_login_email")
    def test_request_reset_is_generic_and_sends_email(self, resolve, sendmail):
        resolve.return_value = self.test_user

        result = password_reset.request_reset("demo-user")

        self.assertEqual(result["message"], password_reset.GENERIC_MESSAGE)
        sendmail.assert_called_once()
        names = frappe.get_all(
            "OMC Password Reset",
            filters={"user": self.test_user},
            pluck="name",
            order_by="creation desc",
            limit=1,
        )
        self.assertTrue(names)
        self.created.extend(names)

    @patch("omc_app.api.password_reset.frappe.sendmail")
    @patch("omc_app.api.password_reset.resolve_login_email")
    def test_unknown_identifier_is_generic(self, resolve, sendmail):
        resolve.return_value = None

        result = password_reset.request_reset("unknown")

        self.assertEqual(result["message"], password_reset.GENERIC_MESSAGE)
        sendmail.assert_not_called()

    @patch("omc_app.api.password_reset.frappe.sendmail")
    @patch("omc_app.api.password_reset.resolve_login_email")
    def test_request_reset_cooldown_is_generic_and_suppresses_email(
        self,
        resolve,
        sendmail,
    ):
        resolve.return_value = self.test_user

        first = password_reset.request_reset("demo-user")
        second = password_reset.request_reset("demo-user")

        self.assertEqual(first["message"], password_reset.GENERIC_MESSAGE)
        self.assertEqual(second["message"], password_reset.GENERIC_MESSAGE)
        sendmail.assert_called_once()

        names = frappe.get_all(
            "OMC Password Reset",
            filters={"user": self.test_user},
            pluck="name",
        )
        self.assertEqual(len(names), 1)
        self.created.extend(names)

    @patch("omc_app.api.password_reset.frappe.sendmail")
    @patch("omc_app.api.password_reset.resolve_login_email")
    def test_oversized_identifier_is_generic_without_lookup(self, resolve, sendmail):
        result = password_reset.request_reset(
            "x" * (password_reset.RESET_IDENTIFIER_MAX_LENGTH + 1)
        )

        self.assertEqual(result["message"], password_reset.GENERIC_MESSAGE)
        resolve.assert_not_called()
        sendmail.assert_not_called()

    @patch("omc_app.api.password_reset.update_password")
    def test_valid_token_resets_password_once(self, update):
        token, doc = password_reset._create_reset(self.test_user)
        self.created.append(doc.name)

        first = password_reset.reset_password(
            token=token,
            new_password="new-password-123",
            confirm_password="new-password-123",
        )
        second = password_reset.reset_password(
            token=token,
            new_password="new-password-123",
            confirm_password="new-password-123",
        )

        self.assertTrue(first["ok"])
        self.assertFalse(second["ok"])
        update.assert_called_once_with(self.test_user, "new-password-123")

    def test_mismatched_passwords_are_rejected(self):
        with self.assertRaises(frappe.ValidationError):
            password_reset.reset_password(
                token="invalid",
                new_password="new-password-123",
                confirm_password="different-password",
            )
