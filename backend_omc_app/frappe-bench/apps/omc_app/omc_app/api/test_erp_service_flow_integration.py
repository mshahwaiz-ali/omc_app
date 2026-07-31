from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

import omc_app.hooks as app_hooks
from omc_app.api import erp_service_task_adapter, erp_task_status_sync


class TestErpServiceFlowIntegration(FrappeTestCase):
    def _request(self):
        request = SimpleNamespace(
            doctype="OMC Service Request",
            name="OMC-SR-INTEGRATION-1",
            title="Tax Filing",
            description="Prepare and submit filing.",
            priority="High",
            assigned_staff="staff@example.com",
            expected_completion_date=None,
            erp_customer="",
            erp_service="",
            erp_task="",
        )
        request.meta = MagicMock()
        request.meta.get_field.return_value = True
        request.set = MagicMock()
        return request

    def test_full_bridge_then_status_sync_chain(self):
        request = self._request()
        service = SimpleNamespace(
            name="tax-filing",
            erp_task_type="Tax Filing",
        )
        profile = SimpleNamespace(
            linked_erpnext_customer="ERP-CUST-1",
        )
        erp_service = SimpleNamespace(name="ERP-SERVICE-1")
        erp_task = SimpleNamespace(name="ERP-TASK-1")

        def set_request_state(
            target,
            *,
            status,
            customer="",
            service="",
            task="",
            error="",
        ):
            target.erp_customer = customer
            target.erp_service = service
            target.erp_task = task

        with (
            patch.object(
                erp_service_task_adapter,
                "_linked_customer",
                return_value="ERP-CUST-1",
            ),
            patch.object(
                erp_service_task_adapter,
                "_create_service",
                return_value=erp_service,
            ),
            patch.object(
                erp_service_task_adapter,
                "_create_task",
                return_value=erp_task,
            ),
            patch.object(
                erp_service_task_adapter,
                "_link_service_task",
            ),
            patch.object(
                erp_service_task_adapter,
                "_assign_task",
                return_value="TODO-1",
            ),
            patch.object(
                erp_service_task_adapter,
                "_set_request_state",
                side_effect=set_request_state,
            ),
        ):
            bridge = erp_service_task_adapter.sync_request(
                request,
                service=service,
                profile=profile,
            )

        self.assertEqual(bridge["status"], "Synced")
        self.assertEqual(request.erp_service, "ERP-SERVICE-1")
        self.assertEqual(request.erp_task, "ERP-TASK-1")

        task_doc = SimpleNamespace(
            name="ERP-TASK-1",
            status="Completed",
            custom_operation_status="",
        )

        request.status = "In Progress"
        request.closed_on = None

        with (
            patch.object(
                erp_task_status_sync.frappe.db,
                "get_value",
                return_value=request.name,
            ),
            patch.object(
                erp_task_status_sync.frappe,
                "get_doc",
                return_value=request,
            ),
            patch(
                "omc_app.api.workflow_automation.completion_blockers",
                return_value=[],
            ),
            patch(
                "omc_app.api.workflow_automation.finalize_completed_case",
            ),
            patch.object(
                erp_task_status_sync,
                "_service_status_value",
                return_value="Completed",
            ),
            patch.object(
                erp_task_status_sync.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                erp_task_status_sync.frappe.utils,
                "now_datetime",
                return_value="2026-07-31 04:54:00",
            ),
            patch.object(
                erp_task_status_sync.frappe.db,
                "set_value",
            ) as set_value,
        ):
            synced = erp_task_status_sync.sync_task_status(task_doc)

        self.assertTrue(synced["updated"])
        self.assertEqual(synced["customer_status"], "Completed")
        self.assertEqual(synced["erp_service"], "ERP-SERVICE-1")
        self.assertEqual(set_value.call_count, 2)

        request_update = set_value.call_args_list[0]
        self.assertEqual(request_update.args[0], "OMC Service Request")
        self.assertEqual(request_update.args[1], request.name)
        self.assertEqual(request_update.args[2]["status"], "Completed")
        self.assertIsNotNone(request_update.args[2]["closed_on"])

        service_update = set_value.call_args_list[1]
        self.assertEqual(
            service_update.args[:4],
            ("Service", "ERP-SERVICE-1", "status", "Completed"),
        )

    def test_bridge_retry_is_idempotent(self):
        request = self._request()
        request.erp_customer = "ERP-CUST-1"
        request.erp_service = "ERP-SERVICE-1"
        request.erp_task = "ERP-TASK-1"
        service = SimpleNamespace(
            name="tax-filing",
            erp_task_type="Tax Filing",
        )

        with (
            patch.object(
                erp_service_task_adapter.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                erp_service_task_adapter,
                "_create_service",
            ) as create_service,
            patch.object(
                erp_service_task_adapter,
                "_create_task",
            ) as create_task,
            patch.object(
                erp_service_task_adapter,
                "_assign_task",
            ) as assign_task,
        ):
            result = erp_service_task_adapter.sync_request(
                request,
                service=service,
            )

        self.assertEqual(result["status"], "Synced")
        self.assertFalse(result["created"])
        create_service.assert_not_called()
        create_task.assert_not_called()
        assign_task.assert_not_called()

    def test_partial_bridge_retry_creates_no_duplicate_records(self):
        request = self._request()
        request.erp_customer = "ERP-CUST-1"
        request.erp_service = "ERP-SERVICE-1"
        request.erp_task = ""
        service = SimpleNamespace(
            name="tax-filing",
            erp_task_type="Tax Filing",
        )

        with (
            patch.object(
                erp_service_task_adapter.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                erp_service_task_adapter,
                "_create_service",
            ) as create_service,
            patch.object(
                erp_service_task_adapter,
                "_create_task",
            ) as create_task,
            patch.object(
                erp_service_task_adapter,
                "_assign_task",
            ) as assign_task,
            patch.object(
                erp_service_task_adapter,
                "_set_request_state",
            ),
        ):
            result = erp_service_task_adapter.sync_request(
                request,
                service=service,
            )

        self.assertEqual(result["status"], "Repair Required")
        self.assertFalse(result["created"])
        create_service.assert_not_called()
        create_task.assert_not_called()
        assign_task.assert_not_called()

    def test_pending_configuration_creates_no_partial_erp_records(self):
        request = self._request()
        service = SimpleNamespace(
            name="tax-filing",
            erp_task_type="",
        )
        profile = SimpleNamespace(
            linked_erpnext_customer="",
        )

        with (
            patch.object(
                erp_service_task_adapter,
                "_set_request_state",
            ),
            patch.object(
                erp_service_task_adapter,
                "_create_service",
            ) as create_service,
            patch.object(
                erp_service_task_adapter,
                "_create_task",
            ) as create_task,
            patch.object(
                erp_service_task_adapter,
                "_assign_task",
            ) as assign_task,
        ):
            result = erp_service_task_adapter.sync_request(
                request,
                service=service,
                profile=profile,
            )

        self.assertEqual(result["status"], "Pending Configuration")
        self.assertFalse(result["created"])
        create_service.assert_not_called()
        create_task.assert_not_called()
        assign_task.assert_not_called()

    def test_task_status_hook_is_registered(self):
        self.assertIn("Task", app_hooks.doc_events)
        self.assertEqual(
            app_hooks.doc_events["Task"]["on_update"],
            "omc_app.api.erp_task_status_sync.sync_task_status",
        )
