from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import tax_calculator


class TestTaxCalculatorResilience(FrappeTestCase):
    def test_missing_settings_returns_configuration_state(self):
        with patch.object(
            tax_calculator,
            "_get_settings",
            return_value={"_configuration_error": True},
        ):
            result = tax_calculator.get_tax_calculator_config()

        self.assertFalse(result["enabled"])
        self.assertEqual(result["reason"], "missing_settings")
        self.assertIn("setup is incomplete", result["message"].lower())

    def test_missing_tax_year_returns_configuration_state(self):
        settings = {
            "calculator_enabled": 1,
            "allow_guest_calculation": 1,
        }
        with (
            patch.object(tax_calculator, "_get_settings", return_value=settings),
            patch.object(tax_calculator, "_current_user", return_value="Guest"),
            patch.object(tax_calculator, "_get_tax_year", return_value=None),
        ):
            result = tax_calculator.get_tax_calculator_config()

        self.assertFalse(result["enabled"])
        self.assertEqual(result["reason"], "missing_tax_year")
        self.assertIn("no active tax year", result["message"].lower())

    def test_invalid_slab_range_is_rejected(self):
        slab = SimpleNamespace(
            from_amount=100000,
            to_amount=50000,
            rate_percent=10,
            amount_over=100000,
        )

        with self.assertRaises(frappe.ValidationError):
            tax_calculator._validate_slab_configuration(slab)

    def test_invalid_slab_rate_is_rejected(self):
        slab = SimpleNamespace(
            from_amount=0,
            to_amount=100000,
            rate_percent=120,
            amount_over=0,
        )

        with self.assertRaises(frappe.ValidationError):
            tax_calculator._validate_slab_configuration(slab)
