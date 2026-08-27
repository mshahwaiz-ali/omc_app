from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import auth_login


class TestMultiIdentifierLogin(FrappeTestCase):
    @patch("omc_app.api.auth_login.frappe.get_all")
    @patch("omc_app.api.auth_login.frappe.db.get_value")
    def test_email_identifier_resolves_one_enabled_user(self, get_value, get_all):
        get_value.return_value = None
        get_all.side_effect = [["person@example.com"], []]

        result = auth_login.resolve_login_email(" Person@Example.com ")

        self.assertEqual(result, "person@example.com")
        self.assertEqual(
            get_value.call_args.args,
            (
                "User",
                {"name": "Person@Example.com", "enabled": 1},
                "name",
            ),
        )

    @patch("omc_app.api.auth_login._profile_users_by_field")
    @patch("omc_app.api.auth_login._enabled_user_name", return_value=None)
    def test_cnic_identifier_uses_normalized_digits(self, _enabled_user, profile_users):
        profile_users.side_effect = [set(), {"person@example.com"}]

        result = auth_login.resolve_login_email("35202-1234567-1")

        self.assertEqual(result, "person@example.com")
        self.assertEqual(
            profile_users.call_args_list[1].args,
            ("cnic", ("3520212345671",)),
        )

    @patch("omc_app.api.auth_login._profile_users_by_field")
    @patch("omc_app.api.auth_login._enabled_user_name", return_value=None)
    def test_ambiguous_cnic_is_rejected(self, _enabled_user, profile_users):
        profile_users.side_effect = [
            set(),
            {"first@example.com", "second@example.com"},
        ]

        result = auth_login.resolve_login_email("35202-1234567-1")

        self.assertIsNone(result)

    @patch("omc_app.api.auth_login._profile_users_by_field")
    @patch("omc_app.api.auth_login._enabled_user_name", return_value=None)
    def test_ambiguous_mobile_across_profile_fields_is_rejected(
        self,
        _enabled_user,
        profile_users,
    ):
        profile_users.side_effect = [
            set(),
            {"first@example.com"},
            {"second@example.com"},
            set(),
        ]

        result = auth_login.resolve_login_email("0300-1234567")

        self.assertIsNone(result)

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

    @patch("omc_app.api.auth_login.security.clear_actor_rate_limit", return_value=None)
    @patch("omc_app.api.auth_login.security.enforce_rate_limit", return_value=None)
    @patch("omc_app.api.auth_login.LoginManager")
    @patch("omc_app.api.auth_login.resolve_login_email")
    def test_login_authenticates_canonical_email(
        self,
        resolve,
        manager_type,
        _rate_limit,
        clear_rate_limit,
    ):
        resolve.return_value = "person@example.com"
        manager = MagicMock()
        manager_type.return_value = manager

        with patch.object(
            frappe.local,
            "session",
            MagicMock(user="person@example.com"),
        ):
            result = auth_login.login(
                identifier="demo-user",
                password="correct-password",
            )

        manager.authenticate.assert_called_once_with(
            user="person@example.com",
            pwd="correct-password",
        )
        manager.post_login.assert_called_once_with()
        clear_rate_limit.assert_called_once_with("login", actor="demo-user")
        self.assertEqual(result["email"], "person@example.com")

    @patch("omc_app.api.auth_login.security.enforce_rate_limit", return_value=None)
    @patch("omc_app.api.auth_login.resolve_login_email")
    def test_unknown_identifier_uses_generic_error(self, resolve, _rate_limit):
        resolve.return_value = None

        with self.assertRaisesRegex(
            frappe.AuthenticationError,
            auth_login.GENERIC_LOGIN_ERROR,
        ):
            auth_login.login(identifier="unknown-user", password="secret")

    @patch("omc_app.api.auth_login.security.enforce_rate_limit", return_value=None)
    @patch("omc_app.api.auth_login.frappe.log_error")
    @patch("omc_app.api.auth_login.resolve_login_email")
    def test_unexpected_login_failure_uses_generic_error(
        self,
        resolve,
        log_error,
        _rate_limit,
    ):
        resolve.side_effect = RuntimeError("internal lookup detail")

        with self.assertRaisesRegex(
            frappe.AuthenticationError,
            auth_login.GENERIC_LOGIN_ERROR,
        ):
            auth_login.login(identifier="person@example.com", password="secret")

        log_error.assert_called_once()
