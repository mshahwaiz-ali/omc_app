from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import service_assignment


class TestServiceAssignmentRecovery(FrappeTestCase):
    def _service(self):
        return SimpleNamespace(
            title="Tax Filing",
            category="Tax",
            icon="tax_filing",
            default_assignee="",
            default_assignment_role="OMC Tax Associate",
        )

    @patch.object(service_assignment, "active_assignable_user", return_value=None)
    def test_ineligible_explicit_assignee_is_rejected(self, _active):
        with self.assertRaises(frappe.ValidationError):
            service_assignment.resolve_assignee(self._service(), explicit_user="wrong@example.com")

    @patch.object(service_assignment, "least_loaded_user", side_effect=["tax@example.com"])
    @patch.object(service_assignment, "users_for_role", return_value=["tax@example.com"])
    def test_configured_role_selection(self, _users, _least):
        result = service_assignment.resolve_assignee(self._service())
        self.assertEqual(result["candidate"], "tax@example.com")
        self.assertEqual(result["source"], "service_role")

    @patch.object(
        service_assignment.frappe,
        "get_all",
        return_value=[SimpleNamespace(name="TODO-1", allocated_to="staff@example.com")],
    )
    @patch.object(service_assignment.frappe, "new_doc")
    def test_existing_todo_prevents_duplicate(self, new_doc, _get_all):
        request = SimpleNamespace(name="OMC-SR-1", title="Request", priority="Medium")
        result = service_assignment.ensure_assignment_todo(request, "staff@example.com")
        self.assertEqual(result, {"name": "TODO-1", "created": False})
        new_doc.assert_not_called()

    @patch.object(service_assignment.frappe.db, "set_value")
    @patch.object(service_assignment.frappe, "get_all")
    def test_conflicting_request_todo_is_cancelled(self, get_all, set_value):
        get_all.return_value = [
            SimpleNamespace(name="TODO-OLD", allocated_to="old@example.com")
        ]
        todo = MagicMock(name="todo")
        todo.name = "TODO-NEW"
        request = SimpleNamespace(name="OMC-SR-1", title="Request", priority="Medium")
        with patch.object(service_assignment.frappe, "new_doc", return_value=todo):
            result = service_assignment.ensure_assignment_todo(request, "new@example.com")
        self.assertTrue(result["created"])
        set_value.assert_called_once_with(
            "ToDo", "TODO-OLD", "status", "Cancelled", update_modified=False
        )

    @patch.object(service_assignment.erp_service_task_adapter, "ensure_task_assignment")
    @patch.object(service_assignment.frappe.db, "exists", return_value=False)
    @patch.object(service_assignment, "ensure_assignment_todo", return_value={"name": "TODO-1", "created": False})
    @patch.object(service_assignment.mobile, "_create_customer_notification")
    def test_existing_todo_prevents_duplicate_notification(self, notify, _todo, _exists, _task):
        request = SimpleNamespace(
            name="OMC-SR-1",
            assigned_staff="staff@example.com",
            title="Request",
            service_title="Service",
            priority="Medium",
            erp_task="",
        )
        result = service_assignment.apply_assignment(
            request,
            {"candidate": "staff@example.com", "source": "service_role"},
            set_assignee=False,
        )
        self.assertFalse(result["notification_created"])
        notify.assert_not_called()
