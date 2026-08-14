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
        service_case = MagicMock()
        service_case.name = "OMC-SR-1"
        service_case.status = status
        service_case.customer_profile = "OMC-CUST-1"
        service_case.assigned_staff = None
        return service_case

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
    def test_paid_transition_runs_activation_once(
        self,
        timeline,
        notification,
        _commit,
        _now,
    ):
        payment = self._payment()
        service_case = self._case()
        patches = self._base_patches(payment, service_case)

        activation_result = {
            "activated": True,
            "case_status": "In Progress",
            "assigned_staff": "consultant@example.com",
            "erp_service": "SERVICE-ERP-1",
            "erp_task": "TASK-ERP-1",
        }

        def reload_case():
            service_case.status = "In Progress"
            service_case.assigned_staff = "consultant@example.com"

        service_case.reload.side_effect = reload_case

        finance_result = {
            "status": "Posted",
            "customer": "CUST-1",
            "sales_invoice": "SINV-1",
            "payment_entry": "ACC-PAY-1",
            "invoice_created": True,
            "payment_entry_created": True,
            "invoice_outstanding": 0,
        }

        with patches[0], patches[1], patches[2], patches[3]:
            with (
                patch.object(
                    payments.erp_finance_adapter,
                    "finalize_verified_payment",
                    return_value=finance_result,
                ) as finance,
                patch(
                    "omc_app.api.service_activation.activate_paid_request",
                    return_value=activation_result,
                ) as activate,
            ):
                result = payments.review_payment_receipt(
                    payment_id=payment.name,
                    status="Paid",
                )

        finance.assert_called_once_with(payment)

        self.assertTrue(result["updated"])
        payment.save.assert_called_once_with(
            ignore_permissions=True,
        )
        activate.assert_called_once_with(service_case.name)
        self.assertEqual(result["activation"], activation_result)
        self.assertEqual(result["case_transition_status"], "In Progress")
        self.assertEqual(result["activation_error"], "")
        notification.assert_called()


    def test_erp_finance_failure_blocks_paid_transition_and_activation(self):
        payment = self._payment()
        service_case = self._case()
        original_status = payment.status
        patches = self._base_patches(payment, service_case)

        with patches[0], patches[1], patches[2], patches[3]:
            with (
                patch.object(
                    payments.erp_finance_adapter,
                    "finalize_verified_payment",
                    side_effect=frappe.ValidationError(
                        "Mode of Payment account is not configured"
                    ),
                ),
                patch(
                    "omc_app.api.service_activation.activate_paid_request",
                ) as activate,
                patch.object(
                    payments.frappe.db,
                    "savepoint",
                ) as savepoint,
                patch.object(
                    payments.frappe.db,
                    "rollback",
                ) as rollback,
            ):
                with self.assertRaises(frappe.ValidationError):
                    payments.review_payment_receipt(
                        payment_id=payment.name,
                        status="Paid",
                    )

        self.assertEqual(payment.status, original_status)
        self.assertIsNone(payment.paid_on)
        activate.assert_not_called()

        savepoint.assert_called_once_with(
            "verified_payment_erp_finance"
        )
        rollback.assert_called_once_with(
            save_point="verified_payment_erp_finance"
        )


class TestPaidActivationDurability(FrappeTestCase):
    def test_activation_failure_does_not_undo_paid_payment(self):
        payment = MagicMock()
        payment.name = "OMC-PAY-FAIL-1"
        payment.service_request = "OMC-SR-FAIL-1"
        payment.status = "Receipt Submitted"
        payment.receipt_attachment = "/private/files/receipt.pdf"
        payment.payment_reference = ""
        payment.remarks = ""
        payment.payment_title = "Service Payment"
        payment.paid_on = None

        service_case = MagicMock()
        service_case.name = "OMC-SR-FAIL-1"
        service_case.status = "Waiting for Payment"
        service_case.customer_profile = "OMC-CUST-1"
        service_case.assigned_staff = None

        def reload_case():
            service_case.status = "Waiting for Payment"
            service_case.assigned_staff = None

        service_case.reload.side_effect = reload_case

        with (
            patch.object(payments, "_require_payment_review_access"),
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
            patch.object(
                payments.frappe.utils,
                "now_datetime",
                return_value="2026-08-15 00:00:00",
            ),
            patch.object(
                payments.review_routing,
                "close_review_todos",
            ),
            patch.object(
                payments.mobile,
                "_create_service_timeline_entry",
            ),
            patch.object(
                payments.mobile,
                "_create_customer_notification",
            ),
            patch.object(
                payments.frappe.db,
                "savepoint",
            ) as savepoint,
            patch.object(
                payments.frappe.db,
                "rollback",
            ) as rollback,
            patch.object(
                payments.frappe.db,
                "commit",
            ) as commit,
            patch.object(
                payments.erp_finance_adapter,
                "finalize_verified_payment",
                return_value={
                    "status": "Posted",
                    "customer": "CUST-1",
                    "sales_invoice": "SINV-1",
                    "payment_entry": "ACC-PAY-1",
                    "invoice_created": True,
                    "payment_entry_created": True,
                    "invoice_outstanding": 0,
                },
            ),
            patch(
                "omc_app.api.service_activation.activate_paid_request",
                side_effect=frappe.ValidationError(
                    "ERP Task Type missing"
                ),
            ),
            patch.object(
                payments.frappe,
                "log_error",
            ),
        ):
            result = payments.review_payment_receipt(
                payment_id=payment.name,
                status="Paid",
            )

        self.assertTrue(result["updated"])
        self.assertEqual(payment.status, "Paid")
        self.assertEqual(
            payment.paid_on,
            "2026-08-15 00:00:00",
        )

        payment.save.assert_called_once_with(
            ignore_permissions=True,
        )

        # First commit makes verified payment durable before activation.
        self.assertGreaterEqual(commit.call_count, 2)

        self.assertEqual(
            savepoint.call_args_list,
            [
                (("verified_payment_erp_finance",), {}),
                (("paid_request_activation",), {}),
            ],
        )
        rollback.assert_called_once_with(
            save_point="paid_request_activation"
        )

        self.assertEqual(
            service_case.status,
            "Waiting for Payment",
        )
        self.assertIsNone(
            result["case_transition_status"],
        )
        self.assertIn(
            "ERP Task Type missing",
            result["activation_error"],
        )
        self.assertIsNone(result["activation"])
