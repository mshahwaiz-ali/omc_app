from importlib import import_module
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

erp_sync_recovery = import_module("omc_app.api.erp_sync_recovery")


class TestErpSyncRecovery(FrappeTestCase):
    def test_non_manager_cannot_read_recovery_queue(self):
        with (
            patch.object(
                erp_sync_recovery.frappe.local,
                "session",
                SimpleNamespace(user="staff@example.com"),
            ),
            patch.object(
                erp_sync_recovery.frappe,
                "get_roles",
                return_value=["OMC Consultant"],
            ),
            self.assertRaises(frappe.PermissionError),
        ):
            erp_sync_recovery.get_erp_sync_issues()

    def test_manager_queue_is_bounded_to_retryable_statuses(self):
        row = frappe._dict(name="OMC-SR-1", erp_sync_status="Repair Required")
        with (
            patch.object(
                erp_sync_recovery.frappe.local,
                "session",
                SimpleNamespace(user="manager@example.com"),
            ),
            patch.object(
                erp_sync_recovery.frappe,
                "get_roles",
                return_value=["OMC Manager"],
            ),
            patch.object(
                erp_sync_recovery.frappe,
                "get_all",
                return_value=[row],
            ) as get_all,
            patch.object(
                erp_sync_recovery.frappe.db,
                "count",
                return_value=3,
            ),
        ):
            result = erp_sync_recovery.get_erp_sync_issues(
                limit_start=-4,
                limit_page_length=999,
            )

        self.assertEqual(result["count"], 1)
        self.assertEqual(result["total"], 3)
        self.assertEqual(result["limit_start"], 0)
        self.assertEqual(result["limit_page_length"], 200)
        self.assertEqual(
            get_all.call_args.kwargs["filters"]["erp_sync_status"][0],
            "in",
        )

    def test_retry_uses_repair_mode_and_commits(self):
        request = SimpleNamespace(
            name="OMC-SR-1",
            service="OMC-SERVICE-1",
            customer_profile="PROFILE-1",
            manual_customer="",
            erp_sync_status="Repair Required",
        )
        service = SimpleNamespace(name="OMC-SERVICE-1")

        def exists(doctype, name):
            return (doctype, name) in {
                ("OMC Service Request", "OMC-SR-1"),
                ("OMC Service", "OMC-SERVICE-1"),
                ("OMC Customer Profile", "PROFILE-1"),
            }

        def get_doc(doctype, name):
            return {
                ("OMC Service Request", "OMC-SR-1"): request,
                ("OMC Service", "OMC-SERVICE-1"): service,
                ("OMC Customer Profile", "PROFILE-1"): SimpleNamespace(
                    name="PROFILE-1"
                ),
            }[(doctype, name)]

        with (
            patch.object(
                erp_sync_recovery.frappe.local,
                "session",
                SimpleNamespace(user="manager@example.com"),
            ),
            patch.object(
                erp_sync_recovery.frappe,
                "get_roles",
                return_value=["OMC Manager"],
            ),
            patch.object(
                erp_sync_recovery.frappe.db,
                "exists",
                side_effect=exists,
            ),
            patch.object(erp_sync_recovery.frappe, "get_doc", side_effect=get_doc),
            patch.object(
                erp_sync_recovery.erp_service_task_adapter,
                "sync_request",
                return_value={
                    "status": "Synced",
                    "created": True,
                    "erp_customer": "CUST-1",
                    "erp_service": "SERVICE-1",
                    "erp_task": "TASK-1",
                },
            ) as sync_request,
            patch.object(erp_sync_recovery.frappe.db, "commit") as commit,
            patch.object(
                erp_sync_recovery.frappe,
                "logger",
                return_value=MagicMock(),
            ),
        ):
            result = erp_sync_recovery.retry_erp_sync("OMC-SR-1")

        self.assertEqual(result["status"], "Synced")
        self.assertEqual(result["request_name"], "OMC-SR-1")
        self.assertTrue(sync_request.call_args.kwargs["repair"])
        commit.assert_called_once_with()

    def test_synced_retry_revalidates_links_without_creating_duplicates(self):
        request = SimpleNamespace(
            name="OMC-SR-1",
            erp_sync_status="Synced",
            erp_customer="CUST-1",
            erp_service="SERVICE-1",
            erp_task="TASK-1",
            service="OMC-SERVICE-1",
            customer_profile="",
            manual_customer="",
        )
        with (
            patch.object(
                erp_sync_recovery.frappe.local,
                "session",
                SimpleNamespace(user="manager@example.com"),
            ),
            patch.object(
                erp_sync_recovery.frappe,
                "get_roles",
                return_value=["OMC Manager"],
            ),
            patch.object(erp_sync_recovery.frappe.db, "exists", return_value=True),
            patch.object(
                erp_sync_recovery.frappe,
                "get_doc",
                side_effect=[request, SimpleNamespace(name="OMC-SERVICE-1")],
            ),
            patch.object(
                erp_sync_recovery.erp_service_task_adapter,
                "sync_request",
                return_value={
                    "status": "Synced",
                    "created": False,
                    "erp_customer": "CUST-1",
                    "erp_service": "SERVICE-1",
                    "erp_task": "TASK-1",
                },
            ) as sync_request,
            patch.object(erp_sync_recovery.frappe.db, "commit") as commit,
            patch.object(
                erp_sync_recovery.frappe,
                "logger",
                return_value=MagicMock(),
            ),
        ):
            result = erp_sync_recovery.retry_erp_sync("OMC-SR-1")

        self.assertEqual(result["status"], "Synced")
        self.assertFalse(result["created"])
        self.assertTrue(sync_request.call_args.kwargs["repair"])
        commit.assert_called_once_with()
