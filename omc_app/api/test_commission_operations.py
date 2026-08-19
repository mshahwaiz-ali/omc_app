from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import commission_operations


class TestCommissionOperations(FrappeTestCase):
    def test_view_only_capability_cannot_open_finance_queue(self):
        with patch.object(
            commission_operations.capabilities,
            "effective",
            return_value={"can_view_referral_commissions": True},
        ):
            with self.assertRaises(frappe.PermissionError):
                commission_operations._finance_capabilities()

    def test_calculated_matched_allows_approve_and_reject(self):
        actions = commission_operations._allowed_actions(
            "Calculated",
            "Matched",
            {
                "can_approve_commissions": True,
                "can_mark_commissions_paid": True,
            },
        )
        self.assertEqual(actions, ["approve", "reject"])

    def test_unmatched_evidence_blocks_forward_finance_actions(self):
        actions = commission_operations._allowed_actions(
            "Calculated",
            "Review Required",
            {
                "can_approve_commissions": True,
                "can_mark_commissions_paid": True,
            },
        )
        self.assertEqual(actions, ["reject"])

    def test_approved_matched_can_be_rejected_or_marked_payable(self):
        actions = commission_operations._allowed_actions(
            "Approved",
            "Matched",
            {
                "can_approve_commissions": True,
                "can_mark_commissions_paid": True,
            },
        )
        self.assertEqual(actions, ["reject", "mark_payable"])

    def test_payable_matched_can_be_rejected_or_marked_paid(self):
        actions = commission_operations._allowed_actions(
            "Payable",
            "Matched",
            {
                "can_approve_commissions": True,
                "can_mark_commissions_paid": True,
            },
        )
        self.assertEqual(actions, ["reject", "mark_paid"])

    def test_paid_allocation_has_no_lifecycle_action(self):
        actions = commission_operations._allowed_actions(
            "Paid",
            "Matched",
            {
                "can_approve_commissions": True,
                "can_mark_commissions_paid": True,
            },
        )
        self.assertEqual(actions, [])
