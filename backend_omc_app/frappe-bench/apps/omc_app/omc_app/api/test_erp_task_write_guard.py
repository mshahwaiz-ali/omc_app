from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import task_write_guard


class TestErpTaskWriteGuard(FrappeTestCase):
    def _task(self, operation_status="Open"):
        meta = SimpleNamespace(
            has_field=lambda fieldname: (
                fieldname == "custom_operation_status"
            )
        )
        task = SimpleNamespace(
            name="ERP-TASK-1",
            custom_operation_status=operation_status,
            meta=meta,
        )
        task.save = lambda **kwargs: None
        return task

    def _link(self):
        return {
            "name": "OMC-SR-1",
            "erp_task": "ERP-TASK-1",
            "erp_service": "ERP-SERVICE-1",
            "customer_profile": "OMC-CUST-1",
        }

    def test_manager_can_update_linked_task_operation_status(self):
        task = self._task()
        with (
            patch.object(
                task_write_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="manager@example.com",
            ),
            patch.object(
                task_write_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_tasks": True},
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                return_value=(task, self._link()),
            ),
            patch.object(
                task_write_guard.task_read_guard,
                "_task_to_payload",
                return_value={"name": "ERP-TASK-1"},
            ),
        ):
            result = task_write_guard.update_task_operation_status(
                task_id="ERP-TASK-1",
                operation_status="Pending at QC",
            )

        self.assertTrue(result["updated"])
        self.assertEqual(
            task.custom_operation_status,
            "Pending at QC",
        )

    def test_assigned_staff_can_update_assigned_task(self):
        task = self._task()
        with (
            patch.object(
                task_write_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="staff@example.com",
            ),
            patch.object(
                task_write_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_assigned_tasks": True},
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                return_value=(task, self._link()),
            ),
            patch.object(
                task_write_guard.task_read_guard,
                "_task_assignment_names",
                return_value={"ERP-TASK-1"},
            ),
            patch.object(
                task_write_guard.task_read_guard,
                "_task_to_payload",
                return_value={"name": "ERP-TASK-1"},
            ),
        ):
            result = task_write_guard.update_task_operation_status(
                task_id="ERP-TASK-1",
                operation_status="Submitted by Operation",
            )

        self.assertTrue(result["updated"])

    def test_unassigned_staff_cannot_update_task(self):
        task = self._task()
        with (
            patch.object(
                task_write_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="staff@example.com",
            ),
            patch.object(
                task_write_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_assigned_tasks": True},
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                return_value=(task, self._link()),
            ),
            patch.object(
                task_write_guard.task_read_guard,
                "_task_assignment_names",
                return_value=set(),
            ),
            self.assertRaises(frappe.PermissionError),
        ):
            task_write_guard.update_task_operation_status(
                task_id="ERP-TASK-1",
                operation_status="Pending at Client",
            )

    def test_rejects_unsupported_operation_status(self):
        task = self._task()
        with (
            patch.object(
                task_write_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="manager@example.com",
            ),
            patch.object(
                task_write_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_tasks": True},
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                return_value=(task, self._link()),
            ),
            self.assertRaises(frappe.ValidationError),
        ):
            task_write_guard.update_task_operation_status(
                task_id="ERP-TASK-1",
                operation_status="Completed",
            )

    def test_duplicate_status_is_noop(self):
        task = self._task("Pending at Client")
        with (
            patch.object(
                task_write_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="manager@example.com",
            ),
            patch.object(
                task_write_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_tasks": True},
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                return_value=(task, self._link()),
            ),
            patch.object(
                task_write_guard.task_read_guard,
                "_task_to_payload",
                return_value={"name": "ERP-TASK-1"},
            ),
        ):
            result = task_write_guard.update_task_operation_status(
                task_id="ERP-TASK-1",
                operation_status="Pending at Client",
            )

        self.assertFalse(result["updated"])

    def test_manager_can_reassign_linked_task(self):
        task = self._task()
        link = self._link()
        with (
            patch.object(
                task_write_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="manager@example.com",
            ),
            patch.object(
                task_write_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_tasks": True},
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                return_value=(task, link),
            ),
            patch.object(task_write_guard, "_assert_assignable_user"),
            patch.object(
                task_write_guard.task_read_guard,
                "_assigned_users",
                return_value=["old@example.com"],
            ),
            patch.object(
                task_write_guard,
                "_close_open_assignments",
                return_value=["old@example.com"],
            ) as close_assignments,
            patch.object(
                task_write_guard,
                "_create_assignment",
            ) as create_assignment,
            patch.object(
                task_write_guard.frappe.db,
                "exists",
                return_value=False,
            ),
            patch.object(
                task_write_guard.task_read_guard,
                "_task_to_payload",
                return_value={"name": "ERP-TASK-1"},
            ),
        ):
            result = task_write_guard.assign_task(
                task_id="ERP-TASK-1",
                assigned_to="new@example.com",
            )

        self.assertTrue(result["updated"])
        close_assignments.assert_called_once_with("ERP-TASK-1")
        create_assignment.assert_called_once_with(task, "new@example.com")

    def test_assigned_staff_cannot_reassign_task(self):
        task = self._task()
        with (
            patch.object(
                task_write_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="staff@example.com",
            ),
            patch.object(
                task_write_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_assigned_tasks": True},
            ),
            self.assertRaises(frappe.PermissionError),
        ):
            task_write_guard.assign_task(
                task_id="ERP-TASK-1",
                assigned_to="other@example.com",
            )

    def test_duplicate_assignment_is_noop(self):
        task = self._task()
        with (
            patch.object(
                task_write_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="manager@example.com",
            ),
            patch.object(
                task_write_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_tasks": True},
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                return_value=(task, self._link()),
            ),
            patch.object(task_write_guard, "_assert_assignable_user"),
            patch.object(
                task_write_guard.task_read_guard,
                "_assigned_users",
                return_value=["same@example.com"],
            ),
            patch.object(
                task_write_guard.task_read_guard,
                "_task_to_payload",
                return_value={"name": "ERP-TASK-1"},
            ),
            patch.object(
                task_write_guard,
                "_close_open_assignments",
            ) as close_assignments,
        ):
            result = task_write_guard.assign_task(
                task_id="ERP-TASK-1",
                assigned_to="same@example.com",
            )

        self.assertFalse(result["updated"])
        close_assignments.assert_not_called()

    def test_rejects_ineligible_assignee(self):
        with (
            patch.object(
                task_write_guard.frappe.db,
                "get_value",
                return_value=None,
            ),
            self.assertRaises(Exception),
        ):
            task_write_guard._assert_assignable_user(
                "missing@example.com",
            )

    def test_closes_all_open_task_assignments(self):
        rows = [
            {"name": "TODO-1", "allocated_to": "one@example.com"},
            {"name": "TODO-2", "allocated_to": "two@example.com"},
        ]
        with (
            patch.object(
                task_write_guard.frappe,
                "get_all",
                return_value=rows,
            ),
            patch.object(
                task_write_guard.frappe.db,
                "set_value",
            ) as set_value,
        ):
            users = task_write_guard._close_open_assignments("ERP-TASK-1")

        self.assertEqual(
            users,
            ["one@example.com", "two@example.com"],
        )
        self.assertEqual(set_value.call_count, 2)

    def test_manager_can_update_priority_and_due_date(self):
        task = self._task()
        task.priority = "Medium"
        task.exp_end_date = None

        with (
            patch.object(
                task_write_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="manager@example.com",
            ),
            patch.object(
                task_write_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_tasks": True},
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                return_value=(task, self._link()),
            ),
            patch.object(
                task_write_guard.frappe.db,
                "exists",
                return_value=False,
            ),
            patch.object(
                task_write_guard.task_read_guard,
                "_task_to_payload",
                return_value={"name": "ERP-TASK-1"},
            ),
        ):
            result = task_write_guard.update_task_details(
                task_id="ERP-TASK-1",
                priority="High",
                due_date="2026-08-15",
            )

        self.assertTrue(result["updated"])
        self.assertEqual(task.priority, "High")
        self.assertEqual(str(task.exp_end_date), "2026-08-15")

    def test_assigned_staff_cannot_update_planning_details(self):
        with (
            patch.object(
                task_write_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="staff@example.com",
            ),
            patch.object(
                task_write_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_assigned_tasks": True},
            ),
            self.assertRaises(frappe.PermissionError),
        ):
            task_write_guard.update_task_details(
                task_id="ERP-TASK-1",
                priority="High",
            )

    def test_rejects_invalid_priority(self):
        task = self._task()
        task.priority = "Medium"
        task.exp_end_date = None

        with (
            patch.object(
                task_write_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="manager@example.com",
            ),
            patch.object(
                task_write_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_tasks": True},
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                return_value=(task, self._link()),
            ),
            self.assertRaises(frappe.ValidationError),
        ):
            task_write_guard.update_task_details(
                task_id="ERP-TASK-1",
                priority="Critical",
            )

    def test_rejects_invalid_due_date(self):
        task = self._task()
        task.priority = "Medium"
        task.exp_end_date = None

        with (
            patch.object(
                task_write_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="manager@example.com",
            ),
            patch.object(
                task_write_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_tasks": True},
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                return_value=(task, self._link()),
            ),
            self.assertRaises(frappe.ValidationError),
        ):
            task_write_guard.update_task_details(
                task_id="ERP-TASK-1",
                due_date="not-a-date",
            )

    def test_duplicate_planning_update_is_noop(self):
        task = self._task()
        task.priority = "High"
        task.exp_end_date = frappe.utils.getdate("2026-08-15")

        with (
            patch.object(
                task_write_guard.mobile,
                "_assert_internal_workspace_access",
                return_value="manager@example.com",
            ),
            patch.object(
                task_write_guard.mobile,
                "_require_canonical_capability",
                return_value={"can_manage_tasks": True},
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                return_value=(task, self._link()),
            ),
            patch.object(
                task_write_guard.task_read_guard,
                "_task_to_payload",
                return_value={"name": "ERP-TASK-1"},
            ),
        ):
            result = task_write_guard.update_task_details(
                task_id="ERP-TASK-1",
                priority="High",
                due_date="2026-08-15",
            )

        self.assertFalse(result["updated"])
