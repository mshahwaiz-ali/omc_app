import unittest

from omc_app.api import workflow_contract


class WorkflowContractTest(unittest.TestCase):
    def test_rejected_receipt_preserves_payment_stage_and_requests_replacement(self):
        result = workflow_contract.project({"status": "Waiting for Payment", "required_documents_count": 1, "approved_documents_count": 1, "payments_count": 1, "open_payments_count": 1, "rejected_payments_count": 1})
        self.assertEqual(result["current_stage"], "payment")
        self.assertEqual(result["next_action"]["action"], "replace_receipt")
        self.assertTrue(result["customer_action_required"])

    def test_completion_requires_documents_payment_and_operations(self):
        result = workflow_contract.project({"status": "In Progress", "required_documents_count": 2, "approved_documents_count": 2, "payments_count": 1, "paid_payments_count": 1, "operational_work_complete": True})
        self.assertTrue(result["completion_eligible"])
        self.assertEqual(result["completion_blockers"], [])

    def test_completed_status_does_not_hide_incomplete_operational_work(self):
        result = workflow_contract.project(
            {
                "status": "Completed",
                "required_documents_count": 0,
                "payments_count": 0,
                "operational_work_complete": False,
            }
        )
        self.assertFalse(result["completion_eligible"])
        self.assertIn(
            "Operational work is not complete.",
            result["completion_blockers"],
        )

    def test_terminal_transitions_are_rejected(self):
        with self.assertRaises(ValueError):
            workflow_contract.validate_service_transition("Completed", "In Progress")

    def test_legacy_status_is_normalized(self):
        self.assertEqual(workflow_contract.normalize_service_status("processing"), "In Progress")
