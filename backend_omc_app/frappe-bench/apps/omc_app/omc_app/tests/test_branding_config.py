from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import branding_config


class TestBrandingConfig(FrappeTestCase):
    @patch("omc_app.api.branding_config.mobile._get_single_settings")
    @patch("omc_app.api.branding_config.mobile.get_mobile_app_config")
    def test_accent_color_is_read_from_branding_settings(
        self,
        get_mobile_app_config,
        get_single_settings,
    ):
        get_mobile_app_config.return_value = {
            "branding": {
                "company_name": "OMC House",
                "primary_color_family": "navy",
                "primaryColorFamily": "navy",
            }
        }
        get_single_settings.return_value = SimpleNamespace(accent_color="#AABBCC")

        result = branding_config.get_mobile_app_config()

        get_single_settings.assert_called_once_with("OMC Branding Settings")
        self.assertEqual(result["branding"]["accent_color"], "#AABBCC")
        self.assertNotIn("primary_color_family", result["branding"])
        self.assertNotIn("primaryColorFamily", result["branding"])

    def test_invalid_accent_color_uses_existing_default(self):
        settings = SimpleNamespace(accent_color="not-a-color")

        self.assertEqual(
            branding_config._resolved_accent_color(settings),
            branding_config._DEFAULT_ACCENT,
        )
