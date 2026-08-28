from unittest import TestCase

from omc_app.api.tax_calculator_mutations import TAX_SERVICE_IDS


class TestTaxServiceMapping(TestCase):
    def test_income_types_use_canonical_active_catalogue_service_ids(self):
        self.assertEqual(
            TAX_SERVICE_IDS,
            {
                "salary": "salaried-tax-filing",
                "business": "business-tax-filing",
                "rental": "other-sources",
            },
        )

    def test_mapping_does_not_accept_arbitrary_income_types(self):
        self.assertNotIn("company", TAX_SERVICE_IDS)
        self.assertNotIn("aop", TAX_SERVICE_IDS)
