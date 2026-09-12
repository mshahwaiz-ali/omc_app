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

    def test_legacy_verified_payment_requires_full_settlement(self):
        request = self._request("Verified Payment")
        with patch.object(
            bridge_outbox,
            "_accounting_status",
            return_value="Partially Settled",
        ):
            self.assertFalse(bridge_outbox.eligibility(request)["eligible"])
        with patch.object(
            bridge_outbox,
            "_accounting_status",
            return_value="Settled",
        ):
            self.assertTrue(bridge_outbox.eligibility(request)["eligible"])

    def test_full_settlement_policy_still_rejects_partial_settlement(self):
        request = self._request("Full Settlement")
        with patch.object(
            bridge_outbox,
            "_accounting_status",
            return_value="Partially Settled",
        ):
            self.assertFalse(bridge_outbox.eligibility(request)["eligible"])
        with patch.object(
            bridge_outbox,
            "_accounting_status",
            return_value="Settled",
        ):
            self.assertTrue(bridge_outbox.eligibility(request)["eligible"])

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
        enqueue.assert_called_once_with("OMC-SR-1")
