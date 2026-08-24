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
            custom_operation_status="",
            creation="2026-07-30 10:00:00",
            modified="2026-07-30 11:00:00",
        )

    def _link(self):
        return {
            "name": "OMC-SR-1",
            "erp_task": "ERP-TASK-1",
            "erp_service": "ERP-SERVICE-1",
            "customer_profile": "OMC-CUST-1",
            "assigned_staff": "staff@example.com",
        }

    def test_internal_staff_lists_direct_erp_tasks_with_optional_omc_enrichment(self):
        task = self._task()

        with (
            patch.object(
                task_read_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="employee@example.com",
            ),
            patch.object(
                task_read_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_view_tasks": True},
            ) as require_capability,
            patch.object(
                task_read_guard,
                "_erp_task_rows",
                return_value=[task],
            ) as task_rows,
            patch.object(
                task_read_guard,
                "_request_links",
                return_value=[self._link()],
            ),
            patch.object(
                task_read_guard,
                "_task_assignment_display_map",
                return_value={
                    "ERP-TASK-1": ["staff@example.com"],
                },
            ),
        ):
            result = task_read_guard.get_tasks()

        require_capability.assert_called_once_with(
            "can_view_tasks",
            message="You do not have permission to view tasks.",
        )
        task_rows.assert_called_once_with(
            limit_start=0,
            limit_page_length=101,
            search="",
            status="",
            priority="",
        )

        self.assertEqual(len(result["tasks"]), 1)
        payload = result["tasks"][0]

        self.assertEqual(payload["name"], "ERP-TASK-1")
        self.assertEqual(payload["title"], "Tax Filing")
        self.assertEqual(payload["service_request"], "OMC-SR-1")
        self.assertEqual(payload["erp_service"], "ERP-SERVICE-1")
        self.assertEqual(
            payload["assigned_to"],
            "staff@example.com",
        )
        self.assertEqual(payload["source_doctype"], "Task")
        self.assertTrue(payload["read_only"])
        self.assertEqual(payload["write_authority"], "ERPNext")

    def test_internal_staff_visibility_is_not_todo_scoped(self):
        task_one = self._task("ERP-TASK-1")
        task_two = self._task("ERP-TASK-2")

        with (
            patch.object(
                task_read_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="staff@example.com",
            ),
            patch.object(
                task_read_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_view_tasks": True},
            ),
            patch.object(
                task_read_guard,
                "_erp_task_rows",
                return_value=[task_one, task_two],
            ),
            patch.object(
                task_read_guard,
                "_request_links",
                return_value=[],
            ),
            patch.object(
                task_read_guard,
                "_task_assignment_display_map",
                return_value={
                    "ERP-TASK-1": ["someone.else@example.com"],
                },
            ),
            patch.object(
                task_read_guard,
                "_task_assignment_names",
                side_effect=AssertionError(
                    "assignment scope must not control task visibility"
                ),
            ),
        ):
            result = task_read_guard.get_tasks()

        self.assertEqual(
            [row["name"] for row in result["tasks"]],
            ["ERP-TASK-1", "ERP-TASK-2"],
        )

    def test_unlinked_erp_task_detail_is_visible(self):
        task = self._task("UNLINKED-TASK")

        with (
            patch.object(
                task_read_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="employee@example.com",
            ),
            patch.object(
                task_read_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_view_tasks": True},
            ),
            patch.object(
                task_read_guard,
                "_load_task",
                return_value=task,
            ),
            patch.object(
                task_read_guard,
                "_request_link",
                return_value=None,
            ),
            patch.object(
                task_read_guard,
                "_task_assignment_display_map",
                return_value={},
            ),
        ):
            payload = task_read_guard.get_task(
                task_id="UNLINKED-TASK",
            )["task"]

        self.assertEqual(payload["name"], "UNLINKED-TASK")
        self.assertEqual(payload["service_request"], "")
        self.assertEqual(payload["erp_service"], "")
        self.assertTrue(payload["read_only"])

    def test_internal_staff_can_read_task_assigned_to_another_user(self):
        task = self._task()

        with (
            patch.object(
                task_read_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="staff@example.com",
            ),
            patch.object(
                task_read_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_view_tasks": True},
            ),
            patch.object(
                task_read_guard,
                "_load_task",
                return_value=task,
            ),
            patch.object(
                task_read_guard,
                "_request_link",
                return_value=self._link(),
            ),
            patch.object(
                task_read_guard,
                "_task_assignment_display_map",
                return_value={
                    "ERP-TASK-1": ["other.employee@example.com"],
                },
            ),
            patch.object(
                task_read_guard,
                "_task_assignment_names",
                side_effect=AssertionError(
                    "assignment scope must not control task detail visibility"
                ),
            ),
        ):
            payload = task_read_guard.get_task(
                task_id="ERP-TASK-1",
            )["task"]

        self.assertEqual(
            payload["assigned_to"],
            "other.employee@example.com",
        )

    def test_task_detail_preserves_flutter_tracking_contract(self):
        task = self._task()

        with (
            patch.object(
                task_read_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="employee@example.com",
            ),
            patch.object(
                task_read_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_view_tasks": True},
            ),
            patch.object(
                task_read_guard,
                "_load_task",
                return_value=task,
            ),
            patch.object(
                task_read_guard,
                "_request_link",
                return_value=self._link(),
            ),
            patch.object(
                task_read_guard,
                "_task_assignment_display_map",
                return_value={
                    "ERP-TASK-1": ["staff@example.com"],
                },
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
            "display_status",
            "erp_status",
            "operation_status",
            "allowed_transitions",
            "priority",
            "due_date",
            "assigned_to",
            "assigned_users",
            "customer_profile",
            "service_request",
            "erp_service",
            "support_ticket",
            "completed_on",
            "created_at",
            "updated_at",
            "read_only",
            "write_authority",
            "can_manage_tasks",
            "can_manage_assigned_tasks",
        }

        self.assertTrue(required.issubset(payload))
        self.assertEqual(payload["allowed_transitions"], [])
        self.assertFalse(payload["can_manage_tasks"])
        self.assertFalse(payload["can_manage_assigned_tasks"])

    def test_payload_falls_back_to_service_request_assignee_when_todos_are_closed(self):
        payload = task_read_guard._task_to_payload(
            self._task(),
            self._link(),
            assigned_users=[],
        )

        self.assertEqual(
            payload["assigned_to"],
            "staff@example.com",
        )
        self.assertEqual(
            payload["assigned_users"],
            ["staff@example.com"],
        )

    def test_operation_status_is_display_only_and_has_no_mobile_transitions(self):
        task = self._task()
        task.custom_operation_status = "Pending at QC"

        payload = task_read_guard._task_to_payload(
            task,
            self._link(),
            assigned_users=["staff@example.com"],
        )

        self.assertEqual(payload["erp_status"], "Working")
        self.assertEqual(payload["status"], "Working")
        self.assertEqual(payload["display_status"], "Working")
        self.assertEqual(
            payload["operation_status"],
            "Pending at QC",
        )
        self.assertEqual(payload["allowed_transitions"], [])
        self.assertTrue(payload["read_only"])

    def test_terminal_task_remains_read_only(self):
        task = self._task()
        task.status = "Completed"
        task.custom_operation_status = "Submitted by QC"

        payload = task_read_guard._task_to_payload(
            task,
            self._link(),
            assigned_users=[],
        )

        self.assertEqual(payload["erp_status"], "Completed")
        self.assertEqual(
            payload["operation_status"],
            "Submitted by QC",
        )
        self.assertEqual(payload["allowed_transitions"], [])
        self.assertTrue(payload["read_only"])
