from types import SimpleNamespace
from unittest import TestCase

from omc_app.api.tax_calculator import _section_4ab_surcharge


class TestSection4ABSurcharge(TestCase):
    def _year(self, salary=10, non_salaried=10):
        return SimpleNamespace(
            section_4ab_threshold=10_000_000,
            salary_surcharge_percent=salary,
            non_salaried_surcharge_percent=non_salaried,
        )

    def test_threshold_is_strictly_exceeded(self):
        result = _section_4ab_surcharge(
            self._year(),
            "Salary",
            10_000_000,
            2_000_000,
        )
        self.assertEqual(result["amount"], 0)
        self.assertEqual(result["rate_percent"], 0)

    def test_salary_surcharge_applies_to_base_income_tax(self):
        result = _section_4ab_surcharge(
            self._year(salary=9),
            "Salary",
            10_000_001,
            2_000_000,
        )
        self.assertEqual(result["rate_percent"], 9)
        self.assertEqual(result["amount"], 180_000)

    def test_non_salaried_surcharge_is_used_for_business_and_rental(self):
        for income_type in ("Business", "Rental"):
            result = _section_4ab_surcharge(
                self._year(non_salaried=10),
                income_type,
                12_000_000,
                3_000_000,
            )
            self.assertEqual(result["rate_percent"], 10)
            self.assertEqual(result["amount"], 300_000)

    def test_salary_surcharge_can_be_removed_without_affecting_non_salaried(self):
        year = self._year(salary=0, non_salaried=10)
        salary = _section_4ab_surcharge(year, "Salary", 12_000_000, 3_000_000)
        business = _section_4ab_surcharge(year, "Business", 12_000_000, 3_000_000)
        self.assertEqual(salary["amount"], 0)
        self.assertEqual(business["amount"], 300_000)
