from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import capabilities
from omc_app.api import mobile
from omc_app.api import task_read_guard
from omc_app.api import task_write_guard


class TestTaskTrackingReadOnlyContract(FrappeTestCase):
    def _task(self, name="TASK-TRACKING-1"):
        return SimpleNamespace(
            name=name,
            subject="Read-only ERP tracking task",
            description="Tracked from ERPNext",
            status="Open",
            custom_operation_status="",
            priority="Medium",
            exp_end_date=None,
            actual_end_date=None,
            creation=None,
            modified=None,
        )

    def test_approved_current_staff_gets_baseline_task_tracking_capability(self):
        staff = SimpleNamespace(
            access_status="Approved",
            reconciliation_status="Current",
            capabilities=[],
        )

        with (
            patch.object(
                capabilities.identity,
                "user_is_enabled",
                return_value=True,
            ),
            patch.object(
                capabilities.identity,
                "get_staff_access",
                return_value=staff,
            ),
            patch.object(
                capabilities,
                "_active_break_glass",
                return_value=set(),
            ),
        ):
            values = capabilities.effective("employee@example.com")

        self.assertEqual(values.get("access_state"), "internal")
        self.assertTrue(values.get("can_access_internal_workspace"))
        self.assertTrue(values.get("can_view_tasks"))
        self.assertFalse(values.get("can_manage_tasks"))

    def test_task_list_requires_view_capability_not_manage_capability(self):
        with (
            patch.object(
                mobile,
                "_assert_internal_workspace_access",
                return_value="employee@example.com",
            ),
            patch.object(
                mobile,
                "_require_canonical_capability",
                return_value={"can_view_tasks": True},
            ) as require_capability,
            patch.object(
                task_read_guard,
                "_task_assignment_names",
                return_value=set(),
            ) as assigned_scope,
            patch.object(
                task_read_guard,
                "_erp_task_rows",
                return_value=[],
            ),
        ):
            result = task_read_guard.get_tasks()

        require_capability.assert_called_once_with(
            "can_view_tasks",
            message="You do not have permission to view tasks.",
        )
        assigned_scope.assert_not_called()
        self.assertEqual(result["tasks"], [])

    def test_unlinked_erp_task_is_visible_to_internal_staff(self):
        task = self._task()

        with (
            patch.object(
                mobile,
                "_assert_internal_workspace_access",
                return_value="employee@example.com",
            ),
            patch.object(
                mobile,
                "_require_canonical_capability",
                return_value={"can_view_tasks": True},
            ),
            patch.object(
                task_read_guard,
                "_erp_task_rows",
                return_value=[task],
            ),
            patch.object(
                task_read_guard,
                "_request_links",
                return_value=[],
            ),
            patch.object(
                task_read_guard,
                "_task_assignment_display_map",
                return_value={},
            ),
        ):
            result = task_read_guard.get_tasks(
                limit_start=0,
                page_length=20,
            )

        self.assertEqual(
            [row["name"] for row in result["tasks"]],
            ["TASK-TRACKING-1"],
        )
        self.assertEqual(
            result["tasks"][0]["service_request"],
            "",
        )

    def test_unlinked_erp_task_detail_is_visible(self):
        task = self._task()

        with (
            patch.object(
                mobile,
                "_assert_internal_workspace_access",
                return_value="employee@example.com",
            ),
            patch.object(
                mobile,
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
            result = task_read_guard.get_task(
                task_id="TASK-TRACKING-1"
            )

        self.assertEqual(
            result["task"]["name"],
            "TASK-TRACKING-1",
        )
        self.assertEqual(
            result["task"]["service_request"],
            "",
        )

    def test_task_payload_is_explicitly_read_only(self):
        task = self._task()

        with patch.object(
            task_read_guard,
            "_task_assignment_display_map",
            return_value={},
        ):
            payload = task_read_guard._task_to_payload(
                task,
                {
                    "name": "",
                    "customer_profile": "",
                    "erp_service": "",
                    "assigned_staff": "",
                },
            )

        self.assertEqual(payload.get("allowed_transitions"), [])
        self.assertFalse(payload.get("can_manage_tasks", True))
        self.assertFalse(payload.get("can_manage_assigned_tasks", True))
        self.assertTrue(payload.get("read_only"))
        self.assertEqual(payload.get("write_authority"), "ERPNext")

    def test_status_update_is_disabled_for_mobile(self):
        with (
            patch.object(
                mobile,
                "_assert_internal_workspace_access",
                return_value="employee@example.com",
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                side_effect=AssertionError("write path reached"),
            ) as load_task,
        ):
            with self.assertRaises(frappe.PermissionError):
                task_write_guard.update_task_operation_status(
                    task_id="TASK-1",
                    operation_status="Working",
                )

        load_task.assert_not_called()

    def test_reassignment_is_disabled_for_mobile(self):
        with (
            patch.object(
                mobile,
                "_assert_internal_workspace_access",
                return_value="employee@example.com",
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                side_effect=AssertionError("write path reached"),
            ) as load_task,
        ):
            with self.assertRaises(frappe.PermissionError):
                task_write_guard.assign_task(
                    task_id="TASK-1",
                    assigned_to="other@example.com",
                )

        load_task.assert_not_called()

    def test_task_planning_update_is_disabled_for_mobile(self):
        with (
            patch.object(
                mobile,
                "_assert_internal_workspace_access",
                return_value="employee@example.com",
            ),
            patch.object(
                task_write_guard,
                "_load_linked_task",
                side_effect=AssertionError("write path reached"),
            ) as load_task,
        ):
            with self.assertRaises(frappe.PermissionError):
                task_write_guard.update_task_details(
                    task_id="TASK-1",
                    priority="High",
                )

        load_task.assert_not_called()
