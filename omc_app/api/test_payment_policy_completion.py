from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import workflow_automation


class TestPaymentPolicyCompletion(FrappeTestCase):
    def _case(self, policy):
        return SimpleNamespace(
            name="OMC-SR-COMPLETION-POLICY",
            service="TEST-SERVICE",
            customer_profile="OMC-CUST-TEST",
            payment_policy_snapshot=policy,
            payment_execution_mode="Prepaid",
            post_paid_approved_by=None,
            post_paid_approved_at=None,
            pay_later_reason=None,
            erp_task=None,
        )

    def _blockers(self, service_case, payment_status):
        with (
            patch.object(
                workflow_automation.mobile,
                "_service_required_documents",
                return_value=[],
            ),
            patch.object(
                workflow_automation.mobile,
                "_required_documents_complete",
                return_value=True,
            ),
            patch.object(
                workflow_automation.mobile,
                "_doctype_has_field",
                return_value=False,
            ),
            patch.object(
                workflow_automation.frappe,
                "get_all",
                side_effect=[
                    [],
                    [SimpleNamespace(status=payment_status)],
                ],
            ),
        ):
            return workflow_automation.completion_blockers(service_case)

    def test_verified_payment_still_requires_full_settlement_for_completion(self):
        blockers = self._blockers(
            self._case("Verified Payment"),
            "Partially Paid",
        )

        self.assertIn(
            "Required payment has not been confirmed.",
            blockers,
        )

    def test_verified_payment_allows_completion_after_paid_projection(self):
        blockers = self._blockers(
            self._case("Verified Payment"),
            "Paid",
        )

        self.assertNotIn(
            "Required payment has not been confirmed.",
            blockers,
        )

    def test_full_settlement_still_blocks_completion_while_partially_paid(self):
        blockers = self._blockers(
            self._case("Full Settlement"),
            "Partially Paid",
        )

        self.assertIn(
            "Required payment has not been confirmed.",
            blockers,
        )

    def test_full_settlement_allows_completion_after_paid_projection(self):
        blockers = self._blockers(
            self._case("Full Settlement"),
            "Paid",
        )

        self.assertNotIn(
            "Required payment has not been confirmed.",
            blockers,
        )

    def test_post_paid_policy_snapshot_does_not_bypass_prepaid_execution(self):
        service_case = self._case("Post-paid Approval")
        service_case.post_paid_approved_by = "finance@example.com"
        service_case.post_paid_approved_at = "2026-09-11 12:00:00"

        blockers = self._blockers(service_case, "Pending")

        self.assertIn(
            "Required payment has not been confirmed.",
            blockers,
        )

    def test_pay_later_still_blocks_completion_until_invoice_is_linked(self):
        service_case = self._case("Full Settlement")
        service_case.payment_execution_mode = "Pay Later"
        service_case.post_paid_approved_by = "finance@example.com"
        service_case.post_paid_approved_at = "2026-09-11 12:00:00"
        service_case.pay_later_reason = "Approved credit exception."

        with patch.object(
            workflow_automation,
            "_pay_later_invoice_linked",
            return_value=False,
        ):
            blockers = self._blockers(service_case, "Deferred")

        self.assertIn(
            "Required payment has not been confirmed.",
            blockers,
        )

    def test_pay_later_allows_completion_after_invoice_link_without_settlement(self):
        service_case = self._case("Full Settlement")
        service_case.payment_execution_mode = "Pay Later"
        service_case.post_paid_approved_by = "finance@example.com"
        service_case.post_paid_approved_at = "2026-09-11 12:00:00"
        service_case.pay_later_reason = "Approved credit exception."

        with patch.object(
            workflow_automation,
            "_pay_later_invoice_linked",
            return_value=True,
        ):
            blockers = self._blockers(service_case, "Deferred")

        self.assertNotIn(
            "Required payment has not been confirmed.",
            blockers,
        )
