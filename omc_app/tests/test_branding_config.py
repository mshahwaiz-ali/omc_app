from types import SimpleNamespace
from unittest.mock import call, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import branding_config


class TestBrandingConfig(FrappeTestCase):
    @patch("omc_app.api.branding_config.mobile._get_single_settings")
    @patch("omc_app.api.branding_config.mobile.get_mobile_app_config")
    def test_accent_color_is_read_from_branding_settings(self, get_mobile_app_config, get_single_settings):
        get_mobile_app_config.return_value = {
            "branding": {"company_name": "OMC House", "primary_color_family": "navy", "primaryColorFamily": "navy"}
        }
        settings = {
            "OMC Mobile Settings": {"minimum_app_version": "", "force_update": 0, "maintenance_mode": 0},
            "OMC Branding Settings": SimpleNamespace(accent_color="#AABBCC"),
        }
        get_single_settings.side_effect = lambda doctype: settings[doctype]
        result = branding_config.get_mobile_app_config()
        self.assertEqual(get_single_settings.call_args_list, [
            call("OMC Mobile Settings"), call("OMC Branding Settings"),
        ])
        self.assertEqual(result["branding"]["accent_color"], "#AABBCC")
        self.assertNotIn("primary_color_family", result["branding"])
        self.assertNotIn("primaryColorFamily", result["branding"])
        self.assertEqual(result["meta"]["minimum_app_version"], "")
        self.assertFalse(result["meta"]["force_update"])
        self.assertFalse(result["meta"]["maintenance_mode"])
        get_mobile_app_config.assert_called_once_with()

    def test_invalid_accent_color_uses_existing_default(self):
        self.assertEqual(
            branding_config._resolved_accent_color(SimpleNamespace(accent_color="not-a-color")),
            branding_config._DEFAULT_ACCENT,
        )

    def test_missing_mobile_settings_cannot_publish_enabled_config(self):
        with patch.object(branding_config.mobile, "_get_single_settings", return_value=None), \
                patch.object(branding_config.mobile, "get_mobile_app_config") as config:
            with self.assertRaises(frappe.ValidationError):
                branding_config.get_mobile_app_config()
        config.assert_not_called()

    def test_invalid_release_controls_cannot_publish_enabled_config(self):
        for controls in (
            {"minimum_app_version": "invalid", "force_update": 0, "maintenance_mode": 0},
            {"minimum_app_version": "", "force_update": 1, "maintenance_mode": 0},
        ):
            with self.subTest(controls=controls):
                with patch.object(branding_config.mobile, "_get_single_settings", return_value=controls), \
                        patch.object(branding_config.mobile, "get_mobile_app_config") as config:
                    with self.assertRaises(frappe.ValidationError):
                        branding_config.get_mobile_app_config()
                config.assert_not_called()
