from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import payments


class TestReceiptPartialFailureSafety(FrappeTestCase):
    def test_cleanup_skips_missing_file(self):
        file_doc = SimpleNamespace(name="FILE-1")

        with patch.object(
            payments.frappe.db,
            "exists",
            return_value=False,
        ):
            self.assertFalse(
                payments._cleanup_failed_receipt_file(
                    file_doc,
                    SimpleNamespace(name="OMC-PAY-1"),
                )
            )

    @patch.object(payments.frappe, "delete_doc")
    @patch.object(payments.frappe, "get_doc")
    @patch.object(payments.frappe.db, "exists")
    def test_cleanup_deletes_unlinked_receipt(
        self,
        exists,
        get_doc,
        delete_doc,
    ):
        exists.side_effect = [
            True,
            False,
        ]
        get_doc.return_value = SimpleNamespace(
            name="FILE-1",
            attached_to_doctype=payments.PAYMENT_DOCTYPE,
            attached_to_name="OMC-PAY-1",
            file_url="/private/files/r.pdf",
        )

        cleaned = payments._cleanup_failed_receipt_file(
            SimpleNamespace(name="FILE-1"),
            SimpleNamespace(name="OMC-PAY-1"),
        )

        self.assertTrue(cleaned)
        delete_doc.assert_called_once_with(
            "File",
            "FILE-1",
            ignore_permissions=True,
            force=True,
        )

    @patch.object(payments.frappe, "delete_doc")
    @patch.object(payments.frappe, "get_doc")
    @patch.object(payments.frappe.db, "exists")
    def test_cleanup_preserves_linked_receipt(
        self,
        exists,
        get_doc,
        delete_doc,
    ):
        exists.side_effect = [
            True,
            True,
        ]
        get_doc.return_value = SimpleNamespace(
            name="FILE-1",
            attached_to_doctype=payments.PAYMENT_DOCTYPE,
            attached_to_name="OMC-PAY-1",
            file_url="/private/files/r.pdf",
        )

        cleaned = payments._cleanup_failed_receipt_file(
            SimpleNamespace(name="FILE-1"),
            SimpleNamespace(name="OMC-PAY-1"),
        )

        self.assertFalse(cleaned)
        delete_doc.assert_not_called()

    @patch.object(
        payments,
        "_cleanup_failed_receipt_file",
    )
    @patch.object(payments.frappe.db, "commit")
    @patch.object(payments.review_routing, "ensure_review_assignment")
    @patch.object(payments, "_set_case_status")
    @patch.object(
        payments.mobile,
        "_create_service_timeline_entry",
        side_effect=RuntimeError("timeline failed"),
    )
    @patch.object(payments.mobile, "_get_mobile_capabilities")
    @patch.object(payments, "save_file")
    @patch.object(payments, "_assert_payment_customer_access")
    @patch.object(payments.frappe, "get_doc")
    @patch.object(
        payments.frappe.db,
        "exists",
        return_value=True,
    )
    def test_failure_cleans_new_file_and_reraises(
        self,
        _exists,
        get_doc,
        customer_access,
        save_file,
        capabilities,
        _timeline,
        set_status,
        assign_review,
        commit,
        cleanup,
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
        file_doc = SimpleNamespace(
            name="FILE-1",
            file_url="/private/files/r.pdf",
        )

        get_doc.return_value = payment
        customer_access.return_value = (
            SimpleNamespace(name="OMC-CUST-1"),
            service_case,
        )
        save_file.return_value = file_doc
        capabilities.return_value = {
            "can_upload_payment_receipt": True,
        }

        with (
            patch.object(payments.security, "enforce_rate_limit"),
            patch.object(payments.idempotency, "begin", return_value=None),
            patch.object(payments.upload_validation, "validate_upload_bytes", return_value="r.pdf"),
            patch.object(payments.upload_validation, "scan_upload", return_value="Manual Review"),
            self.assertRaisesRegex(RuntimeError, "timeline failed"),
        ):
            payments.upload_payment_receipt_file(
                payment_id=payment.name,
                file_name="r.pdf",
                content_base64="JVBERi0xLjc=",
                idempotency_key="receipt-failure-1",
            )

        cleanup.assert_called_once_with(
            file_doc,
            payment,
        )
        set_status.assert_not_called()
        assign_review.assert_not_called()
        commit.assert_not_called()
