from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import branding_config, mobile


class _Meta:
    def __init__(self, has_field=True):
        self._has_field = has_field

    def has_field(self, fieldname):
        return self._has_field


def _settings_doc(has_field=True):
    return SimpleNamespace(
        doctype="OMC Mobile Settings",
        meta=_Meta(has_field=has_field),
    )


class TestMobileConfigSettingsBool(FrappeTestCase):
    def test_saved_one_is_true_and_read_uncached(self):
        doc = _settings_doc()

        with patch.object(
            mobile.frappe.db,
            "get_single_value",
            return_value=1,
        ) as get_single_value:
            result = mobile._settings_bool(
                doc,
                "internal_workspace_enabled",
                False,
            )

        self.assertTrue(result)
        get_single_value.assert_called_once_with(
            "OMC Mobile Settings",
            "internal_workspace_enabled",
            cache=False,
        )

    def test_saved_zero_is_false(self):
        with patch.object(
            mobile.frappe.db,
            "get_single_value",
            return_value=0,
        ):
            self.assertFalse(
                mobile._settings_bool(
                    _settings_doc(),
                    "internal_workspace_enabled",
                    True,
                )
            )

    def test_truthy_and_falsey_strings_follow_existing_contract(self):
        truthy = ("1", "true", "TRUE", " yes ", "on", "enabled")
        falsey = ("0", "false", "no", "off", "disabled", "")

        for value in truthy:
            with self.subTest(value=value), patch.object(
                mobile.frappe.db,
                "get_single_value",
                return_value=value,
            ):
                self.assertTrue(
                    mobile._settings_bool(
                        _settings_doc(),
                        "internal_workspace_enabled",
                        False,
                    )
                )

        for value in falsey:
            with self.subTest(value=value), patch.object(
                mobile.frappe.db,
                "get_single_value",
                return_value=value,
            ):
                self.assertFalse(
                    mobile._settings_bool(
                        _settings_doc(),
                        "internal_workspace_enabled",
                        True,
                    )
                )

    def test_missing_saved_value_uses_code_default(self):
        with patch.object(
            mobile.frappe.db,
            "get_single_value",
            return_value=None,
        ):
            self.assertTrue(
                mobile._settings_bool(
                    _settings_doc(),
                    "internal_workspace_enabled",
                    True,
                )
            )
            self.assertFalse(
                mobile._settings_bool(
                    _settings_doc(),
                    "internal_workspace_enabled",
                    False,
                )
            )

    def test_database_read_error_uses_safe_default(self):
        with patch.object(
            mobile.frappe.db,
            "get_single_value",
            side_effect=RuntimeError("read failed"),
        ):
            self.assertFalse(
                mobile._settings_bool(
                    _settings_doc(),
                    "internal_workspace_enabled",
                    False,
                )
            )
            self.assertTrue(
                mobile._settings_bool(
                    _settings_doc(),
                    "internal_workspace_enabled",
                    True,
                )
            )

    def test_missing_field_does_not_read_database(self):
        with patch.object(
            mobile.frappe.db,
            "get_single_value",
        ) as get_single_value:
            result = mobile._settings_bool(
                _settings_doc(has_field=False),
                "internal_workspace_enabled",
                True,
            )

        self.assertTrue(result)
        get_single_value.assert_not_called()

    def test_branding_wrapper_preserves_internal_workspace_feature(self):
        mobile_settings = {
            "minimum_app_version": "",
            "force_update": 0,
            "maintenance_mode": 0,
        }
        branding_settings = SimpleNamespace(accent_color="#AABBCC")

        def settings_for(doctype):
            if doctype == "OMC Mobile Settings":
                return mobile_settings
            if doctype == "OMC Branding Settings":
                return branding_settings
            raise AssertionError(f"Unexpected settings doctype: {doctype}")

        with patch.object(
            branding_config.mobile,
            "_get_single_settings",
            side_effect=settings_for,
        ), patch.object(
            branding_config.mobile,
            "get_mobile_app_config",
            return_value={
                "features": {
                    "internal_workspace_enabled": True,
                },
                "branding": {},
            },
        ):
            result = branding_config.get_mobile_app_config()

        self.assertTrue(
            result["features"]["internal_workspace_enabled"]
        )


