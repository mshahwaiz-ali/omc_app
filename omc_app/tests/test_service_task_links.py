from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import service_task_links


class TestServiceTaskLinks(FrappeTestCase):
    def test_legacy_primary_is_exposed_until_relation_is_backfilled(self):
        with patch.object(
            service_task_links,
            "_link_doctype_available",
            return_value=True,
        ), patch.object(
            service_task_links.frappe,
            "get_all",
            return_value=[],
        ), patch.object(
            service_task_links,
            "_legacy_task",
            return_value="TASK-PRIMARY",
        ), patch.object(
            service_task_links.frappe.db,
            "get_value",
            return_value="ERP-SVC-0001",
        ):
            rows = service_task_links.linked_task_rows("OMC-SR-0001")

        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["erp_task"], "TASK-PRIMARY")
        self.assertEqual(rows[0]["is_primary"], 1)
        self.assertEqual(rows[0]["required_for_completion"], 1)

    def test_relation_rows_prevent_duplicate_legacy_primary_projection(self):
        row = {
            "name": "TASK-PRIMARY",
            "erp_task": "TASK-PRIMARY",
            "erp_service": "ERP-SVC-0001",
            "is_primary": 1,
            "required_for_completion": 1,
            "source": "Activation",
            "linked_at": None,
        }
        with patch.object(
            service_task_links,
            "_link_doctype_available",
            return_value=True,
        ), patch.object(
            service_task_links.frappe,
            "get_all",
            return_value=[row],
        ), patch.object(
            service_task_links,
            "_legacy_task",
            return_value="TASK-PRIMARY",
        ):
            rows = service_task_links.linked_task_rows("OMC-SR-0001")

        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["erp_task"], "TASK-PRIMARY")

    def test_request_for_task_prefers_relation_table(self):
        with patch.object(
            service_task_links,
            "_link_doctype_available",
            return_value=True,
        ), patch.object(
            service_task_links.frappe.db,
            "get_value",
            return_value="OMC-SR-0001",
        ), patch.object(
            service_task_links.frappe,
            "get_all",
        ) as legacy_query:
            request = service_task_links.request_for_task("TASK-SECONDARY")

        self.assertEqual(request, "OMC-SR-0001")
        legacy_query.assert_not_called()

    def test_request_for_task_falls_back_to_legacy_primary(self):
        with patch.object(
            service_task_links,
            "_link_doctype_available",
            return_value=False,
        ), patch.object(
            service_task_links.frappe,
            "get_all",
            return_value=["OMC-SR-0001"],
        ):
            request = service_task_links.request_for_task("TASK-PRIMARY")

        self.assertEqual(request, "OMC-SR-0001")

    def test_completion_requires_every_required_task(self):
        task_rows = [
            SimpleNamespace(name="TASK-A", status="Completed"),
            SimpleNamespace(name="TASK-B", status="Working"),
        ]
        with patch.object(
            service_task_links,
            "task_names",
            return_value=["TASK-A", "TASK-B"],
        ), patch.object(
            service_task_links.frappe,
            "get_all",
            return_value=task_rows,
        ):
            state = service_task_links.completion_state("OMC-SR-0001")

        self.assertFalse(state["all_required_completed"])
        self.assertEqual(state["completed_tasks"], 1)
        self.assertEqual(state["incomplete_tasks"], ["TASK-B"])

    def test_completion_succeeds_only_when_all_required_tasks_complete(self):
        task_rows = [
            SimpleNamespace(name="TASK-A", status="Completed"),
            SimpleNamespace(name="TASK-B", status="Completed"),
        ]
        with patch.object(
            service_task_links,
            "task_names",
            return_value=["TASK-A", "TASK-B"],
        ), patch.object(
            service_task_links.frappe,
            "get_all",
            return_value=task_rows,
        ):
            state = service_task_links.completion_state("OMC-SR-0001")

        self.assertTrue(state["all_required_completed"])
        self.assertEqual(state["completed_tasks"], 2)
        self.assertEqual(state["incomplete_tasks"], [])
