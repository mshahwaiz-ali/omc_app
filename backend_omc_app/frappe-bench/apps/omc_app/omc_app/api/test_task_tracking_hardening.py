from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import task_read_guard


class TestTaskTrackingHardening(FrappeTestCase):
    def _task(self):
        return SimpleNamespace(
            name="TASK-1",
            subject="Read-only task",
            status="Open",
            priority="Medium",
            creation=None,
            modified=None,
        )

    def test_payload_exposes_server_authoritative_linked_case_access(self):
        payload = task_read_guard._task_to_payload(
            self._task(),
            {
                "name": "OMC-SR-1",
                "customer_profile": "OMC-CUST-1",
                "erp_service": "SERV-1",
                "assigned_staff": "",
            },
            assigned_users=[],
            can_view_linked_service_case=True,
        )

        self.assertEqual(payload["service_request"], "OMC-SR-1")
        self.assertTrue(payload["can_view_linked_service_case"])

    def test_task_list_uses_canonical_service_case_scope_once(self):
        capabilities = {
            "can_access_internal_workspace": True,
            "can_view_tasks": True,
            "can_view_assigned_service_cases": True,
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
                return_value=capabilities,
            ),
            patch.object(
                task_read_guard.mobile,
                "_service_case_scope_names",
                return_value=["OMC-SR-1"],
            ) as service_scope,
            patch.object(
                task_read_guard,
                "_erp_task_rows",
                return_value=[],
            ),
        ):
            result = task_read_guard.get_tasks(page_length=5)

        self.assertEqual(result["tasks"], [])
        service_scope.assert_called_once_with(
            capabilities,
            "staff@example.com",
        )
