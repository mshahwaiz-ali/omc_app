from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import erp_finance_adapter


class TestERPFinanceAdapter(FrappeTestCase):
    def test_validate_configuration_accepts_valid_setup(self):
        settings = SimpleNamespace(
            erp_company="Testing-P1",
            erp_service_item="OMC-SERVICE",
            erp_default_payment_mode="Cash",
        )

        item = SimpleNamespace(
            disabled=0,
            is_stock_item=0,
        )

        with (
            patch.object(
                erp_finance_adapter.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                erp_finance_adapter.frappe,
                "get_doc",
                return_value=item,
            ),
        ):
            result = erp_finance_adapter._validate_configuration(settings)

        self.assertEqual(result["company"], "Testing-P1")
        self.assertEqual(result["item_code"], "OMC-SERVICE")
        self.assertEqual(result["mode_of_payment"], "Cash")

    def test_mode_account_fails_when_payment_mode_has_no_account(self):
        with (
            patch.object(
                erp_finance_adapter,
                "get_default_bank_cash_account",
                return_value=None,
            ),
            self.assertRaises(frappe.ValidationError),
        ):
            erp_finance_adapter._mode_account(
                "Testing-P1",
                "Wire Transfer",
            )

    def test_resolve_customer_reuses_existing_erp_customer(self):
        request = SimpleNamespace(
            name="OMC-SR-1",
            erp_customer="CUST-1",
        )

        with patch.object(
            erp_finance_adapter.frappe.db,
            "exists",
            return_value=True,
        ):
            customer = erp_finance_adapter._resolve_customer(request)

        self.assertEqual(customer, "CUST-1")

    def test_existing_invoice_is_reused(self):
        payment = SimpleNamespace(
            erp_sales_invoice="SINV-1",
        )
        invoice = SimpleNamespace(
            name="SINV-1",
            docstatus=1,
        )

        with (
            patch.object(
                erp_finance_adapter.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                erp_finance_adapter.frappe,
                "get_doc",
                return_value=invoice,
            ),
        ):
            result = erp_finance_adapter._existing_invoice(payment)

        self.assertIs(result, invoice)

    def test_existing_payment_entry_is_reused(self):
        payment = SimpleNamespace(
            erp_payment_entry="ACC-PAY-1",
        )
        payment_entry = SimpleNamespace(
            name="ACC-PAY-1",
            docstatus=1,
        )

        with (
            patch.object(
                erp_finance_adapter.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                erp_finance_adapter.frappe,
                "get_doc",
                return_value=payment_entry,
            ),
        ):
            result = erp_finance_adapter._existing_payment_entry(payment)

        self.assertIs(result, payment_entry)

    def test_create_payment_entry_uses_native_erp_payment_generator(self):
        payment = SimpleNamespace(
            name="OMC-PAY-1",
            service_request="OMC-SR-1",
            payment_reference="BANK-REF-1",
            erp_payment_entry="",
        )
        invoice = SimpleNamespace(name="SINV-1")

        generated = MagicMock()
        generated.name = "ACC-PAY-1"

        config = {
            "company": "Testing-P1",
            "mode_of_payment": "Cash",
        }

        with (
            patch.object(
                erp_finance_adapter,
                "_mode_account",
                return_value="Cash - T",
            ) as mode_account,
            patch.object(
                erp_finance_adapter,
                "get_payment_entry",
                return_value=generated,
            ) as get_payment,
            patch.object(
                erp_finance_adapter.frappe.db,
                "set_value",
            ) as set_value,
        ):
            result = erp_finance_adapter._create_payment_entry(
                payment,
                invoice,
                config,
            )

        mode_account.assert_called_once_with(
            "Testing-P1",
            "Cash",
        )
        get_payment.assert_called_once_with(
            "Sales Invoice",
            "SINV-1",
            bank_account="Cash - T",
            ignore_permissions=True,
        )

        self.assertEqual(generated.mode_of_payment, "Cash")
        self.assertEqual(generated.reference_no, "BANK-REF-1")
        generated.insert.assert_called_once_with(ignore_permissions=True)
        generated.submit.assert_called_once()

        set_value.assert_called_once_with(
            "OMC Service Payment",
            "OMC-PAY-1",
            "erp_payment_entry",
            "ACC-PAY-1",
            update_modified=False,
        )
        self.assertIs(result, generated)

    def test_create_payment_entry_prefers_payment_level_mode(self):
        payment = SimpleNamespace(
            name="OMC-PAY-1",
            service_request="OMC-SR-1",
            payment_reference="WIRE-REF-1",
            payment_method="Wire Transfer",
            erp_payment_entry="",
        )
        invoice = SimpleNamespace(name="SINV-1")

        generated = MagicMock()
        generated.name = "ACC-PAY-1"
        generated.meta.has_field.return_value = False

        config = {
            "company": "Testing-P1",
            "mode_of_payment": "Cash",
        }

        with (
            patch.object(
                erp_finance_adapter.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                erp_finance_adapter,
                "_mode_account",
                return_value="Test Bank - T",
            ) as mode_account,
            patch.object(
                erp_finance_adapter,
                "get_payment_entry",
                return_value=generated,
            ),
            patch.object(
                erp_finance_adapter.frappe.db,
                "set_value",
            ),
        ):
            erp_finance_adapter._create_payment_entry(
                payment,
                invoice,
                config,
            )

        mode_account.assert_called_once_with(
            "Testing-P1",
            "Wire Transfer",
        )
        self.assertEqual(generated.mode_of_payment, "Wire Transfer")
        self.assertEqual(generated.reference_no, "WIRE-REF-1")
        self.assertIsNone(generated.custom_structure_name)
        self.assertIsNone(generated.custom_omc_customer)

    def test_finalize_verified_payment_is_idempotent_when_erp_records_exist(self):
        payment = MagicMock()
        payment.doctype = "OMC Service Payment"
        payment.name = "OMC-PAY-1"
        payment.service_request = "OMC-SR-1"
        payment.erp_sales_invoice = "SINV-1"
        payment.erp_payment_entry = "ACC-PAY-1"

        request = SimpleNamespace(
            name="OMC-SR-1",
            erp_customer="CUST-1",
        )
        settings = SimpleNamespace()

        invoice = MagicMock()
        invoice.name = "SINV-1"
        invoice.docstatus = 1
        invoice.outstanding_amount = 0

        payment_entry = MagicMock()
        payment_entry.name = "ACC-PAY-1"
        payment_entry.docstatus = 1

        config = {
            "company": "Testing-P1",
            "item_code": "OMC-SERVICE",
            "mode_of_payment": "Cash",
        }

        with (
            patch.object(
                erp_finance_adapter.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                erp_finance_adapter.frappe,
                "get_doc",
                return_value=request,
            ),
            patch.object(
                erp_finance_adapter,
                "_settings",
                return_value=settings,
            ),
            patch.object(
                erp_finance_adapter,
                "_validate_configuration",
                return_value=config,
            ),
            patch.object(
                erp_finance_adapter,
                "_resolve_customer",
                return_value="CUST-1",
            ),
            patch.object(
                erp_finance_adapter,
                "_ensure_invoice",
                return_value=(invoice, False),
            ),
            patch.object(
                erp_finance_adapter,
                "_ensure_payment_entry",
                return_value=(payment_entry, False),
            ),
        ):
            result = erp_finance_adapter.finalize_verified_payment(payment)

        self.assertEqual(result["status"], "Posted")
        self.assertFalse(result["invoice_created"])
        self.assertFalse(result["payment_entry_created"])
        self.assertEqual(result["sales_invoice"], "SINV-1")
        self.assertEqual(result["payment_entry"], "ACC-PAY-1")
        self.assertEqual(result["invoice_outstanding"], 0)

        self.assertEqual(payment.erp_finance_status, "Posted")
        self.assertEqual(payment.erp_finance_error, "")
