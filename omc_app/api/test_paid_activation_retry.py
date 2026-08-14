from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import admin_control


class TestPaidActivationRetry(FrappeTestCase):
    def test_retry_runs_full_paid_activation_and_commits(self):
        activation = {
            "activated": True,
            "already_active": False,
            "payment": "PAY-1",
            "assigned_staff": "staff@example.com",
            "erp_sync_status": "Synced",
            "erp_service": "ERP-SERVICE-1",
            "erp_task": "ERP-TASK-1",
            "case_status": "In Progress",
        }

        with (
            patch.object(admin_control, "_require") as require,
            patch.object(
                admin_control.frappe.db,
                "exists",
                return_value=True,
            ),
            patch(
                "omc_app.api.service_activation.activate_paid_request",
                return_value=activation,
            ) as activate,
            patch.object(
                admin_control.mobile,
                "_create_customer_notification",
            ) as notify,
            patch.object(admin_control.frappe.db, "savepoint") as savepoint,
            patch.object(admin_control.frappe.db, "commit") as commit,
        ):
            result = admin_control.retry_paid_activation("OMC-SR-1")

        require.assert_called_once_with("can_retry_sync")
        savepoint.assert_called_once_with("retry_paid_request_activation")
        activate.assert_called_once_with("OMC-SR-1")
        commit.assert_called_once()
        notify.assert_called_once()
        self.assertTrue(result["retried"])
        self.assertEqual(result["activation"], activation)

    def test_retry_is_idempotent_for_already_active_request(self):
        activation = {
            "activated": True,
            "already_active": True,
            "payment": "PAY-1",
            "assigned_staff": "staff@example.com",
            "erp_sync_status": "Synced",
            "case_status": "In Progress",
        }

        with (
            patch.object(admin_control, "_require"),
            patch.object(
                admin_control.frappe.db,
                "exists",
                return_value=True,
            ),
            patch(
                "omc_app.api.service_activation.activate_paid_request",
                return_value=activation,
            ),
            patch.object(
                admin_control.mobile,
                "_create_customer_notification",
            ) as notify,
            patch.object(admin_control.frappe.db, "savepoint"),
            patch.object(admin_control.frappe.db, "commit") as commit,
        ):
            result = admin_control.retry_paid_activation("OMC-SR-1")

        commit.assert_called_once()
        notify.assert_not_called()
        self.assertTrue(result["activation"]["already_active"])

    def test_activation_failure_rolls_back_only_retry_savepoint(self):
        error = frappe.ValidationError("ERP activation failed")

        with (
            patch.object(admin_control, "_require"),
            patch.object(
                admin_control.frappe.db,
                "exists",
                return_value=True,
            ),
            patch(
                "omc_app.api.service_activation.activate_paid_request",
                side_effect=error,
            ),
            patch.object(admin_control.frappe.db, "savepoint") as savepoint,
            patch.object(admin_control.frappe.db, "rollback") as rollback,
            patch.object(admin_control.frappe.db, "commit") as commit,
            patch.object(admin_control.frappe, "log_error"),
            self.assertRaises(frappe.ValidationError),
        ):
            admin_control.retry_paid_activation("OMC-SR-1")

        savepoint.assert_called_once_with("retry_paid_request_activation")
        rollback.assert_called_once_with(
            save_point="retry_paid_request_activation"
        )
        commit.assert_not_called()

    def test_retry_requires_existing_service_request(self):
        with (
            patch.object(admin_control, "_require") as require,
            patch.object(
                admin_control.frappe.db,
                "exists",
                return_value=False,
            ),
            self.assertRaises(frappe.DoesNotExistError),
        ):
            admin_control.retry_paid_activation("OMC-SR-MISSING")

        require.assert_called_once_with("can_retry_sync")
