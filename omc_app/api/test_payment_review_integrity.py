from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import payments


class TestPaymentReviewIntegrity(FrappeTestCase):
    def _payment(
        self,
        status="Receipt Submitted",
        receipt="/private/files/receipt.pdf",
    ):
        payment = MagicMock()
        payment.name = "OMC-PAY-1"
        payment.service_request = "OMC-SR-1"
        payment.status = status
        payment.receipt_attachment = receipt
        payment.payment_reference = ""
        payment.remarks = ""
        payment.payment_title = "Service Payment"
        payment.paid_on = None
        return payment

    def _case(self, status="Waiting for Payment"):
        return SimpleNamespace(
            name="OMC-SR-1",
            status=status,
            customer_profile="OMC-CUST-1",
            assigned_staff=None,
        )

    def _base_patches(self, payment, service_case):
        return (
            patch.object(
                payments,
                "_require_payment_review_access",
            ),
            patch.object(
                payments,
                "_assert_service_request_payment_access",
            ),
            patch.object(
                payments.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                payments.frappe,
                "get_doc",
                side_effect=[payment, service_case],
            ),
        )

    def test_same_status_is_idempotent_noop(self):
        payment = self._payment(status="Under Review")
        service_case = self._case()
        patches = self._base_patches(payment, service_case)

        with patches[0], patches[1], patches[2], patches[3]:
            with patch.object(
                payments.mobile,
                "_create_service_timeline_entry",
            ) as timeline:
                result = payments.review_payment_receipt(
                    payment_id=payment.name,
                    status="Under Review",
                    remarks="Retry",
                )

        self.assertFalse(result["updated"])
        payment.save.assert_not_called()
        timeline.assert_not_called()

    def test_paid_review_is_final(self):
        payment = self._payment(status="Paid")
        service_case = self._case(status="In Progress")
        patches = self._base_patches(payment, service_case)

        with patches[0], patches[1], patches[2], patches[3]:
            with self.assertRaises(frappe.ValidationError):
                payments.review_payment_receipt(
                    payment_id=payment.name,
                    status="Rejected",
                    remarks="Changed decision",
                )

    def test_cancelled_review_is_final(self):
        payment = self._payment(status="Cancelled")
        service_case = self._case()
        patches = self._base_patches(payment, service_case)

        with patches[0], patches[1], patches[2], patches[3]:
            with self.assertRaises(frappe.ValidationError):
                payments.review_payment_receipt(
                    payment_id=payment.name,
                    status="Paid",
                )

    def test_rejected_requires_new_receipt_submission(self):
        payment = self._payment(status="Rejected")
        service_case = self._case(status="Waiting for Customer")
        patches = self._base_patches(payment, service_case)

        with patches[0], patches[1], patches[2], patches[3]:
            with self.assertRaises(frappe.ValidationError):
                payments.review_payment_receipt(
                    payment_id=payment.name,
                    status="Paid",
                )

    def test_rejection_requires_remarks(self):
        payment = self._payment()
        service_case = self._case()
        patches = self._base_patches(payment, service_case)

        with patches[0], patches[1], patches[2], patches[3]:
            with self.assertRaises(frappe.ValidationError):
                payments.review_payment_receipt(
                    payment_id=payment.name,
                    status="Rejected",
                    remarks="",
                )

    def test_under_review_requires_receipt(self):
        payment = self._payment(receipt="")
        service_case = self._case()
        patches = self._base_patches(payment, service_case)

        with patches[0], patches[1], patches[2], patches[3]:
            with self.assertRaises(frappe.ValidationError):
                payments.review_payment_receipt(
                    payment_id=payment.name,
                    status="Under Review",
                )

    def test_terminal_case_rejects_payment_review(self):
        payment = self._payment()
        service_case = self._case(status="Completed")
        patches = self._base_patches(payment, service_case)

        with patches[0], patches[1], patches[2], patches[3]:
            with self.assertRaises(frappe.ValidationError):
                payments.review_payment_receipt(
                    payment_id=payment.name,
                    status="Paid",
                )

    @patch.object(
        payments.frappe.utils,
        "now_datetime",
        return_value="2026-07-31 14:34:00",
    )
    @patch.object(payments.frappe.db, "commit")
    @patch.object(
        payments.mobile,
        "_create_customer_notification",
    )
    @patch.object(
        payments.mobile,
        "_create_service_timeline_entry",
    )
    @patch.object(
        payments,
        "_set_case_status",
        return_value=True,
    )
    def test_paid_transition_runs_side_effects_once(
        self,
        _set_status,
        timeline,
        notification,
        _commit,
        _now,
    ):
        payment = self._payment()
        service_case = self._case()
        patches = self._base_patches(payment, service_case)

        with patches[0], patches[1], patches[2], patches[3]:
            result = payments.review_payment_receipt(
                payment_id=payment.name,
                status="Paid",
            )

        self.assertTrue(result["updated"])
        payment.save.assert_called_once_with(
            ignore_permissions=True,
        )
        self.assertEqual(timeline.call_count, 2)
        notification.assert_called_once()
