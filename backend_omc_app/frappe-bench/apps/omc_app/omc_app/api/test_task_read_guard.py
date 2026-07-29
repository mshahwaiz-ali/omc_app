from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app import hooks
from omc_app.api import task_read_guard


class TestTaskReadGuard(FrappeTestCase):
    def test_hooks_route_task_reads(self):
        self.assertEqual(
            hooks.override_whitelisted_methods["omc_app.api.mobile.get_tasks"],
            "omc_app.api.task_read_guard.get_tasks",
        )
        self.assertEqual(
            hooks.override_whitelisted_methods["omc_app.api.mobile.get_task"],
            "omc_app.api.task_read_guard.get_task",
        )

    @patch("omc_app.api.task_read_guard.frappe.get_all")
    @patch("omc_app.api.task_read_guard.mobile._require_canonical_capability")
    @patch("omc_app.api.task_read_guard.mobile._assert_internal_workspace_access")
    def test_assigned_task_list_remains_scoped(
        self,
        internal_access,
        require_capability,
        get_all,
    ):
        internal_access.return_value = "agent@example.com"
        require_capability.return_value = {
            "can_manage_tasks": False,
            "can_manage_assigned_tasks": True,
        }
        get_all.return_value = []

        self.assertEqual(task_read_guard.get_tasks(), {"tasks": []})
        self.assertEqual(get_all.call_args.kwargs["filters"], {"assigned_to": "agent@example.com"})

    @patch("omc_app.api.task_read_guard.frappe.db.exists")
    @patch("omc_app.api.task_read_guard.frappe.get_doc")
    @patch("omc_app.api.task_read_guard.frappe.get_all")
    @patch("omc_app.api.task_read_guard.mobile._require_canonical_capability")
    @patch("omc_app.api.task_read_guard.mobile._assert_internal_workspace_access")
    def test_list_skips_task_deleted_after_name_lookup(
        self,
        internal_access,
        require_capability,
        get_all,
        get_doc,
        exists,
    ):
        internal_access.return_value = "manager@example.com"
        require_capability.return_value = {"can_manage_tasks": True}
        get_all.return_value = ["TASK-STALE", "TASK-VALID"]
        exists.side_effect = lambda doctype, name: name != "TASK-STALE"
        get_doc.return_value = SimpleNamespace(
            name="TASK-VALID",
            title="Review",
            description="",
            status="Open",
            priority="Medium",
            due_date=None,
            assigned_to="manager@example.com",
            customer_profile="",
            service_request="",
            support_ticket="",
            completed_on=None,
            creation=None,
            modified=None,
        )

        result = task_read_guard.get_tasks()

        self.assertEqual([row["name"] for row in result["tasks"]], ["TASK-VALID"])
        get_doc.assert_called_once_with("OMC Task", "TASK-VALID")

    @patch("omc_app.api.task_read_guard.frappe.db.exists")
    def test_sanitize_clears_only_stale_references(self, exists):
        exists.side_effect = lambda doctype, name: name != "REQ-DELETED"
        payload = {
            "customer_profile": "CUST-1",
            "service_request": "REQ-DELETED",
            "support_ticket": "SUP-1",
        }

        result = task_read_guard._sanitize_task_payload(payload)

        self.assertEqual(result["customer_profile"], "CUST-1")
        self.assertEqual(result["service_request"], "")
        self.assertEqual(result["support_ticket"], "SUP-1")

    @patch("omc_app.api.task_read_guard.frappe.db.exists", return_value=False)
    @patch("omc_app.api.task_read_guard.mobile._require_canonical_capability")
    @patch("omc_app.api.task_read_guard.mobile._assert_internal_workspace_access")
    def test_missing_task_detail_is_rejected(
        self,
        internal_access,
        require_capability,
        _exists,
    ):
        internal_access.return_value = "manager@example.com"
        require_capability.return_value = {"can_manage_tasks": True}

        with self.assertRaises(frappe.DoesNotExistError):
            task_read_guard.get_task(task_id="TASK-MISSING")

    @patch("omc_app.api.task_read_guard.frappe.db.exists", return_value=True)
    @patch("omc_app.api.task_read_guard.frappe.get_doc")
    @patch("omc_app.api.task_read_guard.mobile._require_canonical_capability")
    @patch("omc_app.api.task_read_guard.mobile._assert_internal_workspace_access")
    def test_assigned_user_cannot_read_another_users_task(
        self,
        internal_access,
        require_capability,
        get_doc,
        _exists,
    ):
        internal_access.return_value = "agent@example.com"
        require_capability.return_value = {
            "can_manage_tasks": False,
            "can_manage_assigned_tasks": True,
        }
        get_doc.return_value = SimpleNamespace(assigned_to="other@example.com")

        with self.assertRaises(frappe.PermissionError):
            task_read_guard.get_task(task_id="TASK-1")

    @patch("omc_app.api.task_read_guard.frappe.db.exists", return_value=True)
    @patch("omc_app.api.task_read_guard.frappe.get_doc")
    @patch("omc_app.api.task_read_guard.mobile._task_to_dict")
    @patch("omc_app.api.task_read_guard.mobile._require_canonical_capability")
    @patch("omc_app.api.task_read_guard.mobile._assert_internal_workspace_access")
    def test_valid_detail_preserves_payload_contract(
        self,
        internal_access,
        require_capability,
        task_to_dict,
        get_doc,
        _exists,
    ):
        internal_access.return_value = "manager@example.com"
        require_capability.return_value = {"can_manage_tasks": True}
        task = SimpleNamespace(assigned_to="agent@example.com")
        get_doc.return_value = task
        task_to_dict.return_value = {
            "name": "TASK-1",
            "customer_profile": "",
            "service_request": "",
            "support_ticket": "",
        }

        result = task_read_guard.get_task(task_id="TASK-1")

        self.assertEqual(result["task"]["name"], "TASK-1")
        task_to_dict.assert_called_once_with(task)
