from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import payment_receipt_analysis as analysis


class TestPhase6ReceiptAnalysis(FrappeTestCase):
    def _receipt(self):
        return SimpleNamespace(
            name="OMC-RCP-1",
            service_payment="OMC-PAY-1",
            service_request="OMC-SR-1",
            receipt_attachment="/private/files/receipt.pdf",
            receipt_sha256="abc123",
            review_status="Submitted",
            ai_warnings_json="[]",
        )

    @patch.object(analysis.frappe.db, "set_value")
    @patch.object(analysis, "operational", return_value=False)
    @patch.object(analysis.frappe.db, "exists", return_value=True)
    def test_unconfigured_ai_falls_back_to_manual_review(
        self,
        _exists,
        _operational,
        set_value,
    ):
        result = analysis.schedule_analysis("OMC-RCP-1")

        self.assertEqual(result["status"], "manual_review")
        values = set_value.call_args.args[2]
        self.assertEqual(values["ai_status"], "Manual Review")
        self.assertEqual(values["ai_error_code"], "AI_NOT_CONFIGURED")

    @patch.object(analysis.frappe, "enqueue")
    @patch.object(analysis.frappe.db, "set_value")
    @patch.object(analysis, "operational", return_value=True)
    @patch.object(analysis.frappe.db, "exists", return_value=True)
    def test_configured_ai_queues_after_commit(
        self,
        _exists,
        _operational,
        set_value,
        enqueue,
    ):
        result = analysis.schedule_analysis("OMC-RCP-1")

        self.assertEqual(result["status"], "queued")
        values = set_value.call_args.args[2]
        self.assertEqual(values["ai_status"], "Queued")
        enqueue.assert_called_once_with(
            "omc_app.api.payment_receipt_analysis.analyze_receipt",
            queue="short",
            enqueue_after_commit=True,
            receipt_name="OMC-RCP-1",
        )

    def test_provider_payload_disables_response_storage(self):
        payload = analysis._provider_payload(
            model="gpt-test",
            filename="receipt.pdf",
            content=b"%PDF-1.4\n%%EOF",
        )

        self.assertFalse(payload["store"])
        self.assertEqual(
            payload["text"]["format"]["type"],
            "json_schema",
        )
        self.assertEqual(
            payload["input"][1]["content"][1]["type"],
            "input_file",
        )

    def test_extraction_is_normalized_and_confidence_clamped(self):
        result = analysis._normalise_extraction(
            {
                "amount": "15000",
                "currency": "pkr",
                "transaction_reference": " ABC123 ",
                "transaction_date": "2026-09-18",
                "transaction_time": "15:20",
                "bank_or_wallet": "Meezan",
                "beneficiary_or_account": "OMC",
                "transaction_status": "Successful",
                "confidence": 2,
            }
        )

        self.assertEqual(result["amount"], 15000)
        self.assertEqual(result["currency"], "PKR")
        self.assertEqual(result["transaction_reference"], "ABC123")
        self.assertEqual(result["confidence"], 1.0)

    @patch.object(analysis, "_duplicate_reference_exists", return_value=True)
    @patch.object(analysis, "_duplicate_file_exists", return_value=True)
    def test_warning_engine_detects_partial_currency_duplicate_and_status(
        self,
        _duplicate_file,
        _duplicate_reference,
    ):
        warnings = analysis._build_warnings(
            receipt=self._receipt(),
            extraction={
                "amount": 15000,
                "currency": "USD",
                "transaction_reference": "ABC123",
                "beneficiary_or_account": "wrong-account",
                "transaction_status": "Pending",
            },
            expected_amount=30000,
            expected_currency="PKR",
            payment_accounts=[
                {
                    "account_title": "OMC House",
                    "account_number": "123456",
                    "iban": "PK00OMC123456",
                }
            ],
        )

        codes = {row["code"] for row in warnings}
        self.assertIn("PARTIAL_PAYMENT", codes)
        self.assertIn("CURRENCY_MISMATCH", codes)
        self.assertIn("DUPLICATE_FILE", codes)
        self.assertIn("DUPLICATE_REFERENCE", codes)
        self.assertIn("BENEFICIARY_ACCOUNT_MISMATCH", codes)
        self.assertIn("TRANSACTION_STATUS_NOT_SUCCESSFUL", codes)

    @patch.object(analysis.security, "audit_event")
    @patch.object(analysis.frappe.db, "set_value")
    @patch.object(
        analysis,
        "_analysis_context",
        return_value={
            "expected_amount": 30000,
            "currency": "PKR",
            "payment_accounts": [],
        },
    )
    @patch.object(
        analysis,
        "_call_provider",
        return_value=(
            {
                "amount": 15000,
                "currency": "PKR",
                "transaction_reference": "ABC123",
                "transaction_date": "2026-09-18",
                "transaction_time": "15:20",
                "bank_or_wallet": "Meezan",
                "beneficiary_or_account": None,
                "transaction_status": "Successful",
                "confidence": 0.96,
            },
            "gpt-test",
        ),
    )
    @patch.object(
        analysis,
        "_receipt_file",
        return_value=("receipt.pdf", b"%PDF-1.4\n%%EOF"),
    )
    @patch.object(analysis.frappe, "get_doc")
    @patch.object(
        analysis.frappe.db,
        "get_value",
        return_value="OMC-RCP-1",
    )
    @patch.object(analysis.frappe.db, "exists", return_value=True)
    def test_successful_analysis_only_persists_advisory_result(
        self,
        _exists,
        _lock,
        get_doc,
        _file,
        _provider,
        _context,
        set_value,
        audit,
    ):
        receipt = self._receipt()
        get_doc.return_value = receipt

        result = analysis.analyze_receipt(receipt.name)

        self.assertEqual(result["status"], "completed")
        final_values = set_value.call_args_list[-1].args[2]
        self.assertEqual(final_values["ai_status"], "Completed")
        self.assertEqual(final_values["ai_detected_amount"], 15000)
        self.assertEqual(final_values["ai_detected_reference"], "ABC123")
        self.assertNotIn("verified_amount", final_values)
        self.assertNotIn("accounting_state", final_values)
        audit.assert_called_once()

    @patch.object(analysis.frappe, "log_error")
    @patch.object(analysis, "_mark_manual_review")
    @patch.object(
        analysis,
        "_call_provider",
        side_effect=analysis.ReceiptAnalysisError("PROVIDER_HTTP_503"),
    )
    @patch.object(
        analysis,
        "_receipt_file",
        return_value=("receipt.pdf", b"%PDF-1.4\n%%EOF"),
    )
    @patch.object(analysis.frappe, "get_doc")
    @patch.object(
        analysis.frappe.db,
        "get_value",
        return_value="OMC-RCP-1",
    )
    @patch.object(analysis.frappe.db, "set_value")
    @patch.object(analysis.frappe.db, "exists", return_value=True)
    def test_provider_failure_becomes_manual_review_not_payment_rejection(
        self,
        _exists,
        _set_value,
        _lock,
        get_doc,
        _file,
        _provider,
        manual_review,
        log_error,
    ):
        get_doc.return_value = self._receipt()
        manual_review.return_value = {
            "status": "manual_review",
            "receipt": "OMC-RCP-1",
        }

        result = analysis.analyze_receipt("OMC-RCP-1")

        self.assertEqual(result["status"], "manual_review")
        manual_review.assert_called_once_with(
            "OMC-RCP-1",
            "PROVIDER_HTTP_503",
        )
        log_error.assert_called_once()

    def test_analysis_summary_never_contains_raw_receipt_content(self):
        receipt = self._receipt()
        receipt.ai_status = "Completed"
        receipt.ai_model = "gpt-test"
        receipt.ai_confidence = 0.95
        receipt.ai_detected_amount = 15000
        receipt.ai_detected_currency = "PKR"
        receipt.ai_detected_reference = "ABC123"
        receipt.ai_detected_date = "2026-09-18"
        receipt.ai_detected_time = "15:20"
        receipt.ai_detected_bank = "Meezan"
        receipt.ai_detected_beneficiary = "OMC"
        receipt.ai_detected_status = "Successful"
        receipt.ai_error_code = ""
        receipt.ai_warnings_json = "[]"

        summary = analysis.analysis_summary(receipt)

        self.assertEqual(summary["detected_amount"], 15000)
        self.assertNotIn("base64", summary)
        self.assertNotIn("raw", summary)
