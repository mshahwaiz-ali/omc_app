from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import dashboard_scope


class TestDashboardScope(FrappeTestCase):
    def test_no_service_capability_fails_closed(self):
        self.assertEqual(
            dashboard_scope._service_lifecycle("limited@example.com", {}),
            dashboard_scope._empty_lifecycle(),
        )
        self.assertEqual(
            dashboard_scope._service_snapshots("limited@example.com", {}, limit=3),
            [],
        )
        self.assertEqual(
            dashboard_scope._recent_activity("limited@example.com", {}),
            [],
        )

    def test_no_document_capability_fails_closed(self):
        self.assertEqual(
            dashboard_scope._document_summary("limited@example.com", {}),
            dashboard_scope._empty_document_summary(),
        )

    def test_no_payment_capability_fails_closed(self):
        self.assertEqual(
            dashboard_scope._payment_summary("limited@example.com", {}),
            dashboard_scope._empty_payment_summary(),
        )

    def test_no_support_capability_fails_closed(self):
        self.assertEqual(
            dashboard_scope._support_summary("limited@example.com", {}),
            dashboard_scope._empty_support_summary(),
        )

    @patch("omc_app.api.dashboard_scope.dashboard._pending_erp_task_count")
    def test_global_task_count_requires_manage_tasks(self, pending_erp_task_count):
        pending_erp_task_count.return_value = 7

        self.assertEqual(
            dashboard_scope._pending_task_count(
                "manager@example.com",
                {"can_manage_tasks": True},
            ),
            7,
        )
        pending_erp_task_count.assert_called_once_with()

    def test_next_action_does_not_link_to_hidden_review_queue(self):
        operations = {
            "documents_waiting_review": 4,
            "pending_payments": 3,
            "pending_tasks": 0,
        }
        result = dashboard_scope._next_action(
            {
                "can_view_document_queue": True,
                "can_review_documents": False,
                "can_view_payment_queue": True,
                "can_review_payments": False,
            },
            operations,
            dashboard_scope._empty_support_summary(),
        )

        self.assertEqual(result["type"], "operations")
        self.assertEqual(result["route"], "/internal-workspace")
