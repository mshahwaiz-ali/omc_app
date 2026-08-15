from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app import hooks
from omc_app.api import payment_mutation_guard, payments


class TestPaymentMutationGuard(FrappeTestCase):
    def _payment(self, *, status="Pending", service_request="OMC-SR-TEST"):
        return SimpleNamespace(
            name="OMC-PAY-TEST",
            service_request=service_request,
            status=status,
            remarks="",
            payment_reference="",
            paid_on=None,
            receipt_attachment="",
        )

    def test_hooks_route_payment_mutations_through_guard(self):
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.payments.upload_payment_receipt_file"
            ],
            "omc_app.api.payment_mutation_guard.upload_payment_receipt_file",
        )
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.payments.upload_payment_receipt_multipart"
            ],
            "omc_app.api.payment_mutation_guard.upload_payment_receipt_multipart",
        )
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.payments.review_payment_receipt"
            ],
            "omc_app.api.payment_mutation_guard.review_payment_receipt",
        )

    @patch("omc_app.api.payment_mutation_guard.frappe.get_doc")
    @patch("omc_app.api.payment_mutation_guard.frappe.db.exists", return_value=True)
    def test_terminal_payment_is_rejected_before_delegation(self, exists, get_doc):
        get_doc.return_value = self._payment(status="Paid")

        with self.assertRaises(frappe.ValidationError):
            payment_mutation_guard._load_mutable_payment("OMC-PAY-TEST")

    @patch("omc_app.api.payment_mutation_guard.frappe.db.get_value", return_value="Completed")
    @patch("omc_app.api.payment_mutation_guard.frappe.get_doc")
    @patch("omc_app.api.payment_mutation_guard.frappe.db.exists", return_value=True)
    def test_terminal_parent_is_rejected_before_delegation(
        self,
        exists,
        get_doc,
        get_value,
    ):
        get_doc.return_value = self._payment(status="Pending")

        with self.assertRaises(frappe.ValidationError):
            payment_mutation_guard._load_mutable_payment("OMC-PAY-TEST")

    def test_blank_parent_reference_is_hidden_as_missing_payment(self):
        with self.assertRaises(frappe.DoesNotExistError):
            payment_mutation_guard._load_parent_status(
                self._payment(service_request="")
            )

    @patch("omc_app.api.payment_mutation_guard.frappe.db.exists", return_value=False)
    def test_missing_parent_row_is_hidden_as_missing_payment(self, exists):
        with self.assertRaises(frappe.DoesNotExistError):
            payment_mutation_guard._load_parent_status(self._payment())

        exists.assert_called_once_with(
            "OMC Service Request",
            "OMC-SR-TEST",
        )

    @patch("omc_app.api.payment_mutation_guard.frappe.db.get_value", return_value=None)
    @patch("omc_app.api.payment_mutation_guard.frappe.db.exists", return_value=True)
    def test_parent_without_status_is_hidden_as_missing_payment(self, exists, get_value):
        with self.assertRaises(frappe.DoesNotExistError):
            payment_mutation_guard._load_parent_status(self._payment())

    @patch("omc_app.api.payment_mutation_guard.payments.upload_payment_receipt_file")
    @patch("omc_app.api.payment_mutation_guard._load_mutable_payment")
    def test_receipt_upload_delegates_only_after_guard(self, load_payment, upload):
        load_payment.return_value = self._payment(status="Pending")
        upload.return_value = {"updated": True}

        result = payment_mutation_guard.upload_payment_receipt_file(
            payment_id="OMC-PAY-TEST",
            file_name="receipt.pdf",
            content_base64="ZGF0YQ==",
            payment_reference="BANK-1",
            remarks="Submitted",
            idempotency_key=None,
        )

        load_payment.assert_called_once_with("OMC-PAY-TEST")
        upload.assert_called_once_with(
            payment_id="OMC-PAY-TEST",
            file_name="receipt.pdf",
            content_base64="ZGF0YQ==",
            payment_reference="BANK-1",
            remarks="Submitted",
            idempotency_key=None,
        )
        self.assertTrue(result["updated"])


    @patch(
        "omc_app.api.payment_mutation_guard.payments.upload_payment_receipt_multipart"
    )
    @patch("omc_app.api.payment_mutation_guard._load_mutable_payment")
    def test_multipart_receipt_upload_delegates_only_after_guard(
        self,
        load_payment,
        upload,
    ):
        load_payment.return_value = self._payment(status="Pending")
        upload.return_value = {"updated": True}

        result = payment_mutation_guard.upload_payment_receipt_multipart(
            payment_id="OMC-PAY-TEST",
            payment_reference="BANK-2",
            remarks="Multipart receipt",
            idempotency_key="idem-1",
        )

        load_payment.assert_called_once_with("OMC-PAY-TEST")
        upload.assert_called_once_with(
            payment_id="OMC-PAY-TEST",
            payment_reference="BANK-2",
            remarks="Multipart receipt",
            idempotency_key="idem-1",
        )
        self.assertTrue(result["updated"])

    @patch.object(payments, "_apply_payment_receipt")
    @patch.object(payments, "save_file")
    @patch.object(payments.idempotency, "begin", return_value=None)
    @patch.object(
        payments.upload_validation,
        "read_multipart_upload",
        return_value=("receipt.pdf", b"receipt-data"),
    )
    @patch.object(
        payments.customer_service_access,
        "assert_service_request_action",
    )
    @patch.object(payments.frappe, "get_doc")
    @patch.object(payments.frappe.db, "exists", return_value=True)
    def test_multipart_receipt_uses_assisted_customer_authority(
        self,
        _exists,
        get_doc,
        assert_action,
        _read_upload,
        _idempotency,
        save_file,
        apply_receipt,
    ):
        payment = self._payment(status="Pending")
        service_case = SimpleNamespace(
            name="OMC-SR-TEST",
            status="Waiting for Payment",
        )
        get_doc.return_value = payment

        assert_action.return_value = {
            "service_case": service_case,
            "profile": None,
            "is_internal": True,
            "scope_type": "my_referral",
            "capabilities": {
                "can_upload_payment_receipt": False,
                "can_upload_payment_receipts": False,
                "can_upload_customer_payment_receipt": True,
            },
        }

        file_doc = SimpleNamespace(
            name="FILE-1",
            file_url="/private/files/receipt.pdf",
        )
        save_file.return_value = file_doc
        apply_receipt.return_value = {"updated": True}

        result = payments.upload_payment_receipt_multipart(
            payment_id="OMC-PAY-TEST",
            payment_reference="BANK-3",
            remarks="Customer paid",
        )

        assert_action.assert_called_once_with(
            "OMC-SR-TEST",
            internal_capability="can_upload_customer_payment_receipt",
        )
        apply_receipt.assert_called_once()
        self.assertTrue(result["updated"])

    @patch.object(payments.upload_validation, "read_multipart_upload")
    @patch.object(
        payments.customer_service_access,
        "assert_service_request_action",
        side_effect=frappe.PermissionError,
    )
    @patch.object(payments.frappe, "get_doc")
    @patch.object(payments.frappe.db, "exists", return_value=True)
    def test_denied_assisted_payment_scope_rejects_before_reading_upload(
        self,
        _exists,
        get_doc,
        _assert_action,
        read_upload,
    ):
        get_doc.return_value = self._payment(status="Pending")

        with self.assertRaises(frappe.PermissionError):
            payments.upload_payment_receipt_multipart(
                payment_id="OMC-PAY-TEST",
            )

        read_upload.assert_not_called()

    @patch("omc_app.api.payment_mutation_guard.payments.review_payment_receipt")
    @patch("omc_app.api.payment_mutation_guard._noop_review_response")
    @patch("omc_app.api.payment_mutation_guard._load_mutable_payment")
    def test_duplicate_review_returns_noop_without_side_effects(
        self,
        load_payment,
        noop_response,
        review,
    ):
        payment = self._payment(status="Under Review")
        payment.remarks = "Checking"
        payment.payment_reference = "BANK-1"
        load_payment.return_value = payment
        noop_response.return_value = {"updated": False}

        result = payment_mutation_guard.review_payment_receipt(
            payment_id="OMC-PAY-TEST",
            status="Under Review",
            remarks="Checking",
            payment_reference="BANK-1",
        )

        review.assert_not_called()
        noop_response.assert_called_once_with(payment)
        self.assertFalse(result["updated"])

    @patch(
        "omc_app.api.payment_mutation_guard._load_parent_status",
        return_value=("OMC-SR-TEST", "In Progress"),
    )
    def test_noop_response_uses_verified_parent_status(self, load_parent_status):
        payment = self._payment(status="Under Review")

        result = payment_mutation_guard._noop_review_response(payment)

        self.assertFalse(result["updated"])
        self.assertEqual(result["case_id"], "OMC-SR-TEST")
        self.assertEqual(result["case_status"], "In Progress")
        load_parent_status.assert_called_once_with(payment)

    @patch("omc_app.api.payment_mutation_guard.payments.review_payment_receipt")
    @patch("omc_app.api.payment_mutation_guard._load_mutable_payment")
    def test_changed_review_delegates_to_canonical_handler(self, load_payment, review):
        load_payment.return_value = self._payment(status="Receipt Submitted")
        review.return_value = {"updated": True, "status": "Under Review"}

        result = payment_mutation_guard.review_payment_receipt(
            payment_id="OMC-PAY-TEST",
            status="Under Review",
            remarks="Checking",
            payment_reference="BANK-1",
        )

        review.assert_called_once_with(
            payment_id="OMC-PAY-TEST",
            status="Under Review",
            remarks="Checking",
            payment_reference="BANK-1",
        )
        self.assertEqual(result["status"], "Under Review")
