from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

from omc_app.api import workflow_automation


class TestWorkflowCompletion(TestCase):
    def _case(self):
        return SimpleNamespace(
            name="OMC-SR-TEST",
            title="Test Service",
            service="TEST-SERVICE",
            customer_profile="OMC-CUST-TEST",
        )

    @patch.object(
        workflow_automation.frappe,
        "db",
    )
    @patch.object(workflow_automation.frappe, "get_all")
    @patch.object(
        workflow_automation.mobile,
        "_service_required_documents",
    )
    def test_completion_blocked_by_unpaid_payment(
        self,
        required_documents,
        get_all,
        db,
    ):
        required_documents.return_value = []
        get_all.side_effect = [
            [],
            [SimpleNamespace(status="Pending")],
        ]
        db.count.return_value = 0

        blockers = workflow_automation.completion_blockers(
            self._case()
        )

        self.assertIn(
            "Required payment has not been confirmed.",
            blockers,
        )


    @patch.object(
        workflow_automation.frappe,
        "db",
    )
    @patch.object(workflow_automation.frappe, "get_all")
    @patch.object(
        workflow_automation.mobile,
        "_service_required_documents",
    )
    def test_paid_case_has_no_payment_blocker(
        self,
        required_documents,
        get_all,
        db,
    ):
        required_documents.return_value = []
        get_all.side_effect = [
            [],
            [SimpleNamespace(status="Paid")],
        ]
        db.count.return_value = 0

        blockers = workflow_automation.completion_blockers(
            self._case()
        )

        self.assertNotIn(
            "Required payment has not been confirmed.",
            blockers,
        )


    @patch.object(workflow_automation.mobile, "_create_customer_notification")
    @patch.object(workflow_automation.mobile, "_create_service_timeline_entry")
    @patch.object(workflow_automation.frappe.db, "set_value")
    def test_completion_closes_todos_and_notifies_customer(
        self,
        set_value,
        timeline,
        notification,
    ):
        workflow_automation.finalize_completed_case(self._case())

        set_value.assert_called_once()
        timeline.assert_called_once()
        notification.assert_called_once()

    @patch.object(workflow_automation.mobile, "_create_customer_notification")
    @patch.object(workflow_automation, "_notification_exists")
    def test_notify_once_prevents_duplicate(self, exists, create_notification):
        exists.return_value = True

        result = workflow_automation._notify_once(
            title="Reminder",
            message="Test",
            notification_type="Reminder",
            reference_doctype="OMC Service Request",
            reference_name="OMC-SR-TEST",
            customer_profile="OMC-CUST-TEST",
        )

        self.assertIsNone(result)
        create_notification.assert_not_called()
