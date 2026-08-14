from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import review_routing


class TestReviewRouting(FrappeTestCase):
    def _record(self, doctype=review_routing.DOCUMENT_DOCTYPE, status="Uploaded"):
        return SimpleNamespace(
            doctype=doctype,
            name="REVIEW-1",
            service_request="OMC-SR-1",
            status=status,
        )

    def _case(self, assigned_staff="staff@example.com"):
        return SimpleNamespace(
            name="OMC-SR-1", assigned_staff=assigned_staff, status="Open", priority="Medium"
        )

    @patch.object(review_routing, "_has_capability", return_value=True)
    def test_capable_assigned_staff_has_precedence(self, _capability):
        result = review_routing.resolve_reviewer(self._record(), self._case())
        self.assertEqual(result, {"candidate": "staff@example.com", "source": "assigned_staff"})

    @patch.object(review_routing, "_least_loaded", return_value="reviewer@example.com")
    @patch.object(review_routing, "_users_for_roles", return_value=["reviewer@example.com"])
    @patch.object(review_routing, "_has_capability", side_effect=lambda user, capability: user != "staff@example.com")
    def test_incapable_assignee_falls_back_to_domain_reviewer(self, _capability, _users, _least):
        result = review_routing.resolve_reviewer(self._record(), self._case())
        self.assertEqual(result["candidate"], "reviewer@example.com")
        self.assertEqual(result["source"], "domain_reviewer")

    @patch.object(review_routing, "_open_todos")
    @patch.object(review_routing, "_has_capability", return_value=True)
    def test_open_eligible_todo_is_idempotent(self, _capability, open_todos):
        open_todos.return_value = [
            SimpleNamespace(name="TODO-1", allocated_to="reviewer@example.com", creation="2026-07-31")
        ]
        result = review_routing.ensure_review_assignment(self._record(), self._case())
        self.assertEqual(result["status"], "already_assigned")
        self.assertFalse(result["created"])

    @patch.object(review_routing.frappe.db, "set_value")
    @patch.object(review_routing, "_has_capability", return_value=True)
    @patch.object(review_routing, "_open_todos")
    def test_duplicate_open_todos_are_cancelled(self, open_todos, _capability, set_value):
        open_todos.return_value = [
            SimpleNamespace(name="TODO-1", allocated_to="reviewer@example.com"),
            SimpleNamespace(name="TODO-2", allocated_to="reviewer@example.com"),
        ]
        result = review_routing.ensure_review_assignment(self._record(), self._case())
        self.assertEqual(result["todo"], "TODO-1")
        set_value.assert_called_once_with(
            "ToDo", "TODO-2", "status", "Cancelled", update_modified=False
        )

    @patch.object(review_routing, "close_review_todos", return_value=1)
    def test_terminal_record_closes_todo(self, close):
        result = review_routing.ensure_review_assignment(
            self._record(status="Approved"), self._case()
        )
        self.assertEqual(result["status"], "terminal")
        close.assert_called_once()

    @patch.object(review_routing.mobile, "_create_customer_notification", return_value=SimpleNamespace(name="N-1"))
    @patch.object(review_routing.frappe, "new_doc")
    @patch.object(review_routing, "resolve_reviewer", return_value={"candidate": "reviewer@example.com", "source": "domain_reviewer"})
    @patch.object(review_routing, "_open_todos", return_value=[])
    def test_one_todo_and_notification_are_created(self, _todos, _resolve, new_doc, _notify):
        todo = MagicMock()
        todo.name = "TODO-NEW"
        new_doc.return_value = todo
        result = review_routing.ensure_review_assignment(self._record(), self._case())
        self.assertTrue(result["created"])
        self.assertTrue(result["notification_created"])
        todo.insert.assert_called_once_with(ignore_permissions=True)
