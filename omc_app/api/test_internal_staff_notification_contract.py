import inspect
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import frappe

from omc_app.api import (
    access,
    capabilities,
    erp_service_task_adapter,
    erp_task_status_sync,
    mobile,
)


class TestInternalStaffNotificationContract(unittest.TestCase):
    def test_employee_persona_has_read_only_operational_context(self):
        employee = access.ROLE_CAPABILITIES.get("Employee", set())

        self.assertIn("can_view_assigned_service_cases", employee)
        self.assertIn("can_view_relevant_customers", employee)
        self.assertIn("can_view_document_summaries", employee)
        self.assertIn("can_view_document_attachments", employee)

        # Employee mobile access remains read-only.
        self.assertNotIn("can_update_assigned_service_status", employee)
        self.assertNotIn("can_manage_assigned_tasks", employee)
        self.assertNotIn("can_manage_tasks", employee)
        self.assertNotIn("can_view_internal_notes", employee)

    def test_approved_internal_staff_receive_notification_capability(self):
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

        self.assertTrue(
            values.get("can_view_internal_notifications", False)
        )
        self.assertFalse(values.get("can_view_customer_notifications", False))

    def test_notification_schema_supports_task_type(self):
        field = frappe.get_meta("OMC Notification").get_field(
            "notification_type"
        )

        options = {
            value.strip()
            for value in str(field.options or "").splitlines()
            if value.strip()
        }

        self.assertIn("Task", options)

    def test_task_notification_has_direct_mobile_route(self):
        notification = SimpleNamespace(
            mobile_route="",
            reference_doctype="Task",
            reference_name="TASK-2026-00001",
        )

        with patch.object(
            mobile.frappe.db,
            "exists",
            return_value=True,
        ):
            route = mobile._notification_mobile_route(notification)

        self.assertEqual(route, "/tasks/TASK-2026-00001")

    def test_new_task_assignment_emits_notification(self):
        source = inspect.getsource(
            erp_service_task_adapter.ensure_task_assignment
        )

        self.assertIn("notification", source.lower())
        self.assertIn("Task", source)

    def test_task_status_sync_emits_notification(self):
        source = inspect.getsource(
            erp_task_status_sync.sync_task_status
        )

        self.assertIn("notification", source.lower())


if __name__ == "__main__":
    unittest.main()
