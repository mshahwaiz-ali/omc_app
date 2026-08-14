import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import task_write_guard


class TestErpTaskWriteGuard(FrappeTestCase):
    def _assert_read_only(self, callback):
        with self.assertRaises(frappe.PermissionError) as context:
            callback()

        self.assertIn(
            "Tasks are read-only in the OMC app",
            str(context.exception),
        )

    def test_operation_status_write_is_blocked(self):
        self._assert_read_only(
            lambda: task_write_guard.update_task_operation_status(
                task_id="ERP-TASK-1",
                operation_status="Pending at QC",
            )
        )

    def test_task_assignment_options_are_blocked(self):
        self._assert_read_only(
            lambda: task_write_guard.get_task_assignment_options(
                task_id="ERP-TASK-1",
            )
        )

    def test_task_assignment_write_is_blocked(self):
        self._assert_read_only(
            lambda: task_write_guard.assign_task(
                task_id="ERP-TASK-1",
                assigned_to="staff@example.com",
            )
        )

    def test_task_planning_write_is_blocked(self):
        self._assert_read_only(
            lambda: task_write_guard.update_task_details(
                task_id="ERP-TASK-1",
                priority="High",
                due_date="2026-08-20",
            )
        )
