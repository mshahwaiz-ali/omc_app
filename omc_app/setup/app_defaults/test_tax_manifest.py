from unittest import TestCase

from omc_app.setup.app_defaults.tax_manifest import (
    calculate_schedule_tax,
    surcharge_rate_for,
    tax_year_spec,
    validate_tax_manifest,
)


class TestTaxManifest(TestCase):
    def test_manifest_is_complete_and_valid(self):
        report = validate_tax_manifest()
        self.assertTrue(report["valid"])
        self.assertEqual(report["tax_years"], 7)
        self.assertEqual(report["income_types"], 3)
        self.assertEqual(report["default_tax_year"], "2026-27")

    def test_tax_year_2021_salary_schedule_boundary(self):
        year = tax_year_spec("2020-21")
        self.assertIsNotNone(year)
        self.assertEqual(calculate_schedule_tax(600_000, year.salary_slabs), 0)
        self.assertEqual(calculate_schedule_tax(1_200_000, year.salary_slabs), 30_000)

    def test_tax_year_2021_non_salaried_threshold_is_400k(self):
        year = tax_year_spec("2020-21")
        self.assertIsNotNone(year)
        self.assertEqual(calculate_schedule_tax(400_000, year.non_salaried_slabs), 0)
        self.assertEqual(calculate_schedule_tax(600_000, year.non_salaried_slabs), 10_000)

    def test_tax_year_2023_salary_top_boundary(self):
        year = tax_year_spec("2022-23")
        self.assertIsNotNone(year)
        self.assertEqual(calculate_schedule_tax(12_000_000, year.salary_slabs), 2_955_000)

    def test_tax_year_2027_salary_restructure_is_continuous(self):
        year = tax_year_spec("2026-27")
        self.assertIsNotNone(year)
        self.assertEqual(calculate_schedule_tax(5_600_000, year.salary_slabs), 976_000)
        self.assertEqual(calculate_schedule_tax(7_000_000, year.salary_slabs), 1_424_000)

    def test_section_4ab_surcharge_rates(self):
        self.assertEqual(surcharge_rate_for("2024-25", "Salary", 10_000_000), 0)
        self.assertEqual(surcharge_rate_for("2024-25", "Salary", 10_000_001), 10)
        self.assertEqual(surcharge_rate_for("2025-26", "Salary", 10_000_001), 9)
        self.assertEqual(surcharge_rate_for("2025-26", "Business", 10_000_001), 10)
        self.assertEqual(surcharge_rate_for("2026-27", "Salary", 10_000_001), 0)
        self.assertEqual(surcharge_rate_for("2026-27", "Rental", 10_000_001), 10)
