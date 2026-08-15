from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app import hooks
from omc_app.api import payment_read_guard


class TestPaymentReadGuard(FrappeTestCase):
    def _payment(self, *, service_request="OMC-SR-TEST", visible=1):
        return SimpleNamespace(
            name="OMC-PAY-TEST",
            service_request=service_request,
            visible_to_customer=visible,
        )

    def test_hooks_route_payment_reads_through_guard(self):
        self.assertEqual(
            hooks.override_whitelisted_methods["omc_app.api.payments.get_payments"],
            "omc_app.api.payment_read_guard.get_payments",
        )
        self.assertEqual(
            hooks.override_whitelisted_methods["omc_app.api.payments.get_payment"],
            "omc_app.api.payment_read_guard.get_payment",
        )

    @patch("omc_app.api.payment_read_guard.frappe.get_doc")
    @patch("omc_app.api.payment_read_guard.frappe.db.exists")
    def test_blank_parent_is_not_readable(self, exists, get_doc):
        exists.side_effect = [True]
        get_doc.return_value = self._payment(service_request="")

        with self.assertRaises(frappe.DoesNotExistError):
            payment_read_guard._load_readable_payment("OMC-PAY-TEST")

    @patch("omc_app.api.payment_read_guard.frappe.get_doc")
    @patch("omc_app.api.payment_read_guard.frappe.db.exists")
    def test_missing_parent_is_not_readable(self, exists, get_doc):
        exists.side_effect = [True, False]
        get_doc.return_value = self._payment()

        with self.assertRaises(frappe.DoesNotExistError):
            payment_read_guard._load_readable_payment("OMC-PAY-TEST")

    @patch("omc_app.api.payment_read_guard.payments._payment_dict")
    @patch("omc_app.api.payment_read_guard._load_readable_payment")
    def test_safe_payload_skips_stale_payment(self, load_payment, payment_dict):
        load_payment.side_effect = frappe.DoesNotExistError

        result = payment_read_guard._safe_payment_payload(
            "OMC-PAY-STALE",
            capabilities={},
            customer_view=True,
        )

        self.assertIsNone(result)
        payment_dict.assert_not_called()

    @patch("omc_app.api.payment_read_guard.payments._payment_dict")
    @patch("omc_app.api.payment_read_guard._load_readable_payment")
    def test_safe_payload_preserves_canonical_serialisation(
        self,
        load_payment,
        payment_dict,
    ):
        payment = self._payment()
        load_payment.return_value = payment
        payment_dict.return_value = {"name": payment.name}

        result = payment_read_guard._safe_payment_payload(
            payment.name,
            capabilities={"can_review_payments": True},
            customer_view=False,
        )

        payment_dict.assert_called_once_with(
            payment,
            capabilities={"can_review_payments": True},
            customer_view=False,
        )
        self.assertEqual(result["name"], payment.name)

    @patch("omc_app.api.payment_read_guard.frappe.get_all")
    @patch("omc_app.api.payment_read_guard._safe_payment_payload")
    @patch("omc_app.api.payment_read_guard.payments._accessible_service_requests")
    @patch("omc_app.api.payment_read_guard.access.get_mobile_capabilities")
    @patch("omc_app.api.payment_read_guard.mobile._assert_approved_customer")
    @patch("omc_app.api.payment_read_guard.mobile._can_access_internal_workspace")
    def test_payment_list_skips_only_stale_rows(
        self,
        internal_workspace,
        approved_customer,
        capabilities,
        accessible_requests,
        safe_payload,
        get_all,
    ):
        internal_workspace.return_value = False
        profile = SimpleNamespace(name="CUS-TEST")
        approved_customer.return_value = profile
        capabilities.return_value = {}
        accessible_requests.return_value = [SimpleNamespace(name="OMC-SR-TEST")]
        get_all.side_effect = [
            [
                frappe._dict(
                    name="OMC-PAY-GOOD",
                    payment_title="Tax filing",
                    payment_reference="PK-1",
                    status="Receipt Submitted",
                    service_request="OMC-SR-TEST",
                ),
                frappe._dict(
                    name="OMC-PAY-STALE",
                    payment_title="Tax filing",
                    payment_reference="PK-2",
                    status="Receipt Submitted",
                    service_request="OMC-SR-TEST",
                ),
            ],
            [
                frappe._dict(
                    name="OMC-SR-TEST",
                    customer_name="Ayesha Khan",
                    customer_profile="OMC-CUST-1",
                    service_title="Tax Filing",
                    service="tax-filing",
                )
            ],
        ]
        safe_payload.side_effect = [
            {"name": "OMC-PAY-GOOD"},
            None,
        ]

        result = payment_read_guard.get_payments(
            limit_start=0,
            limit_page_length=1,
            search="Ayesha",
            status="Receipt Submitted,Under Review",
        )

        self.assertEqual(
            result,
            {
                "payments": [{"name": "OMC-PAY-GOOD"}],
                "limit_start": 0,
                "limit_page_length": 1,
                "total": 1,
                "has_more": False,
            },
        )
        self.assertEqual(safe_payload.call_count, 2)

    @patch("omc_app.api.payment_read_guard._authorize_payment_read")
    @patch("omc_app.api.payment_read_guard._load_readable_payment")
    def test_invoice_download_requires_linked_invoice(
        self,
        load_payment,
        authorize,
    ):
        payment = self._payment()
        payment.erp_sales_invoice = ""
        load_payment.return_value = payment

        with self.assertRaises(frappe.DoesNotExistError):
            payment_read_guard.download_invoice_pdf(
                payment_id=payment.name,
            )

        authorize.assert_called_once_with(payment, assisted=0)

    @patch("omc_app.api.payment_read_guard._authorize_payment_read")
    @patch("omc_app.api.payment_read_guard._load_readable_payment")
    def test_invoice_download_rejects_missing_sales_invoice(
        self,
        load_payment,
        authorize,
    ):
        payment = self._payment()
        payment.erp_sales_invoice = "SINV-MISSING"
        load_payment.return_value = payment

        with patch(
            "omc_app.api.payment_read_guard.frappe.db.exists",
            return_value=False,
        ):
            with self.assertRaises(frappe.DoesNotExistError):
                payment_read_guard.download_invoice_pdf(
                    payment_id=payment.name,
                )

        authorize.assert_called_once_with(payment, assisted=0)

    @patch("omc_app.api.payment_read_guard._authorize_payment_read")
    @patch("omc_app.api.payment_read_guard._load_readable_payment")
    def test_invoice_download_requires_submitted_invoice(
        self,
        load_payment,
        authorize,
    ):
        payment = self._payment()
        payment.erp_sales_invoice = "SINV-DRAFT"
        load_payment.return_value = payment

        invoice = SimpleNamespace(
            name="SINV-DRAFT",
            docstatus=0,
        )

        with (
            patch(
                "omc_app.api.payment_read_guard.frappe.db.exists",
                return_value=True,
            ),
            patch(
                "omc_app.api.payment_read_guard.frappe.get_doc",
                return_value=invoice,
            ),
        ):
            with self.assertRaises(frappe.ValidationError):
                payment_read_guard.download_invoice_pdf(
                    payment_id=payment.name,
                )

        authorize.assert_called_once_with(payment, assisted=0)

    @patch("omc_app.api.payment_read_guard.save_file")
    @patch("omc_app.api.payment_read_guard.frappe.get_print")
    @patch("omc_app.api.payment_read_guard.frappe.get_doc")
    @patch("omc_app.api.payment_read_guard.frappe.db.exists")
    @patch("omc_app.api.payment_read_guard._authorize_payment_read")
    @patch("omc_app.api.payment_read_guard._load_readable_payment")
    def test_invoice_download_returns_private_pdf(
        self,
        load_payment,
        authorize,
        exists,
        get_doc,
        get_print,
        save_file,
    ):
        payment = self._payment()
        payment.erp_sales_invoice = "SINV-1"
        load_payment.return_value = payment

        exists.return_value = True
        get_doc.return_value = SimpleNamespace(
            name="SINV-1",
            docstatus=1,
        )
        get_print.return_value = b"%PDF-1.7 invoice"

        file_doc = SimpleNamespace(
            file_name="SINV-1.pdf",
            file_url="/private/files/SINV-1.pdf",
        )
        save_file.return_value = file_doc

        result = payment_read_guard.download_invoice_pdf(
            payment_id=payment.name,
        )

        authorize.assert_called_once_with(payment, assisted=0)
        get_print.assert_called_once_with(
            "Sales Invoice",
            "SINV-1",
            as_pdf=True,
        )
        save_file.assert_called_once_with(
            "SINV-1.pdf",
            b"%PDF-1.7 invoice",
            "OMC Service Payment",
            payment.name,
            is_private=1,
        )

        self.assertEqual(
            result,
            {
                "payment_id": payment.name,
                "invoice": "SINV-1",
                "file_name": "SINV-1.pdf",
                "file_url": "/private/files/SINV-1.pdf",
            },
        )

    @patch("omc_app.api.payment_read_guard._load_readable_payment")
    def test_hidden_payment_detail_is_not_found(self, load_payment):
        load_payment.return_value = self._payment(visible=0)

        with self.assertRaises(frappe.DoesNotExistError):
            payment_read_guard.get_payment(payment_id="OMC-PAY-TEST")
