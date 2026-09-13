from types import SimpleNamespace
import unittest
from unittest.mock import patch

import frappe

from omc_app.api import payment_accounting


class TestPaymentAccountingItemSafety(unittest.TestCase):
    def _request(self):
        return SimpleNamespace(service="test-service", tax_amount=0)

    def _service(self):
        return SimpleNamespace(
            name="test-service",
            erp_invoice_item="Test Service Item",
            erp_sales_taxes_and_charges_template=None,
        )

    def test_service_accounting_config_revalidates_invoice_item_at_runtime(self):
        with (
            patch.object(frappe.db, "exists", return_value=True),
            patch.object(frappe, "get_doc", return_value=self._service()),
            patch.object(payment_accounting, "flt", return_value=0.0),
            patch.object(payment_accounting, "assert_valid_invoice_item") as validate_item,
        ):
            service, invoice_item, tax_template = payment_accounting._service_accounting_config(
                self._request()
            )

        validate_item.assert_called_once_with("Test Service Item")
        self.assertEqual(service.name, "test-service")
        self.assertEqual(invoice_item, "Test Service Item")
        self.assertEqual(tax_template, "")

    def test_runtime_invoice_item_validation_failure_blocks_payment_preflight(self):
        with (
            patch.object(frappe.db, "exists", return_value=True),
            patch.object(frappe, "get_doc", return_value=self._service()),
            patch.object(
                payment_accounting,
                "assert_valid_invoice_item",
                side_effect=frappe.ValidationError(
                    "ERP Invoice Item must be a non-stock sales item."
                ),
            ),
        ):
            with self.assertRaises(frappe.ValidationError):
                payment_accounting._service_accounting_config(self._request())
