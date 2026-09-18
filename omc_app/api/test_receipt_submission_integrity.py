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
    @patch("omc_app.api.payment_receipt_analysis.schedule_analysis")
    @patch.object(payments, "_record_receipt_evidence")
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
        record_evidence,
        schedule_analysis,
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
        record_evidence.return_value = SimpleNamespace(
            name="OMC-RCP-1",
            submission_source="Customer App",
            submitted_by="profile-edit-test@example.com",
            submitted_at="2026-09-18 12:00:00",
        )

        with (
            patch.object(payments.security, "enforce_rate_limit"),
            patch.object(payments.idempotency, "begin", return_value=None),
            patch.object(payments.upload_validation, "validate_upload_bytes", return_value="new.pdf"),
            patch.object(payments.upload_validation, "scan_upload", return_value="Manual Review"),
            patch.object(
                payments,
                "save_file",
                return_value=SimpleNamespace(
                    file_url="/private/files/new.pdf",
                    owner="profile-edit-test@example.com",
                    creation="2026-09-18 12:00:00",
                ),
            ),
        ):
            result = payments.upload_payment_receipt_file(
                payment_id=payment.name,
                file_name="new.pdf",
                content_base64="JVBERi0xLjc=",
                payment_reference="REF-2",
                remarks="New receipt",
                idempotency_key="receipt-test-1",
            )

        self.assertTrue(result["updated"])
        payment.save.assert_called_once_with(
            ignore_permissions=True,
        )
        record_evidence.assert_called_once()
        schedule_analysis.assert_called_once_with("OMC-RCP-1")
        timeline.assert_called_once()
        set_status.assert_called_once()
        notify.assert_called_once()
        commit.assert_not_called()
