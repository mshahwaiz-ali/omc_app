from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import mobile
from omc_app.api import task_write_guard


READ_ONLY_MESSAGE = (
    "Tasks are read-only in the OMC app. Manage tasks in ERPNext."
)


class TestErpTaskWriteGuard(FrappeTestCase):
    def _assert_read_only_error(self, action):
        with self.assertRaises(frappe.PermissionError) as raised:
            action()

        self.assertIn(
            READ_ONLY_MESSAGE,
            str(raised.exception),
        )

    def test_status_update_is_retired_for_internal_staff(self):
        with (
            patch.object(
                mobile,
                "_assert_internal_workspace_access",
                return_value="employee@example.com",
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                side_effect=AssertionError(
                    "ERP Task load must not be reached"
                ),
            ) as load_task,
        ):
            self._assert_read_only_error(
                lambda: task_write_guard.update_task_operation_status(
                    task_id="TASK-1",
                    operation_status="Working",
                )
            )

        load_task.assert_not_called()

    def test_qc_completion_is_retired_for_internal_staff(self):
        with (
            patch.object(
                mobile,
                "_assert_internal_workspace_access",
                return_value="consultant@example.com",
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                side_effect=AssertionError(
                    "ERP Task load must not be reached"
                ),
            ) as load_task,
        ):
            self._assert_read_only_error(
                lambda: task_write_guard.update_task_operation_status(
                    task_id="TASK-1",
                    operation_status="Submitted by QC",
                )
            )

        load_task.assert_not_called()

    def test_reassignment_is_retired_for_internal_staff(self):
        with (
            patch.object(
                mobile,
                "_assert_internal_workspace_access",
                return_value="manager@example.com",
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                side_effect=AssertionError(
                    "ERP Task load must not be reached"
                ),
            ) as load_task,
            patch.object(
                task_write_guard,
                "_create_assignment",
                side_effect=AssertionError(
                    "ToDo creation must not be reached"
                ),
            ) as create_assignment,
        ):
            self._assert_read_only_error(
                lambda: task_write_guard.assign_task(
                    task_id="TASK-1",
                    assigned_to="other@example.com",
                )
            )

        load_task.assert_not_called()
        create_assignment.assert_not_called()

    def test_priority_update_is_retired_for_internal_staff(self):
        with (
            patch.object(
                mobile,
                "_assert_internal_workspace_access",
                return_value="manager@example.com",
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                side_effect=AssertionError(
                    "ERP Task load must not be reached"
                ),
            ) as load_task,
        ):
            self._assert_read_only_error(
                lambda: task_write_guard.update_task_details(
                    task_id="TASK-1",
                    priority="High",
                )
            )

        load_task.assert_not_called()

    def test_due_date_update_is_retired_for_internal_staff(self):
        with (
            patch.object(
                mobile,
                "_assert_internal_workspace_access",
                return_value="manager@example.com",
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                side_effect=AssertionError(
                    "ERP Task load must not be reached"
                ),
            ) as load_task,
        ):
            self._assert_read_only_error(
                lambda: task_write_guard.update_task_details(
                    task_id="TASK-1",
                    due_date="2026-12-31",
                )
            )

        load_task.assert_not_called()

    def test_read_only_denial_happens_before_capability_or_task_mutation(self):
        with (
            patch.object(
                mobile,
                "_assert_internal_workspace_access",
                return_value="employee@example.com",
            ) as workspace_guard,
            patch.object(
                mobile,
                "_require_canonical_capability",
                side_effect=AssertionError(
                    "legacy mutation capability check must not be reached"
                ),
            ) as capability_guard,
            patch.object(
                task_write_guard,
                "_load_linked_task",
                side_effect=AssertionError(
                    "ERP Task load must not be reached"
                ),
            ) as load_task,
        ):
            self._assert_read_only_error(
                lambda: task_write_guard.update_task_operation_status(
                    task_id="TASK-1",
                    operation_status="Working",
                )
            )

        workspace_guard.assert_called_once_with()
        capability_guard.assert_not_called()
        load_task.assert_not_called()

    def test_guest_or_unapproved_user_still_fails_workspace_guard_first(self):
        with (
            patch.object(
                mobile,
                "_assert_internal_workspace_access",
                side_effect=frappe.PermissionError(
                    "Internal workspace access denied"
                ),
            ),
            patch.object(
                task_write_guard,
                "_deny_mobile_task_write",
                side_effect=AssertionError(
                    "read-only staff denial must not bypass workspace auth"
                ),
            ) as deny_write,
        ):
            with self.assertRaises(frappe.PermissionError):
                task_write_guard.update_task_operation_status(
                    task_id="TASK-1",
                    operation_status="Working",
                )

        deny_write.assert_not_called()
