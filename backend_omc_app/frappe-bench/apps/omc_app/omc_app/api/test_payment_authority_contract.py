from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.omc_app.doctype.omc_service_payment.omc_service_payment import (
    OMCServicePayment,
)


class TestPaymentAuthorityContract(FrappeTestCase):
    def _payment(self, **overrides):
        payment = OMCServicePayment(
            {
                "doctype": "OMC Service Payment",
                "service_request": "OMC-SR-1",
                "payment_title": "Service Payment",
                "amount": 1000,
                "currency": "PKR",
                "status": "Pending",
                "visible_to_customer": 1,
            }
        )
        for key, value in overrides.items():
            setattr(payment, key, value)
        return payment

    def test_amount_must_be_positive(self):
        payment = self._payment(amount=0)

        with self.assertRaises(Exception):
            payment._assert_financial_integrity()

    def test_amount_is_immutable_after_creation(self):
        payment = self._payment(amount=1200)
        previous = SimpleNamespace(
            service_request="OMC-SR-1",
            amount=1000,
        )

        with self.assertRaises(Exception):
            payment._assert_financial_integrity(previous)

    def test_service_request_is_immutable_after_creation(self):
        payment = self._payment(service_request="OMC-SR-2")
        previous = SimpleNamespace(
            service_request="OMC-SR-1",
            amount=1000,
        )

        with self.assertRaises(Exception):
            payment._assert_financial_integrity(previous)

    def test_paid_or_rejected_requires_receipt(self):
        for status in ("Paid", "Rejected"):
            with self.subTest(status=status):
                payment = self._payment(
                    status=status,
                    receipt_attachment="",
                )
                with self.assertRaises(Exception):
                    payment._assert_financial_integrity()

    def test_duplicate_active_payment_is_blocked(self):
        payment = self._payment()

        with patch(
            "omc_app.omc_app.doctype.omc_service_payment."
            "omc_service_payment.frappe.db.exists",
            return_value="PAY-EXISTING",
        ):
            with self.assertRaises(Exception):
                payment._assert_single_active_payment()

    def test_cancelled_payment_skips_active_duplicate_check(self):
        payment = self._payment(status="Cancelled")

        with patch(
            "omc_app.omc_app.doctype.omc_service_payment."
            "omc_service_payment.frappe.db.exists",
        ) as exists:
            payment._assert_single_active_payment()

        exists.assert_not_called()

    def test_legacy_mobile_upload_keeps_canonical_workflow_calls(self):
        from pathlib import Path

        root = Path(__file__).resolve()
        for candidate in root.parents:
            mobile = candidate / "api/mobile.py"
            if mobile.is_file():
                source = mobile.read_text(encoding="utf-8")
                break
        else:
            self.fail("mobile.py not found")

        self.assertIn(
            'payments._set_case_status(service_case, "Waiting for Payment")',
            source,
        )
        self.assertIn("payments._notify_payment_reviewers(", source)
        self.assertIn('capabilities.get("can_upload_payment_receipt")', source)
