from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import erp_task_status_sync


class TestErpTaskStatusSync(FrappeTestCase):
    def test_customer_status_mapping(self):
        cases = {
            "Open": "Open",
            "Working": "In Progress",
            "Under Review": "In Review",
            "Pending Review": "In Review",
            "Overdue": "Overdue",
            "Waiting for Customer": "Waiting for Customer",
            "Payment Pending": "Waiting for Payment",
            "Completed": "Completed",
            "Closed": "Completed",
            "Cancelled": "Cancelled",
        }
        for source, expected in cases.items():
            with self.subTest(source=source):
                self.assertEqual(
                    erp_task_status_sync.customer_status(source),
                    expected,
                )

    def test_operation_status_takes_precedence(self):
        self.assertEqual(
            erp_task_status_sync.customer_status(
                "Working",
                "Waiting for Customer",
            ),
            "Waiting for Customer",
        )

    def test_unlinked_task_is_ignored(self):
        task = SimpleNamespace(
            name="TASK-UNLINKED",
            status="Working",
            custom_operation_status="",
        )
        with (
            patch.object(
                erp_task_status_sync.frappe.db,
                "get_value",
                return_value=None,
            ),
            patch.object(
                erp_task_status_sync.frappe.db,
                "set_value",
            ) as set_value,
        ):
            result = erp_task_status_sync.sync_task_status(task)

        self.assertFalse(result["updated"])
        set_value.assert_not_called()

    def test_linked_task_updates_request_and_service(self):
        task = SimpleNamespace(
            name="TASK-1",
            status="Working",
            custom_operation_status="Waiting for Customer",
        )

        def get_value(doctype, filters, fieldname):
            if doctype == "OMC Service Request" and isinstance(filters, dict):
                return "OMC-SR-1"
            if doctype == "OMC Service Request" and filters == "OMC-SR-1":
                return "ERP-SERVICE-1"
            return None

        request = SimpleNamespace(
            name="OMC-SR-1",
            status="In Progress",
            closed_on=None,
            erp_service="ERP-SERVICE-1",
        )

        with (
            patch.object(
                erp_task_status_sync.frappe.db,
                "get_value",
                return_value="OMC-SR-1",
            ),
            patch.object(
                erp_task_status_sync.frappe,
                "get_doc",
                return_value=request,
            ),
            patch.object(
                erp_task_status_sync,
                "_service_status_value",
                return_value="Waiting for Customer",
            ),
            patch.object(
                erp_task_status_sync.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                erp_task_status_sync.frappe.db,
                "set_value",
            ) as set_value,
        ):
            result = erp_task_status_sync.sync_task_status(task)

        self.assertTrue(result["updated"])
        self.assertEqual(result["customer_status"], "Waiting for Customer")
        self.assertEqual(set_value.call_count, 2)
    def test_completed_task_respects_completion_blockers(self):
        task = SimpleNamespace(
            name="TASK-1",
            status="Completed",
            custom_operation_status="",
        )
        request = SimpleNamespace(
            name="OMC-SR-1",
            status="In Progress",
            closed_on=None,
            erp_service="ERP-SERVICE-1",
        )

        with (
            patch.object(
                erp_task_status_sync.frappe.db,
                "get_value",
                return_value="OMC-SR-1",
            ),
            patch.object(
                erp_task_status_sync.frappe,
                "get_doc",
                return_value=request,
            ),
            patch(
                "omc_app.api.workflow_automation.completion_blockers",
                return_value=["Required payment has not been confirmed."],
            ),
            patch.object(
                erp_task_status_sync.frappe.db,
                "set_value",
            ) as set_value,
        ):
            result = erp_task_status_sync.sync_task_status(task)

        self.assertFalse(result["updated"])
        self.assertEqual(result["requested_status"], "Completed")
        self.assertIn("Required payment", result["reason"])
        set_value.assert_not_called()

    def test_completed_task_runs_canonical_finalization(self):
        task = SimpleNamespace(
            name="TASK-1",
            status="Completed",
            custom_operation_status="",
        )
        request = SimpleNamespace(
            name="OMC-SR-1",
            status="In Progress",
            closed_on=None,
            erp_service="ERP-SERVICE-1",
        )

        with (
            patch.object(
                erp_task_status_sync.frappe.db,
                "get_value",
                return_value="OMC-SR-1",
            ),
            patch.object(
                erp_task_status_sync.frappe,
                "get_doc",
                return_value=request,
            ),
            patch(
                "omc_app.api.workflow_automation.completion_blockers",
                return_value=[],
            ),
            patch(
                "omc_app.api.workflow_automation.finalize_completed_case",
            ) as finalize,
            patch.object(
                erp_task_status_sync,
                "_service_status_value",
                return_value="Completed",
            ),
            patch.object(
                erp_task_status_sync.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                erp_task_status_sync.frappe.db,
                "set_value",
            ),
            patch.object(
                erp_task_status_sync.frappe.utils,
                "now_datetime",
                return_value="2026-07-31 04:54:00",
            ),
        ):
            result = erp_task_status_sync.sync_task_status(task)

        self.assertTrue(result["updated"])
        finalize.assert_called_once_with(request)

    def test_customer_cancellation_updates_linked_task_and_service(self):
        request = SimpleNamespace(
            erp_task="TASK-1",
            erp_service="ERP-SERVICE-1",
        )

        with (
            patch.object(
                erp_task_status_sync.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                erp_task_status_sync,
                "_allowed_options",
                side_effect=lambda doctype, fieldname: (
                    {"Cancelled"} if fieldname == "status" else set()
                ),
            ),
            patch.object(
                erp_task_status_sync,
                "_service_status_value",
                return_value="Cancelled",
            ),
            patch.object(
                erp_task_status_sync.frappe.db,
                "set_value",
            ) as set_value,
        ):
            result = erp_task_status_sync.cancel_linked_erp_records(request)

        self.assertTrue(result["task_cancelled"])
        self.assertTrue(result["service_cancelled"])
        self.assertEqual(set_value.call_count, 2)

    def test_cancelled_task_runs_canonical_finalization(self):
        task = SimpleNamespace(
            name="TASK-1",
            status="Cancelled",
            custom_operation_status="",
        )
        request = SimpleNamespace(
            name="OMC-SR-1",
            title="Tax Filing",
            status="In Progress",
            closed_on=None,
            erp_service="ERP-SERVICE-1",
            erp_task="TASK-1",
            customer_profile="OMC-CUST-1",
        )

        with (
            patch.object(
                erp_task_status_sync.frappe.db,
                "get_value",
                return_value="OMC-SR-1",
            ),
            patch.object(
                erp_task_status_sync.frappe,
                "get_doc",
                return_value=request,
            ),
            patch(
                "omc_app.api.workflow_automation.finalize_cancelled_case",
            ) as finalize,
            patch.object(
                erp_task_status_sync,
                "_service_status_value",
                return_value="Cancelled",
            ),
            patch.object(
                erp_task_status_sync.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                erp_task_status_sync.frappe.db,
                "set_value",
            ),
            patch.object(
                erp_task_status_sync.frappe.utils,
                "now_datetime",
                return_value="2026-07-31 05:30:00",
            ),
        ):
            result = erp_task_status_sync.sync_task_status(task)

        self.assertTrue(result["updated"])
        self.assertEqual(result["customer_status"], "Cancelled")
        finalize.assert_called_once_with(
            request,
            reason="The linked ERP Task was cancelled by OMC staff.",
            cancelled_by_customer=False,
            sync_erp=False,
        )

    def test_terminal_request_cannot_be_reopened_by_task_sync(self):
        task = SimpleNamespace(
            name="TASK-1",
            status="Working",
            custom_operation_status="",
        )
        request = SimpleNamespace(
            name="OMC-SR-1",
            status="Completed",
            closed_on=object(),
            erp_service="ERP-SERVICE-1",
        )

        with (
            patch.object(
                erp_task_status_sync.frappe.db,
                "get_value",
                return_value="OMC-SR-1",
            ),
            patch.object(
                erp_task_status_sync.frappe,
                "get_doc",
                return_value=request,
            ),
            patch.object(
                erp_task_status_sync.frappe.db,
                "set_value",
            ) as set_value,
        ):
            result = erp_task_status_sync.sync_task_status(task)

        self.assertFalse(result["updated"])
        self.assertIn("cannot be reopened", result["reason"])
        set_value.assert_not_called()



