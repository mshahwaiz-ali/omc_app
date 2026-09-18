from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import bridge_outbox, payment_accounting_hooks
from omc_app.omc_app.doctype.omc_service_payment.omc_service_payment import (
    ALLOWED_PAYMENT_STATUS_TRANSITIONS,
)


class TestVerifiedPaymentActivation(FrappeTestCase):
    def _request(self, policy):
        return SimpleNamespace(
            name="OMC-SR-PAYMENT-POLICY",
            request_state="Pending Payment",
            payment_policy_snapshot=policy,
            payable_amount=100,
            post_paid_approved_by=None,
            post_paid_approved_at=None,
        )

    def test_verified_partial_payment_is_activation_evidence(self):
        request = self._request("Verified Payment")
        with (
            patch.object(bridge_outbox, "_accounting_status", return_value="Partially Settled"),
            patch.object(bridge_outbox, "_accounted_amount", return_value=50),
        ):
            self.assertTrue(bridge_outbox.eligibility(request)["eligible"])

    def test_full_settlement_snapshot_also_starts_after_verified_partial_payment(self):
        request = self._request("Full Settlement")
        with (
            patch.object(bridge_outbox, "_accounting_status", return_value="Partially Settled"),
            patch.object(bridge_outbox, "_accounted_amount", return_value=50),
        ):
            self.assertTrue(bridge_outbox.eligibility(request)["eligible"])

    def test_unverified_or_zero_accounted_payment_is_not_activation_evidence(self):
        request = self._request("Full Settlement")
        for status, amount in (("Unmatched", 0), ("Partially Settled", 0), ("Review Required", 50), ("Reversed", 50)):
            with self.subTest(status=status, amount=amount):
                with (
                    patch.object(bridge_outbox, "_accounting_status", return_value=status),
                    patch.object(bridge_outbox, "_accounted_amount", return_value=amount),
                ):
                    self.assertFalse(bridge_outbox.eligibility(request)["eligible"])

    def test_settled_positive_payment_remains_activation_evidence(self):
        request = self._request("Full Settlement")
        with (
            patch.object(bridge_outbox, "_accounting_status", return_value="Settled"),
            patch.object(bridge_outbox, "_accounted_amount", return_value=100),
        ):
            self.assertTrue(bridge_outbox.eligibility(request)["eligible"])

    def test_accounted_amount_only_counts_submitted_clean_allocations(self):
        with patch.object(bridge_outbox.frappe, "get_all", return_value=[500, 250]) as get_all:
            self.assertEqual(bridge_outbox._accounted_amount("OMC-SR-1"), 750)

        get_all.assert_called_once_with(
            "OMC Accounting Link",
            filters={
                "service_request": "OMC-SR-1",
                "payment_entry": ["is", "set"],
                "payment_docstatus": 1,
                "accounting_status": ["in", ["Partially Settled", "Settled"]],
            },
            pluck="allocated_amount",
            limit_page_length=1000,
        )

    def test_partial_payment_can_receive_a_follow_up_receipt(self):
        self.assertIn(
            "Receipt Submitted",
            ALLOWED_PAYMENT_STATUS_TRANSITIONS["Partially Paid"],
        )

    def test_request_projection_does_not_overwrite_installment_state(self):
        with (
            patch.object(
                payment_accounting_hooks.accounting_reconciliation,
                "reconcile_request",
                return_value={"accounting_status": "Partially Settled"},
            ),
            patch.object(
                payment_accounting_hooks.frappe.db,
                "set_value",
            ) as set_value,
            patch.object(
                payment_accounting_hooks.bridge_outbox,
                "enqueue_if_eligible",
            ) as enqueue,
        ):
            result = payment_accounting_hooks.project_request_payment_state(
                "OMC-SR-1"
            )

        self.assertEqual(result["accounting_status"], "Partially Settled")
        set_value.assert_not_called()
        enqueue.assert_not_called()
