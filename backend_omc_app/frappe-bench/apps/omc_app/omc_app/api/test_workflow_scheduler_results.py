from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import workflow_automation


class TestWorkflowSchedulerResults(FrappeTestCase):
    @patch("omc_app.api.workflow_automation._notify_reviewers_once")
    @patch("omc_app.api.workflow_automation._reviewer_users")
    @patch("omc_app.api.workflow_automation.frappe.get_all")
    def test_hourly_runner_reuses_reviewers_and_reports_workload(
        self,
        get_all,
        reviewer_users,
        notify_reviewers,
    ):
        reviewer_users.return_value = ["admin@example.com", "manager@example.com"]
        get_all.side_effect = [
            [
                SimpleNamespace(
                    name="DOC-1",
                    service_request="SR-1",
                    document_title="Passport",
                )
            ],
            [
                SimpleNamespace(
                    name="PAY-1",
                    service_request="SR-1",
                    payment_title="Initial fee",
                )
            ],
            [SimpleNamespace(name="SR-2", title="Tax Filing")],
        ]
        notify_reviewers.side_effect = [["N-1", "N-2"], ["N-3"], []]

        result = workflow_automation.run_hourly_workflow_checks()

        reviewer_users.assert_called_once_with()
        self.assertEqual(result["reviewers"], 2)
        self.assertEqual(result["documents_scanned"], 1)
        self.assertEqual(result["payments_scanned"], 1)
        self.assertEqual(result["unassigned_scanned"], 1)
        self.assertEqual(result["notifications_created"], 3)
        self.assertEqual(notify_reviewers.call_count, 3)
        for invocation in notify_reviewers.call_args_list:
            self.assertEqual(
                invocation.kwargs["reviewers"],
                ["admin@example.com", "manager@example.com"],
            )
        for invocation in get_all.call_args_list:
            self.assertEqual(
                invocation.kwargs["limit_page_length"],
                workflow_automation.HOURLY_BATCH_SIZE,
            )

    @patch("omc_app.api.workflow_automation._notify_once")
    @patch("omc_app.api.workflow_automation._reviewer_users")
    @patch("omc_app.api.workflow_automation.getdate")
    @patch("omc_app.api.workflow_automation.frappe.get_all")
    def test_daily_runner_is_bounded_and_reuses_reviewers(
        self,
        get_all,
        getdate,
        reviewer_users,
        notify_once,
    ):
        get_all.return_value = [
            SimpleNamespace(
                name="SR-1",
                title="Tax Filing",
                status="Waiting for Customer",
                customer_profile="CUST-1",
                assigned_staff="staff@example.com",
                expected_completion_date="2026-07-20",
                modified="2026-07-20",
            )
        ]
        getdate.side_effect = lambda value=None: (
            "2026-07-29" if value is None else value
        )
        reviewer_users.return_value = ["admin@example.com"]
        notify_once.side_effect = [
            SimpleNamespace(name="N-CUSTOMER"),
            SimpleNamespace(name="N-ADMIN"),
            SimpleNamespace(name="N-STAFF"),
        ]

        result = workflow_automation.run_daily_workflow_checks()

        reviewer_users.assert_called_once_with()
        self.assertEqual(result["cases_scanned"], 1)
        self.assertEqual(result["reviewers"], 1)
        self.assertEqual(result["customer_reminders_created"], 1)
        self.assertEqual(result["overdue_escalations_created"], 2)
        self.assertEqual(result["missing_customer_profile"], 0)
        self.assertEqual(
            get_all.call_args.kwargs["limit_page_length"],
            workflow_automation.DAILY_BATCH_SIZE,
        )
        self.assertEqual(get_all.call_args.kwargs["order_by"], "modified asc")
        recipients = {
            invocation.kwargs.get("recipient_user")
            for invocation in notify_once.call_args_list
            if invocation.kwargs.get("recipient_user")
        }
        self.assertEqual(
            recipients,
            {"admin@example.com", "staff@example.com"},
        )

    @patch("omc_app.api.workflow_automation._notify_once")
    @patch("omc_app.api.workflow_automation._reviewer_users", return_value=[])
    @patch("omc_app.api.workflow_automation.getdate", return_value="2026-07-29")
    @patch("omc_app.api.workflow_automation.frappe.get_all")
    def test_daily_runner_skips_customer_reminder_without_profile(
        self,
        get_all,
        getdate,
        reviewer_users,
        notify_once,
    ):
        get_all.return_value = [
            SimpleNamespace(
                name="SR-ORPHAN",
                title="Orphaned case",
                status="Waiting for Payment",
                customer_profile=None,
                assigned_staff=None,
                expected_completion_date=None,
                modified="2026-07-28",
            )
        ]

        result = workflow_automation.run_daily_workflow_checks()

        self.assertEqual(result["cases_scanned"], 1)
        self.assertEqual(result["missing_customer_profile"], 1)
        self.assertEqual(result["customer_reminders_created"], 0)
        notify_once.assert_not_called()

    def test_batch_sizes_are_bounded(self):
        self.assertGreater(workflow_automation.HOURLY_BATCH_SIZE, 0)
        self.assertLessEqual(workflow_automation.HOURLY_BATCH_SIZE, 500)
        self.assertGreater(workflow_automation.DAILY_BATCH_SIZE, 0)
        self.assertLessEqual(workflow_automation.DAILY_BATCH_SIZE, 500)

    def test_notify_reviewers_accepts_preloaded_users(self):
        notification = MagicMock(name="notification")
        notification.name = "N-1"
        with (
            patch(
                "omc_app.api.workflow_automation._reviewer_users"
            ) as reviewer_users,
            patch(
                "omc_app.api.workflow_automation._notify_once",
                return_value=notification,
            ) as notify_once,
        ):
            result = workflow_automation._notify_reviewers_once(
                title="Pending",
                message="Review required",
                reference_doctype="OMC Service Request",
                reference_name="SR-1",
                reviewers=["admin@example.com"],
            )

        reviewer_users.assert_not_called()
        notify_once.assert_called_once_with(
            title="Pending",
            message="Review required",
            notification_type="Workflow",
            reference_doctype="OMC Service Request",
            reference_name="SR-1",
            recipient_user="admin@example.com",
        )
        self.assertEqual(result, ["N-1"])
