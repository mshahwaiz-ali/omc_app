from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import payment_mutation_guard, payments
from omc_app.omc_app.doctype.omc_payment_receipt.omc_payment_receipt import (
    OMCPaymentReceipt,
)


class TestPhase5StaffReceiptUpload(FrappeTestCase):
    @staticmethod
    def _payment():
        return SimpleNamespace(
            name="OMC-PAY-TEST",
            service_request="OMC-SR-TEST",
            status="Pending",
            accounted_amount=0,
            receipt_attachment="",
        )

    def test_receipt_submission_source_is_immutable_evidence(self):
        self.assertIn(
            "submission_source",
            OMCPaymentReceipt.IMMUTABLE_FIELDS,
        )

    @patch.object(
        payment_mutation_guard.payments,
        "_assert_service_request_payment_access",
    )
    @patch.object(
        payment_mutation_guard.frappe,
        "get_doc",
        return_value=SimpleNamespace(name="OMC-SR-TEST"),
    )
    @patch.object(
        payment_mutation_guard.access,
        "get_mobile_capabilities",
        return_value={
            "can_access_internal_workspace": True,
            "can_review_payments": True,
        },
    )
    @patch.object(
        payment_mutation_guard.payments,
        "_current_user",
        return_value="finance@example.com",
    )
    def test_staff_access_requires_review_capability_and_service_scope(
        self,
        _user,
        _capabilities,
        _get_doc,
        assert_scope,
    ):
        actor, service_case = (
            payment_mutation_guard._require_staff_receipt_upload_access(
                self._payment()
            )
        )

        self.assertEqual(actor, "finance@example.com")
        self.assertEqual(service_case.name, "OMC-SR-TEST")
        assert_scope.assert_called_once_with(
            "OMC-SR-TEST",
            internal_user="finance@example.com",
        )

    @patch.object(
        payment_mutation_guard.access,
        "get_mobile_capabilities",
        return_value={
            "can_access_internal_workspace": True,
            "can_review_payments": False,
        },
    )
    @patch.object(
        payment_mutation_guard.payments,
        "_current_user",
        return_value="staff@example.com",
    )
    def test_staff_upload_rejects_internal_user_without_payment_review_capability(
        self,
        _user,
        _capabilities,
    ):
        with self.assertRaises(frappe.PermissionError):
            payment_mutation_guard._require_staff_receipt_upload_access(
                self._payment()
            )

    @patch.object(
        payment_mutation_guard,
        "_restore_activated_case_status",
    )
    @patch.object(
        payment_mutation_guard,
        "_activated_case_snapshot",
        return_value=None,
    )
    @patch.object(
        payment_mutation_guard.payments,
        "_submit_payment_receipt_base64",
        return_value={"updated": True},
    )
    @patch.object(
        payment_mutation_guard,
        "_require_staff_receipt_upload_access",
        return_value=(
            "finance@example.com",
            SimpleNamespace(name="OMC-SR-TEST"),
        ),
    )
    @patch.object(
        payment_mutation_guard,
        "_assert_receipt_upload_allowed",
    )
    @patch.object(
        payment_mutation_guard,
        "_load_mutable_payment",
    )
    def test_staff_endpoint_uses_shared_pipeline_with_staff_provenance(
        self,
        load_payment,
        _assert_upload,
        _staff_access,
        submit,
        _snapshot,
        restore,
    ):
        payment = self._payment()
        load_payment.return_value = payment

        result = payment_mutation_guard.staff_upload_payment_receipt_file(
            payment_id=payment.name,
            file_name="receipt.pdf",
            content_base64="JVBERi0xLjc=",
            payment_reference="REF-1",
            remarks="Uploaded by finance",
            idempotency_key="phase5-test-1",
        )

        self.assertTrue(result["updated"])
        submit.assert_called_once_with(
            payment=payment,
            service_case=SimpleNamespace(name="OMC-SR-TEST"),
            file_name="receipt.pdf",
            content_base64="JVBERi0xLjc=",
            payment_reference="REF-1",
            remarks="Uploaded by finance",
            idempotency_key="phase5-test-1",
            submission_source="Staff On Behalf",
            submitted_by="finance@example.com",
        )
        restore.assert_called_once_with(payment, None)

    @patch.object(payments.security, "audit_event")
    @patch.object(payments.frappe, "new_doc")
    @patch.object(payments.frappe.db, "get_value", return_value=None)
    def test_evidence_records_explicit_staff_provenance(
        self,
        _get_value,
        new_doc,
        audit_event,
    ):
        doc = MagicMock()
        doc.name = "OMC-RCP-1"
        new_doc.return_value = doc
        payment = SimpleNamespace(
            name="OMC-PAY-1",
            service_request="OMC-SR-1",
            currency="PKR",
        )

        result = payments._record_receipt_evidence(
            payment=payment,
            receipt_attachment="/private/files/receipt.pdf",
            payment_reference="REF-1",
            remarks="Staff upload",
            submission_source="Staff On Behalf",
            submitted_by="finance@example.com",
            submitted_at="2026-09-18 22:00:00",
        )

        self.assertIs(result, doc)
        self.assertEqual(doc.submission_source, "Staff On Behalf")
        self.assertEqual(doc.submitted_by, "finance@example.com")
        self.assertEqual(doc.submitted_at, "2026-09-18 22:00:00")
        doc.insert.assert_called_once_with(ignore_permissions=True)
        audit_event.assert_called_once()
