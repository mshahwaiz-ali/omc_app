from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

import omc_app.hooks as hooks
from omc_app.api import dashboard_scope, internal_workspace_summary


class TestInternalWorkspaceSummary(FrappeTestCase):
    def test_legacy_mobile_route_is_overridden_by_scoped_reader(self):
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.mobile.get_internal_workspace_summary"
            ],
            "omc_app.api.internal_workspace_summary.get_internal_workspace_summary",
        )

    def test_access_denied_fails_closed(self):
        with patch(
            "omc_app.api.internal_workspace_summary.access.can_access_internal_workspace",
            return_value=False,
        ):
            with self.assertRaises(frappe.PermissionError):
                internal_workspace_summary.get_internal_workspace_summary()

    def test_summary_uses_capability_scoped_dashboard_helpers(self):
        capabilities = {
            "can_access_internal_workspace": True,
            "can_view_payment_queue": True,
        }
        lifecycle = {
            "total": 4,
            "active": 3,
            "completed": 1,
            "cancelled": 0,
            "expired": 0,
            "waiting_customer": 1,
        }
        documents = dashboard_scope._empty_document_summary()
        payments = {
            **dashboard_scope._empty_payment_summary(),
            "pending": 2,
            "payments_due": 2,
            "receipt_submitted": 2,
            "receipt_under_review": 3,
            "under_review": 1,
            "total": 5,
        }
        support = dashboard_scope._empty_support_summary()
        operations = {
            "open_leads": 0,
            "active_customers": 0,
            "pending_tasks": 0,
            "pending_payments": 3,
            "documents_waiting_review": 0,
            "active_services": 3,
            "waiting_customer": 1,
        }

        with (
            patch(
                "omc_app.api.internal_workspace_summary.access.can_access_internal_workspace",
                return_value=True,
            ),
            patch(
                "omc_app.api.internal_workspace_summary.access.get_mobile_capabilities",
                return_value=capabilities,
            ),
            patch(
                "omc_app.api.internal_workspace_summary.security.enforce_rate_limit"
            ),
            patch(
                "omc_app.api.internal_workspace_summary.dashboard_scope._service_lifecycle",
                return_value=lifecycle,
            ),
            patch(
                "omc_app.api.internal_workspace_summary.dashboard_scope._document_summary",
                return_value=documents,
            ),
            patch(
                "omc_app.api.internal_workspace_summary.dashboard_scope._payment_summary",
                return_value=payments,
            ),
            patch(
                "omc_app.api.internal_workspace_summary.dashboard_scope._support_summary",
                return_value=support,
            ),
            patch(
                "omc_app.api.internal_workspace_summary.dashboard_scope._operations_summary",
                return_value=operations,
            ),
        ):
            result = internal_workspace_summary.get_internal_workspace_summary()

        self.assertEqual(result["scope"], "capability")
        self.assertEqual(result["pending_payments"], 3)
        self.assertEqual(result["payments_due"], 2)
        self.assertEqual(result["open_services"], 3)
        self.assertEqual(result["active_customers"], 0)
        self.assertEqual(result["open_leads"], 0)
        self.assertEqual(result["my_assigned_services"], 0)

    def test_performance_counts_are_user_scoped(self):
        capabilities = {"can_view_assigned_service_cases": True}
        with patch(
            "omc_app.api.internal_workspace_summary.frappe.db.count",
            side_effect=[4, 2, 5, 1],
        ) as count:
            result = internal_workspace_summary._my_service_performance(
                "consultant@example.com",
                capabilities,
            )

        self.assertEqual(
            result,
            {
                "my_assigned_services": 4,
                "my_active_services": 2,
                "my_completed_services": 5,
                "my_completed_this_month": 1,
            },
        )
        assigned_filters = count.call_args_list[0].args[1]
        completed_filters = count.call_args_list[2].args[1]
        self.assertEqual(assigned_filters["assigned_staff"], "consultant@example.com")
        self.assertEqual(completed_filters["completed_by"], "consultant@example.com")

    def test_performance_fails_closed_without_service_scope(self):
        with patch(
            "omc_app.api.internal_workspace_summary.frappe.db.count"
        ) as count:
            result = internal_workspace_summary._my_service_performance(
                "limited@example.com",
                {"can_access_internal_workspace": True},
            )

        self.assertEqual(
            result,
            {
                "my_assigned_services": 0,
                "my_active_services": 0,
                "my_completed_services": 0,
                "my_completed_this_month": 0,
            },
        )
        count.assert_not_called()
