from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import dashboard


class TestDashboardTaskAuthority(FrappeTestCase):
    def test_pending_task_count_uses_only_linked_erp_tasks(self):
        with (
            patch.object(
                dashboard,
                "_get_all",
                return_value=["TASK-2", "TASK-1", "TASK-1", None],
            ) as get_all,
            patch.object(
                dashboard,
                "_count",
                return_value=2,
            ) as count,
        ):
            result = dashboard._pending_erp_task_count()

        self.assertEqual(result, 2)
        get_all.assert_called_once_with(
            "OMC Service Request",
            filters={"erp_task": ["is", "set"]},
            pluck="erp_task",
        )
        count.assert_called_once_with(
            "Task",
            {
                "name": ["in", ["TASK-1", "TASK-2"]],
                "status": ["not in", ["Completed", "Cancelled"]],
            },
        )

    def test_pending_task_count_returns_zero_without_links(self):
        with (
            patch.object(dashboard, "_get_all", return_value=[]),
            patch.object(dashboard, "_count") as count,
        ):
            result = dashboard._pending_erp_task_count()

        self.assertEqual(result, 0)
        count.assert_not_called()

    def test_internal_summary_uses_erp_task_counter(self):
        customer_summary = {
            "document_summary": {"uploaded": 0},
            "open_services": 0,
        }
        with (
            patch.object(dashboard, "_pending_erp_task_count", return_value=3),
            patch.object(dashboard, "_count", return_value=0),
        ):
            result = dashboard._internal_operations_summary(customer_summary)

        self.assertEqual(result["pending_tasks"], 3)
