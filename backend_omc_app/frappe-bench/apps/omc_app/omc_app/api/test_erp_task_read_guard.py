from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import task_read_guard


class TestErpTaskReadGuard(FrappeTestCase):
    def _task(self, name="ERP-TASK-1"):
        return SimpleNamespace(
            name=name,
            subject="Tax Filing",
            description="Prepare filing",
            status="Working",
            priority="High",
            exp_end_date="2026-08-10",
            actual_end_date=None,
            creation="2026-07-30 10:00:00",
            modified="2026-07-30 11:00:00",
        )

    def _link(self):
        return {
            "name": "OMC-SR-1",
            "erp_task": "ERP-TASK-1",
            "erp_service": "ERP-SERVICE-1",
            "customer_profile": "OMC-CUST-1",
        }

    def test_manager_lists_only_omc_linked_erp_tasks(self):
        with (
            patch.object(
                task_read_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="manager@example.com",
            ),
            patch.object(
                task_read_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_tasks": True},
            ),
            patch.object(
                task_read_guard,
                "_request_link_map",
                return_value={"ERP-TASK-1": self._link()},
            ),
            patch.object(
                task_read_guard,
                "_load_task",
                side_effect=lambda name: self._task(name),
            ) as load_task,
            patch.object(
                task_read_guard,
                "_assigned_users",
                return_value=["staff@example.com"],
            ),
        ):
            result = task_read_guard.get_tasks()

        self.assertEqual(len(result["tasks"]), 1)
        payload = result["tasks"][0]
        self.assertEqual(payload["name"], "ERP-TASK-1")
        self.assertEqual(payload["title"], "Tax Filing")
        self.assertEqual(payload["service_request"], "OMC-SR-1")
        self.assertEqual(payload["erp_service"], "ERP-SERVICE-1")
        self.assertEqual(payload["assigned_to"], "staff@example.com")
        self.assertEqual(payload["source_doctype"], "Task")
        load_task.assert_called_once_with("ERP-TASK-1")

    def test_assigned_staff_list_is_todo_scoped(self):
        link_map = {
            "ERP-TASK-1": self._link(),
            "ERP-TASK-2": {
                **self._link(),
                "erp_task": "ERP-TASK-2",
                "name": "OMC-SR-2",
            },
        }

        with (
            patch.object(
                task_read_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="staff@example.com",
            ),
            patch.object(
                task_read_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_assigned_tasks": True},
            ),
            patch.object(
                task_read_guard,
                "_request_links",
                return_value=[link_map["ERP-TASK-1"]],
            ),
            patch.object(
                task_read_guard,
                "_task_assignment_names",
                return_value={"ERP-TASK-1"},
            ),
            patch.object(
                task_read_guard,
                "_load_task",
                side_effect=lambda name: self._task(name),
            ),
            patch.object(
                task_read_guard,
                "_assigned_users",
                return_value=["staff@example.com"],
            ),
        ):
            result = task_read_guard.get_tasks()

        self.assertEqual(
            [row["name"] for row in result["tasks"]],
            ["ERP-TASK-1"],
        )

    def test_unlinked_erp_task_is_not_exposed(self):
        with (
            patch.object(
                task_read_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="manager@example.com",
            ),
            patch.object(
                task_read_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_tasks": True},
            ),
            patch.object(
                task_read_guard,
                "_request_link",
                return_value=None,
            ),
            self.assertRaises(Exception),
        ):
            task_read_guard.get_task(task_id="UNLINKED-TASK")

    def test_assigned_staff_cannot_read_another_users_task(self):
        with (
            patch.object(
                task_read_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="staff@example.com",
            ),
            patch.object(
                task_read_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_assigned_tasks": True},
            ),
            patch.object(
                task_read_guard,
                "_request_link",
                return_value=self._link(),
            ),
            patch.object(
                task_read_guard,
                "_task_assignment_names",
                return_value=set(),
            ),
            self.assertRaises(Exception),
        ):
            task_read_guard.get_task(task_id="ERP-TASK-1")

    def test_task_detail_preserves_flutter_contract(self):
        with (
            patch.object(
                task_read_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="manager@example.com",
            ),
            patch.object(
                task_read_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_tasks": True},
            ),
            patch.object(
                task_read_guard,
                "_request_link",
                return_value=self._link(),
            ),
            patch.object(
                task_read_guard,
                "_load_task",
                return_value=self._task(),
            ),
            patch.object(
                task_read_guard,
                "_assigned_users",
                return_value=["staff@example.com"],
            ),
        ):
            payload = task_read_guard.get_task(
                task_id="ERP-TASK-1",
            )["task"]

        required = {
            "name",
            "title",
            "description",
            "status",
            "priority",
            "due_date",
            "assigned_to",
            "customer_profile",
            "service_request",
            "support_ticket",
            "completed_on",
            "created_at",
            "updated_at",
        }
        self.assertTrue(required.issubset(payload))

    def test_payload_prefers_operation_status(self):
        task = self._task()
        task.custom_operation_status = "Pending at QC"

        with patch.object(
            task_read_guard,
            "_assigned_users",
            return_value=[],
        ):
            payload = task_read_guard._task_to_payload(
                task,
                {
                    "name": "OMC-SR-1",
                    "erp_service": "ERP-SERVICE-1",
                    "customer_profile": "OMC-CUST-1",
                },
            )

        self.assertEqual(payload["status"], "Pending at QC")
