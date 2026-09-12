from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import (
    accounting_reconciliation,
    bridge_outbox,
    payment_installments,
    scheduler_jobs,
)


class TestAccountingSettlementState(FrappeTestCase):
    def test_partial_settlement_remains_partial_without_reversal(self):
        state, allocated = accounting_reconciliation.settlement_state(
            required=50000,
            invoice_basis=50000,
            allocated=20000,
        )

        self.assertEqual(state, "Partially Settled")
        self.assertEqual(allocated, 20000)

    def test_cancelled_payment_keeps_partial_replacement_reversed(self):
        state, allocated = accounting_reconciliation.settlement_state(
            required=50000,
            invoice_basis=50000,
            allocated=20000,
            reversed_exists=True,
        )

        self.assertEqual(state, "Reversed")
        self.assertEqual(allocated, 20000)

    def test_full_replacement_settlement_clears_historical_reversal(self):
        state, allocated = accounting_reconciliation.settlement_state(
            required=50000,
            invoice_basis=50000,
            allocated=50000,
            reversed_exists=True,
        )

        self.assertEqual(state, "Settled")
        self.assertEqual(allocated, 50000)

    def test_technical_quarantine_overrides_full_allocation(self):
        state, _ = accounting_reconciliation.settlement_state(
            required=50000,
            invoice_basis=50000,
            allocated=50000,
            technical_reason="broken accounting evidence",
            reversed_exists=True,
        )

        self.assertEqual(state, "Quarantined")

    def test_human_review_overrides_full_allocation(self):
        state, _ = accounting_reconciliation.settlement_state(
            required=50000,
            invoice_basis=50000,
            allocated=50000,
            invalid_reason="customer mismatch",
            reversed_exists=True,
        )

        self.assertEqual(state, "Review Required")


class TestInstallmentSettlementState(FrappeTestCase):
    def test_full_installment_allocation_is_paid(self):
        accounting_status, payment_status = accounting_reconciliation.installment_state(
            requested=20000,
            accounted=20000,
        )

        self.assertEqual(accounting_status, "Settled")
        self.assertEqual(payment_status, "Paid")

    def test_partial_installment_allocation_is_not_fully_paid(self):
        accounting_status, payment_status = accounting_reconciliation.installment_state(
            requested=20000,
            accounted=10000,
        )

        self.assertEqual(accounting_status, "Partially Settled")
        self.assertEqual(payment_status, "Partially Paid")

    def test_zero_installment_allocation_remains_unmatched(self):
        accounting_status, payment_status = accounting_reconciliation.installment_state(
            requested=20000,
            accounted=0,
        )

        self.assertEqual(accounting_status, "Unmatched")
        self.assertEqual(payment_status, "Under Review")


class TestInstallmentCreationHoldGate(FrappeTestCase):
    def test_review_required_blocks_new_payment(self):
        reason = payment_installments._new_payment_block_reason(
            "Review Required",
            "SINV-TEST-00001",
        )

        self.assertTrue(reason)

    def test_quarantine_blocks_new_payment(self):
        reason = payment_installments._new_payment_block_reason(
            "Quarantined",
            "SINV-TEST-00001",
        )

        self.assertTrue(reason)

    def test_reversal_allows_recovery_when_invoice_is_still_submitted(self):
        with patch.object(payment_installments, "_invoice_is_submitted", return_value=True):
            reason = payment_installments._new_payment_block_reason(
                "Reversed",
                "SINV-TEST-00001",
            )

        self.assertEqual(reason, "")

    def test_reversal_blocks_payment_when_invoice_is_cancelled(self):
        with patch.object(payment_installments, "_invoice_is_submitted", return_value=False):
            reason = payment_installments._new_payment_block_reason(
                "Reversed",
                "SINV-TEST-00001",
            )

        self.assertTrue(reason)


class TestActivationPaymentEvidence(FrappeTestCase):
    @staticmethod
    def _request(policy):
        return SimpleNamespace(
            name="OMC-SR-TEST-00001",
            payment_policy_snapshot=policy,
        )

    def test_full_settlement_policy_rejects_partial_accounting(self):
        with patch.object(
            bridge_outbox,
            "_accounting_status",
            return_value="Partially Settled",
        ):
            evidence = bridge_outbox._payment_evidence(
                self._request("Full Settlement")
            )

        self.assertFalse(evidence["valid"])
        self.assertEqual(evidence["reason"], "Full ERP settlement is required.")

    def test_legacy_verified_payment_snapshot_rejects_partial_accounting(self):
        with patch.object(
            bridge_outbox,
            "_accounting_status",
            return_value="Partially Settled",
        ):
            evidence = bridge_outbox._payment_evidence(
                self._request("Verified Payment")
            )

        self.assertFalse(evidence["valid"])
        self.assertEqual(evidence["reason"], "Full ERP settlement is required.")

    def test_legacy_verified_payment_snapshot_accepts_full_settlement(self):
        with patch.object(
            bridge_outbox,
            "_accounting_status",
            return_value="Settled",
        ):
            evidence = bridge_outbox._payment_evidence(
                self._request("Verified Payment")
            )

        self.assertTrue(evidence["valid"])
        self.assertEqual(evidence["reason"], "")


class TestAccountingReconciliationSweep(FrappeTestCase):
    def test_sweep_reconciles_each_linked_request_once(self):
        with (
            patch.object(
                scheduler_jobs.frappe,
                "get_all",
                return_value=[
                    "OMC-SR-TEST-00002",
                    "OMC-SR-TEST-00001",
                    "OMC-SR-TEST-00002",
                    "",
                ],
            ),
            patch.object(
                scheduler_jobs.accounting_reconciliation,
                "reconcile_request",
            ) as reconcile,
            patch.object(scheduler_jobs.frappe.db, "commit"),
        ):
            result = scheduler_jobs.run_accounting_reconciliation_sweep()

        self.assertEqual(
            [call.args[0] for call in reconcile.call_args_list],
            ["OMC-SR-TEST-00001", "OMC-SR-TEST-00002"],
        )
        self.assertEqual(result["checked"], 3)
        self.assertEqual(result["completed"], 2)
        self.assertEqual(result["failed"], 0)

    def test_sweep_isolates_one_request_failure(self):
        def reconcile(request_name):
            if request_name == "OMC-SR-TEST-00001":
                raise RuntimeError("boom")

        with (
            patch.object(
                scheduler_jobs.frappe,
                "get_all",
                return_value=["OMC-SR-TEST-00001", "OMC-SR-TEST-00002"],
            ),
            patch.object(
                scheduler_jobs.accounting_reconciliation,
                "reconcile_request",
                side_effect=reconcile,
            ) as reconcile_request,
            patch.object(scheduler_jobs.frappe.db, "commit"),
            patch.object(scheduler_jobs.frappe.db, "rollback") as rollback,
            patch.object(scheduler_jobs.frappe, "log_error"),
        ):
            result = scheduler_jobs.run_accounting_reconciliation_sweep()

        self.assertEqual(reconcile_request.call_count, 2)
        rollback.assert_called_once()
        self.assertEqual(result["completed"], 1)
        self.assertEqual(result["failed"], 1)
        self.assertEqual(result["failed_requests"], ["OMC-SR-TEST-00001"])
