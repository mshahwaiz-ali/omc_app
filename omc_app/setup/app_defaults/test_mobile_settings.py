from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.setup.app_defaults import mobile_settings


class TestMobileSettingsAppDefaults(FrappeTestCase):
    def _settings(self):
        return {
            "minimum_app_version": "9.0.0",
            "force_update": 0,
            "maintenance_mode": 0,
            "guest_mode_enabled": 1,
            "payments_enabled": 1,
        }

    def test_preview_is_validation_only(self):
        settings = self._settings()

        with (
            patch.object(
                mobile_settings.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                mobile_settings.frappe,
                "get_single",
                return_value=settings,
            ),
            patch.object(
                mobile_settings,
                "validate_release_controls",
                return_value={
                    "minimum_app_version": "9.0.0",
                    "force_update": False,
                    "maintenance_mode": False,
                },
            ) as validate,
        ):
            report = (
                mobile_settings
                .preview_mobile_settings()
            )

        self.assertTrue(report["safe_to_sync"])
        self.assertTrue(report["converged"])
        self.assertEqual(report["changes"], {})
        self.assertEqual(
            report["ownership"],
            "client_managed",
        )

        validate.assert_called_once_with(
            "9.0.0",
            0,
            0,
        )

    def test_invalid_release_controls_block_preview(self):
        settings = self._settings()

        with (
            patch.object(
                mobile_settings.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                mobile_settings.frappe,
                "get_single",
                return_value=settings,
            ),
            patch.object(
                mobile_settings,
                "validate_release_controls",
                side_effect=ValueError(
                    "invalid release controls"
                ),
            ),
        ):
            report = (
                mobile_settings
                .preview_mobile_settings()
            )

        self.assertFalse(report["safe_to_sync"])
        self.assertFalse(report["converged"])
        self.assertEqual(
            report["blockers"][0]["type"],
            "invalid_release_controls",
        )

    def test_missing_doctype_blocks_preview(self):
        with patch.object(
            mobile_settings.frappe.db,
            "exists",
            return_value=False,
        ):
            report = (
                mobile_settings
                .preview_mobile_settings()
            )

        self.assertFalse(report["safe_to_sync"])
        self.assertFalse(report["converged"])
        self.assertEqual(
            report["blockers"][0]["type"],
            "missing_doctype",
        )

    def test_sync_does_not_mutate_mobile_settings(self):
        preview = {
            "changes": {},
            "release_controls": {
                "minimum_app_version": "9.0.0",
                "force_update": False,
                "maintenance_mode": False,
            },
            "ownership": "client_managed",
            "blockers": [],
            "safe_to_sync": True,
            "converged": True,
        }

        validation = {
            "valid": True,
            "safe_to_sync": True,
            "changes": {},
            "release_controls": (
                preview["release_controls"]
            ),
            "ownership": "client_managed",
            "blockers": [],
        }

        with (
            patch.object(
                mobile_settings,
                "preview_mobile_settings",
                return_value=preview,
            ),
            patch.object(
                mobile_settings,
                "validate_mobile_settings",
                return_value=validation,
            ),
            patch.object(
                mobile_settings.frappe,
                "get_single",
            ) as get_single,
            patch.object(
                mobile_settings.frappe.db,
                "commit",
            ) as commit,
        ):
            result = (
                mobile_settings
                .sync_mobile_settings(
                    commit=True,
                )
            )

        self.assertEqual(
            result["changed_fields"],
            [],
        )
        self.assertEqual(
            result["ownership"],
            "client_managed",
        )
        get_single.assert_not_called()
        commit.assert_not_called()
