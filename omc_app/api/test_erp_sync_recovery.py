from importlib import import_module
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

erp_sync_recovery = import_module("omc_app.api.erp_sync_recovery")


class TestErpSyncRecovery(FrappeTestCase):
    def test_retry_backoff_and_exhaustion_defaults(self):
        self.assertEqual(
            [erp_sync_recovery._delay_for("Transient", attempt) for attempt in range(1, 6)],
            [1, 2, 4, 8, 24],
        )
        self.assertEqual(
            [erp_sync_recovery._delay_for("Configuration", attempt) for attempt in range(1, 6)],
            [24, 48, 96, 168, 168],
        )
        self.assertEqual(erp_sync_recovery.MAX_AUTOMATIC_ATTEMPTS, 5)

    def test_exception_categories_fail_closed(self):
        transient = type("DeadlockError", (Exception,), {})()
        self.assertEqual(erp_sync_recovery._category_for_exception(transient), "Transient")
        operational = type("OperationalError", (Exception,), {})(1213, "deadlock")
        self.assertEqual(erp_sync_recovery._category_for_exception(operational), "Transient")
        self.assertEqual(
            erp_sync_recovery._category_for_exception(ValueError("bad invariant")),
            "Permanent",
        )

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
        request.meta = MagicMock()
        request.meta.get_field.return_value = False
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
                erp_sync_recovery.erp_activation,
                "activate_request",
                return_value={
                    "status": "Synced",
                    "created": True,
                    "eligible": True,
                    "erp_customer": "CUST-1",
                    "erp_service": "SERVICE-1",
                    "erp_task": "TASK-1",
                },
            ) as activate_request,
            patch.object(erp_sync_recovery.frappe.db, "commit") as commit,
            patch.object(
                erp_sync_recovery.frappe,
                "logger",
                return_value=MagicMock(),
            ),
            patch.object(
                erp_sync_recovery,
                "now_datetime",
                return_value="2026-07-31 12:00:00",
            ),
        ):
            result = erp_sync_recovery.retry_erp_sync("OMC-SR-1")

        self.assertEqual(result["status"], "Synced")
        self.assertEqual(result["request_name"], "OMC-SR-1")
        self.assertTrue(activate_request.call_args.kwargs["repair"])
        commit.assert_called_once_with()

    def test_unpaid_retry_does_not_cross_erp_activation_gate(self):
        request = SimpleNamespace(
            name="OMC-SR-UNPAID",
            service="OMC-SERVICE-1",
            customer_profile="",
            manual_customer="",
            erp_sync_status="Repair Required",
            erp_retry_exhausted_at=None,
            erp_retry_count=0,
            erp_customer="",
            erp_service="",
            erp_task="",
            final_price=25000,
            status="Waiting for Payment",
        )
        request.meta = MagicMock()
        request.meta.get_field.return_value = False

        service = SimpleNamespace(
            name="OMC-SERVICE-1",
            base_price=25000,
            erp_task_type="GST Registration",
        )

        def exists(doctype, name):
            return (doctype, name) in {
                ("OMC Service Request", "OMC-SR-UNPAID"),
                ("OMC Service", "OMC-SERVICE-1"),
            }

        def get_doc(doctype, name):
            return {
                ("OMC Service Request", "OMC-SR-UNPAID"): request,
                ("OMC Service", "OMC-SERVICE-1"): service,
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
            patch.object(
                erp_sync_recovery.frappe,
                "get_doc",
                side_effect=get_doc,
            ),
            patch.object(
                erp_sync_recovery.erp_activation,
                "_paid_payment_exists",
                return_value=False,
            ),
            patch.object(
                erp_sync_recovery.erp_activation.erp_service_task_adapter,
                "sync_request",
            ) as sync_request,
            patch.object(
                erp_sync_recovery,
                "_record_attempt_result",
            ) as record_attempt,
            patch.object(
                erp_sync_recovery.frappe.db,
                "commit",
            ) as commit,
            patch.object(
                erp_sync_recovery.frappe,
                "logger",
                return_value=MagicMock(),
            ),
        ):
            result = erp_sync_recovery.retry_erp_sync(
                "OMC-SR-UNPAID"
            )

        self.assertEqual(result["status"], "Not Started")
        self.assertFalse(result["eligible"])
        self.assertEqual(
            result["request_name"],
            "OMC-SR-UNPAID",
        )

        sync_request.assert_not_called()
        record_attempt.assert_not_called()
        commit.assert_not_called()

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
        request.meta = MagicMock()
        request.meta.get_field.return_value = False
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
            patch.object(
                erp_sync_recovery,
                "now_datetime",
                return_value="2026-07-31 12:00:00",
            ),
        ):
            result = erp_sync_recovery.retry_erp_sync("OMC-SR-1")

        self.assertEqual(result["status"], "Synced")
        self.assertFalse(result["created"])
        self.assertTrue(sync_request.call_args.kwargs["repair"])
        commit.assert_called_once_with()
