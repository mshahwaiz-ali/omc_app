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
            post_paid_approved_by=None,
            post_paid_approved_at=None,
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

    def test_post_paid_requires_finance_approval_not_full_settlement(self):
        service_case = self._case("Post-paid Approval")
        service_case.post_paid_approved_by = "finance@example.com"
        service_case.post_paid_approved_at = "2026-09-11 12:00:00"

        blockers = self._blockers(service_case, "Pending")

        self.assertNotIn(
            "Required payment has not been confirmed.",
            blockers,
        )
