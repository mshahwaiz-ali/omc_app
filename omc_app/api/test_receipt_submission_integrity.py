from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import payments


class TestReceiptSubmissionIntegrity(FrappeTestCase):
    def _payment(self, status="Pending"):
        return SimpleNamespace(
            name="OMC-PAY-1",
            status=status,
            receipt_attachment="/private/files/r.pdf",
            payment_reference="REF-1",
            remarks="Submitted",
        )

    def test_paid_payment_rejects_new_receipt(self):
        with self.assertRaises(frappe.ValidationError):
            payments._assert_payment_accepts_receipt(
                self._payment(status="Paid")
            )

    def test_cancelled_payment_rejects_new_receipt(self):
        with self.assertRaises(frappe.ValidationError):
            payments._assert_payment_accepts_receipt(
                self._payment(status="Cancelled")
            )

    def test_rejected_payment_accepts_replacement(self):
        payments._assert_payment_accepts_receipt(
            self._payment(status="Rejected")
        )

    def test_identical_submission_is_detected(self):
        payment = self._payment(status="Receipt Submitted")

        self.assertTrue(
            payments._payment_receipt_submission_is_unchanged(
                payment,
                receipt_attachment="/private/files/r.pdf",
                payment_reference="REF-1",
                remarks="Submitted",
            )
        )

    def test_changed_receipt_is_not_noop(self):
        payment = self._payment(status="Receipt Submitted")

        self.assertFalse(
            payments._payment_receipt_submission_is_unchanged(
                payment,
                receipt_attachment="/private/files/new.pdf",
                payment_reference="REF-1",
                remarks="Submitted",
            )
        )

    @patch.object(payments.frappe.db, "commit")
    @patch.object(payments.review_routing, "ensure_review_assignment")
    @patch.object(payments, "_set_case_status")
    @patch.object(
        payments.mobile,
        "_create_service_timeline_entry",
    )
    @patch.object(payments.mobile, "_get_mobile_capabilities")
    @patch.object(payments.mobile, "_save_base64_file")
    @patch.object(payments, "_assert_payment_customer_access")
    @patch.object(payments.frappe, "get_doc")
    @patch.object(
        payments.frappe.db,
        "exists",
        return_value=True,
    )
    def test_new_base64_receipt_runs_side_effects_once(
        self,
        _exists,
        get_doc,
        customer_access,
        save_file,
        capabilities,
        timeline,
        set_status,
        notify,
        commit,
    ):
        payment = MagicMock()
        payment.name = "OMC-PAY-1"
        payment.service_request = "OMC-SR-1"
        payment.status = "Pending"
        payment.receipt_attachment = ""
        payment.payment_reference = ""
        payment.remarks = ""
        payment.payment_title = "Service Payment"
        payment.paid_on = None

        service_case = SimpleNamespace(
            name="OMC-SR-1",
            status="Open",
        )
        get_doc.return_value = payment
        customer_access.return_value = (
            SimpleNamespace(name="OMC-CUST-1"),
            service_case,
        )
        save_file.return_value = SimpleNamespace(
            file_url="/private/files/new.pdf",
        )
        capabilities.return_value = {
            "can_upload_payment_receipt": True,
        }

        result = payments.upload_payment_receipt_file(
            payment_id=payment.name,
            file_name="new.pdf",
            content_base64="YWJj",
            payment_reference="REF-2",
            remarks="New receipt",
        )

        self.assertTrue(result["updated"])
        payment.save.assert_called_once_with(
            ignore_permissions=True,
        )
        timeline.assert_called_once()
        set_status.assert_called_once()
        notify.assert_called_once()
        commit.assert_called_once()
