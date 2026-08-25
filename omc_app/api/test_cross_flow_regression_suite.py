from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import mobile, payments, workflow_automation


class TestCrossFlowRegressionSuite(FrappeTestCase):
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
        payment.payment_reference = "REF-1"
        payment.remarks = ""
        payment.payment_title = "Service Payment"
        payment.paid_on = None
        return payment

    def _case(
        self,
        status="Waiting for Payment",
        final_price=5000,
    ):
        return SimpleNamespace(
            name="OMC-SR-1",
            service="OMC-SVC-1",
            status=status,
            final_price=final_price,
            customer_profile="OMC-CUST-1",
            assigned_staff=None,
        )

    def test_locked_price_and_approved_documents_allow_payment(self):
        service_case = self._case(final_price=5000)
        required = [
            {
                "title": "CNIC",
                "document_type": "Identity",
                "is_required": 1,
            }
        ]
        documents = [
            {
                "title": "CNIC",
                "type": "Identity",
                "status": "Approved",
                "file_url": "/private/files/cnic.pdf",
            }
        ]

        with patch.object(
            mobile.frappe,
            "get_all",
            return_value=[],
        ):
            contract = mobile._service_case_payment_contract(
                service_case,
                documents=documents,
                required_document_templates=required,
            )

        self.assertTrue(contract["documents_complete"])
        self.assertTrue(contract["payment_eligible"])
        self.assertEqual(
            contract["payment_block_reason"],
            "payment_not_opened",
        )

    def test_historical_rejection_does_not_block_approved_replacement(self):
        service_case = self._case()
        required = [
            {
                "title": "CNIC",
                "document_type": "Identity",
                "is_required": 1,
            }
        ]
        documents = [
            {
                "title": "CNIC",
                "type": "Identity",
                "status": "Rejected",
                "file_url": "/private/files/old.pdf",
            },
            {
                "title": "CNIC",
                "type": "Identity",
                "status": "Approved",
                "file_url": "/private/files/new.pdf",
            },
        ]

        with patch.object(
            mobile.frappe,
            "get_all",
            return_value=[],
        ):
            contract = mobile._service_case_payment_contract(
                service_case,
                documents=documents,
                required_document_templates=required,
            )

        self.assertTrue(contract["documents_complete"])
        self.assertTrue(contract["payment_eligible"])

    def test_unpaid_active_payment_blocks_completion(self):
        service_case = self._case(status="In Progress")
        document_rows = [
            SimpleNamespace(
                document_title="CNIC",
                document_type="Identity",
                status="Approved",
                attachment="/private/files/cnic.pdf",
            )
        ]
        payment_rows = [
            SimpleNamespace(
                name="OMC-PAY-1",
                status="Pending",
            )
        ]

        with patch.object(
            workflow_automation.mobile,
            "_service_required_documents",
            return_value=[
                {
                    "title": "CNIC",
                    "document_type": "Identity",
                    "is_required": 1,
                }
            ],
        ), patch.object(
            workflow_automation.mobile,
            "_doctype_has_field",
            return_value=True,
        ):
            with patch.object(
                workflow_automation.frappe,
                "get_all",
                side_effect=[document_rows, payment_rows],
            ):
                blockers = workflow_automation.completion_blockers(
                    service_case
                )

        self.assertTrue(
            any("payment" in blocker.lower() for blocker in blockers)
        )

    def test_paid_payment_clears_completion_payment_blocker(self):
        service_case = self._case(status="In Progress")
        document_rows = [
            SimpleNamespace(
                document_title="CNIC",
                document_type="Identity",
                status="Approved",
                attachment="/private/files/cnic.pdf",
            )
        ]
        payment_rows = [
            SimpleNamespace(
                name="OMC-PAY-1",
                status="Paid",
            )
        ]

        with patch.object(
            workflow_automation.mobile,
            "_service_required_documents",
            return_value=[
                {
                    "title": "CNIC",
                    "document_type": "Identity",
                    "is_required": 1,
                }
            ],
        ), patch.object(
            workflow_automation.mobile,
            "_doctype_has_field",
            return_value=True,
        ):
            with patch.object(
                workflow_automation.frappe,
                "get_all",
                side_effect=[document_rows, payment_rows],
            ):
                blockers = workflow_automation.completion_blockers(
                    service_case
                )

        self.assertFalse(
            any("payment" in blocker.lower() for blocker in blockers)
        )

    def test_same_payment_review_is_noop_without_side_effects(self):
        payment = self._payment(status="Under Review")
        service_case = self._case()

        with patch.object(
            payments,
            "_require_payment_review_access",
        ), patch.object(
            payments,
            "_assert_service_request_payment_access",
        ), patch.object(
            payments.frappe.db,
            "exists",
            return_value=True,
        ), patch.object(
            payments.frappe,
            "get_doc",
            side_effect=[payment, service_case],
        ), patch.object(
            payments.mobile,
            "_create_service_timeline_entry",
        ) as timeline, patch.object(
            payments.mobile,
            "_create_customer_notification",
        ) as notification:
            result = payments.review_payment_receipt(
                payment_id=payment.name,
                status="Under Review",
                remarks="Repeated request",
            )

        self.assertFalse(result["updated"])
        payment.save.assert_not_called()
        timeline.assert_not_called()
        notification.assert_not_called()

    def test_paid_payment_rejects_receipt_replacement(self):
        payment = self._payment(status="Paid")

        with self.assertRaises(frappe.ValidationError):
            payments._assert_payment_accepts_receipt(payment)

    def test_completed_case_rejects_payment_review(self):
        payment = self._payment()
        service_case = self._case(status="Completed")

        with patch.object(
            payments,
            "_require_payment_review_access",
        ), patch.object(
            payments,
            "_assert_service_request_payment_access",
        ), patch.object(
            payments.frappe.db,
            "exists",
            return_value=True,
        ), patch.object(
            payments.frappe,
            "get_doc",
            side_effect=[payment, service_case],
        ):
            with self.assertRaises(frappe.ValidationError):
                payments.review_payment_receipt(
                    payment_id=payment.name,
                    status="Paid",
                )

    def test_cancelled_case_rejects_payment_review(self):
        payment = self._payment()
        service_case = self._case(status="Cancelled")

        with patch.object(
            payments,
            "_require_payment_review_access",
        ), patch.object(
            payments,
            "_assert_service_request_payment_access",
        ), patch.object(
            payments.frappe.db,
            "exists",
            return_value=True,
        ), patch.object(
            payments.frappe,
            "get_doc",
            side_effect=[payment, service_case],
        ):
            with self.assertRaises(frappe.ValidationError):
                payments.review_payment_receipt(
                    payment_id=payment.name,
                    status="Rejected",
                    remarks="Invalid after cancellation",
                )

    def test_rejected_payment_accepts_new_receipt_submission(self):
        payment = self._payment(status="Rejected")

        payments._assert_payment_accepts_receipt(payment)

    def test_identical_receipt_retry_is_detected(self):
        payment = self._payment(status="Receipt Submitted")

        unchanged = (
            payments._payment_receipt_submission_is_unchanged(
                payment,
                receipt_attachment="/private/files/receipt.pdf",
                payment_reference="REF-1",
                remarks="",
            )
        )

        self.assertTrue(unchanged)
