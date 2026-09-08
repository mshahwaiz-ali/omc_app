"""Pure control validation tests; no business records, Redis or provider calls."""
import unittest

from omc_app.api.mobile_release_controls import validate_release_controls


class TestMobileReleaseControls(unittest.TestCase):
    def test_unset_controls_do_not_enable_any_gate(self):
        self.assertEqual(validate_release_controls(), {
            "minimum_app_version": "", "force_update": False, "maintenance_mode": False,
        })

    def test_valid_versions_and_build_metadata_are_retained(self):
        for version in ("9.0.0", "9.10.0", "9.0.0-rc.1", "9.0.0+13", "9.0.0-rc.1+13"):
            with self.subTest(version=version):
                self.assertEqual(validate_release_controls(version)["minimum_app_version"], version)

    def test_invalid_versions_are_rejected(self):
        for version in ("9.0", "latest", "v9.0.0", "09.0.0", "9.0.0-01", "9.0.0+", "9.0.0\nunsafe", 9):
            with self.subTest(version=version), self.assertRaises(ValueError):
                validate_release_controls(version)

    def test_force_update_requires_minimum(self):
        with self.assertRaises(ValueError):
            validate_release_controls("", 1)

    def test_optional_minimum_is_allowed(self):
        self.assertFalse(validate_release_controls("9.10.0", 0)["force_update"])

    def test_maintenance_does_not_depend_on_a_version(self):
        self.assertTrue(validate_release_controls("", 0, "1")["maintenance_mode"])

    def test_false_string_is_not_truthy(self):
        self.assertFalse(validate_release_controls("9.0.0", "false", "0")["force_update"])

    def test_malformed_flags_fail_closed(self):
        for value in ("invalid", 2, [], {}, 1.0):
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_release_controls("9.0.0", value)


if __name__ == '__main__':
    unittest.main()
