from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import auth_login


class TestMultiIdentifierLogin(FrappeTestCase):
    @patch("omc_app.api.auth_login.frappe.db.get_value")
    def test_email_identifier_resolves_enabled_user(self, get_value):
        get_value.side_effect = (
            None,
            "person@example.com",
        )

        result = auth_login.resolve_login_email(" Person@Example.com ")

        self.assertEqual(result, "person@example.com")
        self.assertEqual(
            get_value.call_args_list[0].args,
            (
                "User",
                {"name": "Person@Example.com", "enabled": 1},
                "name",
            ),
        )
        self.assertEqual(
            get_value.call_args_list[1].args,
            (
                "User",
                {"email": "person@example.com", "enabled": 1},
                "name",
            ),
        )

    @patch("omc_app.api.auth_login._enabled_user_name")
    @patch("omc_app.api.auth_login._profile_email_by_field")
    def test_cnic_identifier_uses_normalized_digits(
        self,
        profile_lookup,
        enabled_user,
    ):
        profile_lookup.side_effect = (
            None,
            "person@example.com",
        )
        enabled_user.side_effect = (
            None,
            None,
            "person@example.com",
        )

        result = auth_login.resolve_login_email("35202-1234567-1")

        self.assertEqual(result, "person@example.com")
        self.assertEqual(
            profile_lookup.call_args_list[1].args,
            ("cnic", ("3520212345671",)),
        )
        self.assertEqual(
            enabled_user.call_args_list[2].args,
            ("person@example.com",),
        )

    def test_mobile_candidates_cover_pakistan_formats(self):
        self.assertEqual(
            auth_login._mobile_candidates("0300-1234567"),
            (
                "+923001234567",
                "923001234567",
                "03001234567",
                "3001234567",
            ),
        )

    @patch("omc_app.api.auth_login.LoginManager")
    @patch("omc_app.api.auth_login.resolve_login_email")
    def test_login_authenticates_canonical_email(self, resolve, manager_type):
        resolve.return_value = "person@example.com"
        manager = MagicMock()
        manager_type.return_value = manager

        with patch.object(frappe.local, "session", MagicMock(user="person@example.com")):
            result = auth_login.login(
                identifier="demo-user",
                password="correct-password",
            )

        manager.authenticate.assert_called_once_with(
            user="person@example.com",
            pwd="correct-password",
        )
        manager.post_login.assert_called_once_with()
        self.assertEqual(result["email"], "person@example.com")

    @patch("omc_app.api.auth_login.resolve_login_email")
    def test_unknown_identifier_uses_generic_error(self, resolve):
        resolve.return_value = None

        with self.assertRaises(frappe.AuthenticationError):
            auth_login.login(identifier="unknown-user", password="secret")

    @patch("omc_app.api.auth_login.frappe.log_error")
    @patch("omc_app.api.auth_login.resolve_login_email")
    def test_unexpected_login_failure_uses_generic_error(self, resolve, log_error):
        resolve.side_effect = RuntimeError("internal lookup detail")

        with self.assertRaisesRegex(
            frappe.AuthenticationError,
            auth_login.GENERIC_LOGIN_ERROR,
        ):
            auth_login.login(identifier="person@example.com", password="secret")

        log_error.assert_called_once()
