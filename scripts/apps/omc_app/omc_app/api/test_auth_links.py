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

    def test_verified_https_links_target_production_app_routes(self):
        self.assertEqual(
            auth_links.verification_links("verify token")["universal_url"],
            "https://erp.omchouse.com/app/verify-email?token=verify+token",
        )
        self.assertEqual(
            auth_links.password_reset_links("reset-token")["universal_url"],
            "https://erp.omchouse.com/app/reset-password?token=reset-token",
        )

    @patch("omc_app.api.auth_links.get_url")
    def test_web_link_uses_frappe_origin_by_default(self, get_url):
        expected_path = (
            "/api/method/omc_app.api.pending_registration."
            "verify_registration_web?token=abc"
        )
        get_url.return_value = f"https://example.test{expected_path}"

        links = auth_links.verification_links("abc")

        self.assertEqual(
            links["web_url"],
            f"https://example.test{expected_path}",
        )
        get_url.assert_called_once_with(expected_path)

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