class TestHistoricalErpTaskStatusSync(FrappeTestCase):
    def test_historical_task_status_is_authoritative(self):
        self.assertEqual(
            erp_task_status_sync.historical_customer_status(
                "Overdue",
                "Open",
            ),
            "Overdue",
        )
        self.assertEqual(
            erp_task_status_sync.historical_customer_status(
                "Completed",
                "Open",
            ),
            "Completed",
        )

    def test_historical_under_review_ignores_operation_status(self):
        self.assertEqual(
            erp_task_status_sync.historical_customer_status(
                "Under Review",
                "Open",
            ),
            "In Review",
        )

    def test_unknown_historical_task_status_does_not_use_operation_status(self):
        self.assertEqual(
            erp_task_status_sync.historical_customer_status(
                "Legacy Unknown Status",
                "Completed",
            ),
            "Historical",
        )
        self.assertEqual(
            erp_task_status_sync.historical_customer_status(
                "",
                "Completed",
            ),
            "Historical",
        )

    def test_historical_overdue_stays_active_and_does_not_mutate_erp_service(self):
        task = SimpleNamespace(
            name="TASK-HIST-1",
            status="Overdue",
            custom_operation_status="Open",
            completed_on=None,
            modified="2026-08-24 05:00:00",
        )
        request = SimpleNamespace(
            name="OMC-SR-HIST-1",
            status="Open",
            request_state="Historical",
            source_channel="Imported",
            closed_on=None,
            erp_service="SERV-HIST-1",
        )

        with (
            patch.object(
                erp_task_status_sync.frappe.db,
                "get_value",
                return_value="OMC-SR-HIST-1",
            ),
            patch.object(
                erp_task_status_sync.frappe,
                "get_doc",
                return_value=request,
            ),
            patch.object(
                erp_task_status_sync.frappe.db,
                "set_value",
            ) as set_value,
        ):
            result = erp_task_status_sync.sync_task_status(task)

        self.assertTrue(result["updated"])
        self.assertTrue(result["historical"])
        self.assertEqual(result["customer_status"], "Overdue")
        self.assertIsNone(request.closed_on)
        self.assertEqual(set_value.call_count, 1)

        values = set_value.call_args.args[2]
        self.assertEqual(values["status"], "Overdue")
        self.assertIsNone(values["closed_on"])

    def test_historical_completed_bypasses_modern_completion_workflow(self):
        task = SimpleNamespace(
            name="TASK-HIST-2",
            status="Completed",
            custom_operation_status="Open",
            completed_on="2026-07-15 14:30:00",
            modified="2026-07-15 14:30:00",
        )
        request = SimpleNamespace(
            name="OMC-SR-HIST-2",
            status="Overdue",
            request_state="Historical",
            source_channel="Imported",
            closed_on=None,
            erp_service="SERV-HIST-2",
        )

        with (
            patch.object(
                erp_task_status_sync.frappe.db,
                "get_value",
                return_value="OMC-SR-HIST-2",
            ),
            patch.object(
                erp_task_status_sync.frappe,
                "get_doc",
                return_value=request,
            ),
            patch.object(
                erp_task_status_sync.frappe.db,
                "set_value",
            ) as set_value,
            patch(
                "omc_app.api.workflow_automation.completion_blockers",
            ) as blockers,
            patch(
                "omc_app.api.workflow_automation.finalize_completed_case",
            ) as finalize,
        ):
            result = erp_task_status_sync.sync_task_status(task)

        self.assertTrue(result["updated"])
        self.assertTrue(result["historical"])
        self.assertEqual(result["customer_status"], "Completed")
        self.assertEqual(
            request.closed_on,
            "2026-07-15 14:30:00",
        )

        blockers.assert_not_called()
        finalize.assert_not_called()
        self.assertEqual(set_value.call_count, 1)

        values = set_value.call_args.args[2]
        self.assertEqual(values["status"], "Completed")
        self.assertEqual(
            values["closed_on"],
            "2026-07-15 14:30:00",
        )
