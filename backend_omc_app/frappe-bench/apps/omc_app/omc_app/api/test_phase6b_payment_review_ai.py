import json
from contextlib import contextmanager
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import payment_accounting
from omc_app.api import payment_receipt_analysis as analysis


class TestPhase6BPaymentReviewAI(FrappeTestCase):
    def _payment(self, amount=30000):
        return SimpleNamespace(
            name="OMC-PAY-6B",
            service_request="OMC-SR-6B",
            amount=amount,
            currency="PKR",
            receipt_attachment="/private/files/receipt.pdf",
        )

    def _receipt(
        self,
        *,
        status="Completed",
        confidence=0.96,
        amount=15000,
        currency="PKR",
        warnings=None,
        error_code="",
    ):
        receipt = MagicMock()
        receipt.name = "OMC-RCP-6B"
        receipt.service_payment = "OMC-PAY-6B"
        receipt.service_request = "OMC-SR-6B"
        receipt.receipt_attachment = "/private/files/receipt.pdf"
        receipt.review_status = "Submitted"
        receipt.accounting_state = "Not Started"
        receipt.ai_status = status
        receipt.ai_model = "gpt-test"
        receipt.ai_confidence = confidence
        receipt.ai_detected_amount = amount
        receipt.ai_detected_currency = currency
        receipt.ai_detected_reference = "AI-REF-1"
        receipt.ai_detected_date = "2026-09-18"
        receipt.ai_detected_time = "15:20"
        receipt.ai_detected_bank = "Meezan"
        receipt.ai_detected_beneficiary = "OMC House"
        receipt.ai_detected_status = "Successful"
        receipt.ai_error_code = error_code
        receipt.ai_warnings_json = json.dumps(warnings or [])
        return receipt

    @contextmanager
    def _review_environment(self, payment, receipt, *, remaining=30000):
        with (
            patch.object(payment_accounting, "_require_review_access"),
            patch.object(
                payment_accounting,
                "_current_user",
                return_value="reviewer@example.com",
            ),
            patch.object(
                payment_accounting.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                payment_accounting.frappe,
                "get_doc",
                return_value=payment,
            ),
            patch.object(payment_accounting, "_assert_assigned_reviewer"),
            patch.object(
                payment_accounting,
                "_receipt_for_current_evidence",
                return_value=(receipt, "source-key"),
            ),
            patch.object(
                payment_accounting,
                "_preflight",
                return_value={
                    "currency": "PKR",
                    "payment_account": {"name": "OMC-ACC-1"},
                },
            ),
            patch.object(
                payment_accounting,
                "_remaining_amount",
                return_value=remaining,
            ),
            patch.object(
                payment_accounting.payments,
                "review_payment_receipt",
                return_value={
                    "updated": True,
                    "status": "Under Review",
                    "receipt_status": "Accepted",
                },
            ) as human_review,
            patch.object(
                payment_accounting.security,
                "audit_event",
            ) as audit,
            patch.object(payment_accounting.frappe.db, "commit"),
            patch.object(
                payment_accounting,
                "_queue_receipt",
            ) as queue,
        ):
            yield human_review, audit, queue

    def test_confident_partial_ai_amount_is_safe_suggestion(self):
        state = payment_accounting._ai_review_state(
            self._payment(),
            self._receipt(
                warnings=[
                    {
                        "code": "PARTIAL_PAYMENT",
                        "severity": "info",
                        "message": "Detected amount is below the installment amount.",
                    }
                ]
            ),
            currency="PKR",
            remaining_amount=30000,
        )

        self.assertTrue(state["suggestion_available"])
        self.assertEqual(state["suggested_verified_amount"], 15000)
        self.assertFalse(state["exception_reason_required"])
        self.assertFalse(state["manual_review_required"])

    def test_low_confidence_ai_does_not_suggest_and_requires_exception_reason(self):
        state = payment_accounting._ai_review_state(
            self._payment(),
            self._receipt(confidence=0.70),
            currency="PKR",
            remaining_amount=30000,
        )

        self.assertFalse(state["suggestion_available"])
        self.assertIsNone(state["suggested_verified_amount"])
        self.assertTrue(state["manual_review_required"])
        self.assertTrue(state["exception_reason_required"])

    def test_manual_review_ai_requires_exception_reason(self):
        state = payment_accounting._ai_review_state(
            self._payment(),
            self._receipt(
                status="Manual Review",
                confidence=0,
                amount=None,
                error_code="AI_NOT_CONFIGURED",
            ),
            currency="PKR",
            remaining_amount=30000,
        )

        self.assertTrue(state["manual_review_required"])
        self.assertTrue(state["exception_reason_required"])
        self.assertFalse(state["suggestion_available"])

    def test_critical_warning_is_visible_and_blocks_default_suggestion_only(self):
        state = payment_accounting._ai_review_state(
            self._payment(),
            self._receipt(
                warnings=[
                    {
                        "code": "DUPLICATE_REFERENCE",
                        "severity": "warning",
                        "message": "Duplicate reference.",
                    }
                ]
            ),
            currency="PKR",
            remaining_amount=30000,
        )

        self.assertIn("DUPLICATE_REFERENCE", state["warning_codes"])
        self.assertFalse(state["suggestion_available"])
        self.assertTrue(state["manual_review_required"])
        self.assertFalse(state["exception_reason_required"])

    def test_amount_above_installment_is_never_suggested(self):
        state = payment_accounting._ai_review_state(
            self._payment(amount=30000),
            self._receipt(amount=35000),
            currency="PKR",
            remaining_amount=30000,
        )

        self.assertFalse(state["suggestion_available"])
        self.assertEqual(state["confident_detected_amount"], 35000)

    def test_amount_above_erp_remaining_is_never_suggested(self):
        state = payment_accounting._ai_review_state(
            self._payment(amount=30000),
            self._receipt(amount=20000),
            currency="PKR",
            remaining_amount=15000,
        )

        self.assertFalse(state["suggestion_available"])
        self.assertEqual(state["confident_detected_amount"], 20000)

    @patch.object(payment_accounting, "_receipt_for_current_evidence")
    @patch.object(payment_accounting, "_remaining_amount", return_value=22000)
    @patch.object(
        payment_accounting,
        "_mapped_payment_accounts",
        return_value=[
            {
                "name": "OMC-ACC-1",
                "title": "Meezan",
                "bank_name": "Meezan Bank",
                "account_title": "OMC House",
                "account_number": "123",
                "iban": "PK00OMC123",
                "erp_account": "Bank - OMC",
                "mode_of_payment": "Bank Transfer",
            }
        ],
    )
    @patch.object(payment_accounting, "_assert_assigned_reviewer")
    @patch.object(
        payment_accounting,
        "_current_user",
        return_value="reviewer@example.com",
    )
    @patch.object(payment_accounting.frappe, "get_doc")
    @patch.object(payment_accounting.frappe.db, "exists", return_value=True)
    @patch.object(payment_accounting, "_require_review_access")
    def test_review_context_exposes_receipt_ai_warnings_and_safe_default(
        self,
        _access,
        _exists,
        get_doc,
        _user,
        _assigned,
        _accounts,
        _remaining,
        receipt_lookup,
    ):
        payment = self._payment()
        request = SimpleNamespace(
            company_snapshot="OMC Company",
            pricing_currency="PKR",
        )
        receipt = self._receipt(
            warnings=[
                {
                    "code": "PARTIAL_PAYMENT",
                    "severity": "info",
                    "message": "Partial payment.",
                }
            ]
        )
        get_doc.side_effect = [payment, request]
        receipt_lookup.return_value = (receipt, "source-key")

        context = payment_accounting.get_review_context(payment_id=payment.name)

        self.assertEqual(context["receipt_url"], receipt.receipt_attachment)
        self.assertEqual(context["expected_amount"], 30000)
        self.assertEqual(context["erp_remaining_amount"], 22000)
        self.assertEqual(context["suggested_verified_amount"], 15000)
        self.assertEqual(context["ai"]["detected_reference"], "AI-REF-1")
        self.assertEqual(context["ai_warnings"][0]["code"], "PARTIAL_PAYMENT")
        self.assertEqual(context["payment_accounts"][0]["bank_name"], "Meezan Bank")

    def test_changing_confident_ai_amount_without_reason_fails(self):
        payment = self._payment()
        receipt = self._receipt(amount=15000)

        with self._review_environment(payment, receipt) as (
            human_review,
            _audit,
            queue,
        ):
            with self.assertRaisesRegex(
                frappe.ValidationError,
                "override reason",
            ):
                payment_accounting.review_receipt(
                    payment_id=payment.name,
                    decision="Verified",
                    verified_amount=14000,
                    payment_account="OMC-ACC-1",
                )

        human_review.assert_not_called()
        queue.assert_not_called()

    def test_changing_confident_ai_amount_with_reason_uses_human_review_path(self):
        payment = self._payment()
        receipt = self._receipt(amount=15000)

        with self._review_environment(payment, receipt) as (
            human_review,
            audit,
            queue,
        ):
            result = payment_accounting.review_receipt(
                payment_id=payment.name,
                decision="Verified",
                verified_amount=14000,
                payment_account="OMC-ACC-1",
                ai_override_reason="Receipt shows fee adjustment.",
            )

        human_review.assert_called_once()
        queue.assert_called_once_with(receipt.name)
        receipt.save.assert_called_once_with(ignore_permissions=True)
        self.assertEqual(receipt.review_status, "Verified")
        self.assertEqual(receipt.verified_amount, 14000)
        self.assertEqual(
            receipt.ai_override_reason,
            "Receipt shows fee adjustment.",
        )
        event_types = [call.kwargs.get("event_type") for call in audit.call_args_list]
        self.assertIn("payment.receipt_verified", event_types)
        self.assertIn("payment.receipt_ai_override", event_types)
        self.assertTrue(result["accounting_queued"])

    def test_ai_failure_manual_verification_without_reason_fails(self):
        payment = self._payment()
        receipt = self._receipt(
            status="Manual Review",
            confidence=0,
            amount=None,
            error_code="PROVIDER_HTTP_503",
        )

        with self._review_environment(payment, receipt) as (
            human_review,
            _audit,
            queue,
        ):
            with self.assertRaisesRegex(
                frappe.ValidationError,
                "exception reason",
            ):
                payment_accounting.review_receipt(
                    payment_id=payment.name,
                    decision="Verified",
                    verified_amount=15000,
                    payment_account="OMC-ACC-1",
                )

        human_review.assert_not_called()
        queue.assert_not_called()

    def test_ai_failure_manual_verification_with_reason_can_proceed(self):
        payment = self._payment()
        receipt = self._receipt(
            status="Manual Review",
            confidence=0,
            amount=None,
            error_code="AI_NOT_CONFIGURED",
        )

        with self._review_environment(payment, receipt) as (
            human_review,
            audit,
            queue,
        ):
            result = payment_accounting.review_receipt(
                payment_id=payment.name,
                decision="Verified",
                verified_amount=15000,
                payment_account="OMC-ACC-1",
                ai_override_reason="AI unavailable; original receipt checked manually.",
            )

        human_review.assert_called_once()
        queue.assert_called_once_with(receipt.name)
        self.assertEqual(receipt.verified_amount, 15000)
        self.assertTrue(result["ai_override_reason_recorded"])
        override_events = [
            call
            for call in audit.call_args_list
            if call.kwargs.get("event_type") == "payment.receipt_ai_override"
        ]
        self.assertEqual(len(override_events), 1)
        self.assertEqual(
            override_events[0].kwargs.get("safe_reason"),
            "manual_ai_exception",
        )

    def test_verified_amount_above_installment_remains_rejected(self):
        payment = self._payment(amount=30000)
        receipt = self._receipt(amount=30000)

        with self._review_environment(payment, receipt) as (
            human_review,
            _audit,
            queue,
        ):
            with self.assertRaisesRegex(
                frappe.ValidationError,
                "installment amount",
            ):
                payment_accounting.review_receipt(
                    payment_id=payment.name,
                    decision="Verified",
                    verified_amount=30001,
                    payment_account="OMC-ACC-1",
                    ai_override_reason="Manual correction.",
                )

        human_review.assert_not_called()
        queue.assert_not_called()

    def test_verified_amount_above_erp_remaining_remains_rejected(self):
        payment = self._payment(amount=30000)
        receipt = self._receipt(amount=20000)

        with self._review_environment(
            payment,
            receipt,
            remaining=15000,
        ) as (
            human_review,
            _audit,
            queue,
        ):
            with self.assertRaisesRegex(
                frappe.ValidationError,
                "remaining amount",
            ):
                payment_accounting.review_receipt(
                    payment_id=payment.name,
                    decision="Verified",
                    verified_amount=20000,
                    payment_account="OMC-ACC-1",
                )

        human_review.assert_not_called()
        queue.assert_not_called()

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
                "transaction_reference": "AI-REF-1",
                "transaction_date": "2026-09-18",
                "transaction_time": "15:20",
                "bank_or_wallet": "Meezan",
                "beneficiary_or_account": "OMC House",
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
        return_value="OMC-RCP-6B",
    )
    @patch.object(analysis.frappe.db, "exists", return_value=True)
    def test_ai_analysis_never_invokes_human_review_or_accounting(
        self,
        _exists,
        _lock,
        get_doc,
        _file,
        _provider,
        _context,
        _set_value,
        _audit,
    ):
        receipt = self._receipt()
        get_doc.return_value = receipt

        with (
            patch.object(payment_accounting, "review_receipt") as human_review,
            patch.object(payment_accounting, "process_receipt") as accounting,
        ):
            result = analysis.analyze_receipt(receipt.name)

        self.assertEqual(result["status"], "completed")
        human_review.assert_not_called()
        accounting.assert_not_called()
