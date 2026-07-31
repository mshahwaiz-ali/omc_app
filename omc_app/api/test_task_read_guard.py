import importlib
from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app import hooks
from omc_app.api import mobile


task_read_guard = importlib.import_module("omc_app.api.task_read_guard")
task_write_guard = importlib.import_module("omc_app.api.task_write_guard")


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

class TestTaskReadPagination(FrappeTestCase):
    def test_task_write_uses_exact_link_lookup(self):
        request_link = {
            "name": "OMC-SR-OLDER",
            "erp_task": "ERP-TASK-OLDER",
        }
        task = SimpleNamespace(name="ERP-TASK-OLDER")

        with (
            patch.object(
                task_read_guard,
                "_request_link",
                return_value=request_link,
            ) as exact_link,
            patch.object(
                task_read_guard,
                "_load_task",
                return_value=task,
            ),
        ):
            loaded_task, loaded_link = task_write_guard._load_linked_task(
                task.name
            )

        exact_link.assert_called_once_with(task.name)
        self.assertIs(loaded_task, task)
        self.assertIs(loaded_link, request_link)

    def test_task_detail_uses_exact_link_lookup(self):
        request_link = {
            "name": "OMC-SR-OLDER",
            "erp_task": "ERP-TASK-OLDER",
        }
        task = SimpleNamespace(name="ERP-TASK-OLDER")

        with (
            patch.object(
                mobile,
                "_assert_internal_workspace_access",
                return_value="manager@example.com",
            ),
            patch.object(
                mobile,
                "_require_canonical_capability",
                return_value={"can_manage_tasks": True},
            ),
            patch.object(
                task_read_guard,
                "_request_link",
                return_value=request_link,
            ) as exact_link,
            patch.object(
                task_read_guard,
                "_load_task",
                return_value=task,
            ),
            patch.object(
                task_read_guard,
                "_task_to_payload",
                return_value={"name": task.name},
            ),
        ):
            result = task_read_guard.get_task(task_id=task.name)

        exact_link.assert_called_once_with(task.name)
        self.assertEqual(result, {"task": {"name": task.name}})

    def test_task_list_is_bounded_and_reports_next_page(self):
        rows = [
            {"name": f"OMC-SR-{index}", "erp_task": f"TASK-{index}"}
            for index in range(101)
        ]

        with (
            patch.object(
                mobile,
                "_assert_internal_workspace_access",
                return_value="manager@example.com",
            ),
            patch.object(
                mobile,
                "_require_canonical_capability",
                return_value={"can_manage_tasks": True},
            ),
            patch.object(
                task_read_guard,
                "_request_links",
                return_value=rows,
            ) as request_links,
            patch.object(
                task_read_guard,
                "_load_task",
                side_effect=lambda name: SimpleNamespace(name=name),
            ),
            patch.object(
                task_read_guard,
                "_task_to_payload",
                side_effect=lambda task, _link: {"name": task.name},
            ),
        ):
            result = task_read_guard.get_tasks(
                limit_start="100",
                page_length="500",
            )

        request_links.assert_called_once_with(
            task_names=None,
            limit_start=100,
            limit_page_length=101,
        )
        self.assertEqual(len(result["tasks"]), 100)
        self.assertEqual(
            result["pagination"],
            {
                "limit_start": 100,
                "page_length": 100,
                "has_more": True,
                "next_start": 200,
            },
        )
