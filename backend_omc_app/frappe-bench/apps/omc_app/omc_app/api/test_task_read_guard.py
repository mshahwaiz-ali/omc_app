from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app import hooks
from omc_app.api import mobile


class TestTaskReadRouteDelegation(FrappeTestCase):
    def test_hooks_route_task_list_to_canonical_guard(self):
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.mobile.get_tasks"
            ],
            "omc_app.api.task_read_guard.get_tasks",
        )

    def test_hooks_route_task_detail_to_canonical_guard(self):
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.mobile.get_task"
            ],
            "omc_app.api.task_read_guard.get_task",
        )

    def test_mobile_task_list_fallback_delegates_to_guard(self):
        with patch(
            "omc_app.api.task_read_guard.get_tasks",
            return_value={"tasks": [{"name": "ERP-TASK-1"}]},
        ) as guarded:
            result = mobile.get_tasks()

        guarded.assert_called_once_with()
        self.assertEqual(
            result,
            {"tasks": [{"name": "ERP-TASK-1"}]},
        )

    def test_mobile_task_detail_fallback_delegates_to_guard(self):
        with patch(
            "omc_app.api.task_read_guard.get_task",
            return_value={"name": "ERP-TASK-1"},
        ) as guarded:
            result = mobile.get_task(task_id="ERP-TASK-1")

        guarded.assert_called_once_with(task_id="ERP-TASK-1")
        self.assertEqual(result, {"name": "ERP-TASK-1"})
