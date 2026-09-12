from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import (
    erp_task_status_sync,
    service_case_contract,
    service_task_links,
    workflow_automation,
)


class TestMultiTaskServiceFlow(FrappeTestCase):
    def _request(self):
        return SimpleNamespace(
            name="OMC-SR-0001",
            title="Service Request",
            status="In Progress",
            request_state="Activated",
            source_channel="Mobile App",
            erp_service="ERP-SVC-0001",
            erp_task="TASK-A",
            erp_customer="CUST-0001",
            assigned_staff="staff@example.com",
            completed_by="",
            completion_source="",
        )

    def _task(self, name="TASK-A", status="Completed"):
        return SimpleNamespace(
            name=name,
            status=status,
            custom_operation_status="",
            workflow_state="",
            completed_on=None,
            modified=None,
        )

    def test_one_completed_task_does_not_complete_multi_task_request(self):
        request = self._request()
        task = self._task()
        aggregate = {
            "required_tasks": 2,
            "completed_tasks": 1,
            "incomplete_tasks": ["TASK-B"],
            "cancelled_tasks": [],
            "all_required_completed": False,
        }

        with patch.object(
            service_task_links,
            "request_for_task",
            return_value=request.name,
        ), patch.object(
            erp_task_status_sync.frappe,
            "get_doc",
            return_value=request,
        ), patch.object(
            service_task_links,
            "completion_state",
            return_value=aggregate,
        ), patch.object(
            erp_task_status_sync,
            "_service_status_value",
            return_value=None,
        ), patch.object(
            erp_task_status_sync,
            "_task_notification_changed",
            return_value=False,
        ), patch.object(
            erp_task_status_sync.frappe.db,
            "set_value",
        ) as set_value:
            result = erp_task_status_sync.sync_task_status(task)

        self.assertTrue(result["updated"])
        self.assertEqual(result["customer_status"], "In Progress")
        request_updates = [
            call.args[2]
            for call in set_value.call_args_list
            if call.args[:2] == ("OMC Service Request", request.name)
        ]
        self.assertTrue(request_updates)
        self.assertEqual(request_updates[0]["status"], "In Progress")

    def test_last_required_task_can_complete_request(self):
        request = self._request()
        task = self._task(name="TASK-B")
        aggregate = {
            "required_tasks": 2,
            "completed_tasks": 2,
            "incomplete_tasks": [],
            "cancelled_tasks": [],
            "all_required_completed": True,
        }

        with patch.object(
            service_task_links,
            "request_for_task",
            return_value=request.name,
        ), patch.object(
            erp_task_status_sync.frappe,
            "get_doc",
            return_value=request,
        ), patch.object(
            service_task_links,
            "completion_state",
            return_value=aggregate,
        ), patch.object(
            workflow_automation,
            "completion_blockers",
            return_value=[],
        ), patch.object(
            workflow_automation,
            "record_completion_attribution",
            return_value={"updated": False},
        ), patch.object(
            workflow_automation,
            "finalize_completed_case",
        ) as finalize, patch.object(
            erp_task_status_sync,
            "_service_status_value",
            return_value=None,
        ), patch.object(
            erp_task_status_sync,
            "_task_notification_changed",
            return_value=False,
        ), patch.object(
            erp_task_status_sync.frappe.db,
            "set_value",
        ):
            result = erp_task_status_sync.sync_task_status(task)

        self.assertEqual(result["customer_status"], "Completed")
        finalize.assert_called_once_with(request)

    def test_multi_task_cancel_does_not_auto_cancel_request(self):
        request = self._request()
        task = self._task(status="Cancelled")
        aggregate = {
            "required_tasks": 2,
            "completed_tasks": 0,
            "incomplete_tasks": ["TASK-A", "TASK-B"],
            "cancelled_tasks": ["TASK-A"],
            "all_required_completed": False,
        }

        with patch.object(
            service_task_links,
            "request_for_task",
            return_value=request.name,
        ), patch.object(
            erp_task_status_sync.frappe,
            "get_doc",
            return_value=request,
        ), patch.object(
            service_task_links,
            "completion_state",
            return_value=aggregate,
        ), patch.object(
            erp_task_status_sync,
            "_service_status_value",
            return_value=None,
        ), patch.object(
            erp_task_status_sync,
            "_task_notification_changed",
            return_value=False,
        ), patch.object(
            erp_task_status_sync.frappe.db,
            "set_value",
        ):
            result = erp_task_status_sync.sync_task_status(task)

        self.assertEqual(result["customer_status"], "In Progress")
        self.assertEqual(request.request_state, "Activated")

    def test_customer_contract_redacts_task_identifiers(self):
        payload = {
            "erp_task": "TASK-A",
            "erp_tasks": ["TASK-A", "TASK-B"],
            "task_id": "TASK-A",
            "task_ids": ["TASK-A", "TASK-B"],
            "title": "Service Request",
        }
        with patch.object(
            service_case_contract.access,
            "is_internal_user",
            return_value=False,
        ):
            service_case_contract._redact_customer_task_internals(payload)

        self.assertNotIn("erp_task", payload)
        self.assertNotIn("erp_tasks", payload)
        self.assertNotIn("task_id", payload)
        self.assertNotIn("task_ids", payload)
        self.assertEqual(payload["title"], "Service Request")

    def test_customer_progress_exposes_counts_not_task_names(self):
        payload = {}
        aggregate = {
            "required_tasks": 3,
            "completed_tasks": 2,
            "incomplete_tasks": ["TASK-C"],
            "cancelled_tasks": [],
            "all_required_completed": False,
        }
        with patch.object(
            service_task_links,
            "completion_state",
            return_value=aggregate,
        ):
            service_case_contract._apply_task_progress(
                payload,
                "OMC-SR-0001",
            )

        self.assertEqual(
            payload["task_progress"],
            {"required": 3, "completed": 2, "remaining": 1},
        )
        self.assertFalse(payload["operational_work_complete"])
        self.assertNotIn("TASK-C", str(payload))

    def test_cancel_service_request_cancels_all_linked_tasks(self):
        request = self._request()

        def exists(doctype, name):
            return (doctype, name) in {
                ("Task", "TASK-A"),
                ("Task", "TASK-B"),
                ("Service", "ERP-SVC-0001"),
            }

        with patch.object(
            service_task_links,
            "task_names",
            return_value=["TASK-A", "TASK-B"],
        ), patch.object(
            erp_task_status_sync,
            "_allowed_options",
            side_effect=lambda doctype, fieldname: (
                {"Open", "Completed", "Cancelled"}
                if fieldname == "status"
                else {"Open", "Cancelled"}
            ),
        ), patch.object(
            erp_task_status_sync,
            "_service_status_value",
            return_value="Cancelled",
        ), patch.object(
            erp_task_status_sync.frappe.db,
            "exists",
            side_effect=exists,
        ), patch.object(
            erp_task_status_sync.frappe.db,
            "set_value",
        ) as set_value:
            result = erp_task_status_sync.cancel_linked_erp_records(request)

        self.assertEqual(result["tasks_cancelled"], 2)
        task_updates = [
            call
            for call in set_value.call_args_list
            if call.args and call.args[0] == "Task"
        ]
        self.assertEqual(len(task_updates), 2)
