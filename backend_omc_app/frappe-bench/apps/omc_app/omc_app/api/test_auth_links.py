from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import auth_links


class TestAuthLinks(FrappeTestCase):
    def test_verification_app_link_targets_flutter_route(self):
        links = auth_links.verification_links("token with spaces")

        self.assertEqual(
            links["app_url"],
            "omchouse://auth/verify-email?token=token+with+spaces",
        )

    def test_reset_app_link_targets_flutter_route(self):
        links = auth_links.password_reset_links("reset-token")

        self.assertEqual(
            links["app_url"],
            "omchouse://auth/reset-password?token=reset-token",
        )

    @patch("omc_app.api.auth_links.get_url")
    def test_web_link_uses_frappe_origin_by_default(self, get_url):
        get_url.return_value = "https://example.test/verify-email?token=abc"

        links = auth_links.verification_links("abc")

        self.assertEqual(
            links["web_url"],
            "https://example.test/verify-email?token=abc",
        )
        get_url.assert_called_once_with("/verify-email?token=abc")

    def test_web_link_can_use_configured_flutter_origin(self):
        original = frappe.conf.get(auth_links.WEB_BASE_URL_CONFIG_KEY)
        frappe.conf[auth_links.WEB_BASE_URL_CONFIG_KEY] = (
            "https://app.example.test/auth/"
        )
        try:
            links = auth_links.password_reset_links("abc")
        finally:
            if original is None:
                frappe.conf.pop(auth_links.WEB_BASE_URL_CONFIG_KEY, None)
            else:
                frappe.conf[auth_links.WEB_BASE_URL_CONFIG_KEY] = original

        self.assertEqual(
            links["web_url"],
            "https://app.example.test/auth/reset-password?token=abc",
        )
