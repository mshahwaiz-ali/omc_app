from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import mobile


class TestPublicContentSafety(FrappeTestCase):
    def test_private_file_path_is_not_exposed(self):
        self.assertEqual(
            mobile._public_file_url("/private/files/internal-banner.png"),
            "",
        )

    def test_unknown_local_path_is_not_exposed(self):
        self.assertEqual(
            mobile._public_file_url("../../site_config.json"),
            "",
        )
        self.assertEqual(
            mobile._public_file_url("files/unclassified.png"),
            "",
        )

    @patch(
        "omc_app.api.mobile.frappe.utils.get_url",
        return_value="https://omc.local/files/banner.png",
    )
    def test_public_file_path_is_resolved(self, get_url):
        result = mobile._public_file_url("/files/banner.png")

        self.assertEqual(result, "https://omc.local/files/banner.png")
        get_url.assert_called_once_with("/files/banner.png")

    @patch(
        "omc_app.api.mobile.frappe.utils.get_url",
        return_value="https://omc.local/assets/omc_app/logo.svg",
    )
    def test_asset_path_is_resolved(self, get_url):
        result = mobile._public_file_url("/assets/omc_app/logo.svg")

        self.assertEqual(
            result,
            "https://omc.local/assets/omc_app/logo.svg",
        )

    def test_absolute_http_urls_remain_supported(self):
        self.assertEqual(
            mobile._public_file_url("https://cdn.example.com/banner.png"),
            "https://cdn.example.com/banner.png",
        )
        self.assertEqual(
            mobile._public_file_url("http://cdn.example.com/banner.png"),
            "http://cdn.example.com/banner.png",
        )
