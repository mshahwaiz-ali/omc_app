from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import completion_recheck, payment_accounting_hooks


class TestCompletionRecheck(FrappeTestCase):
    def test_completed_task_reuses_canonical_task_projection(self):
        request = SimpleNamespace(
            name="OMC-SR-RECHECK",
            status="In Progress",
            request_state="Activated",
            erp_task="TASK-RECHECK",
        )
        task = SimpleNamespace(
            name="TASK-RECHECK",
            status="Completed",
            custom_operation_status=None,
        )

        def exists(doctype, name):
            return (doctype, name) in {
                ("OMC Service Request", request.name),
                ("Task", task.name),
            }

        with (
            patch.object(
                completion_recheck.frappe.db,
                "exists",
                side_effect=exists,
            ),
            patch.object(
                completion_recheck.frappe,
                "get_doc",
                side_effect=[request, task],
            ),
            patch.object(
                completion_recheck.erp_task_status_sync,
                "customer_status",
                return_value="Completed",
            ),
            patch.object(
                completion_recheck.erp_task_status_sync,
                "sync_task_status",
                return_value={"updated": True, "customer_status": "Completed"},
            ) as sync,
        ):
            result = completion_recheck.recheck_completed_task(request.name)

        self.assertTrue(result["updated"])
        sync.assert_called_once_with(task, method="dependency_recheck")

    def test_non_completed_task_is_not_projected(self):
        request = SimpleNamespace(
            name="OMC-SR-RECHECK",
            status="In Progress",
            request_state="Activated",
            erp_task="TASK-RECHECK",
        )
        task = SimpleNamespace(
            name="TASK-RECHECK",
            status="Working",
            custom_operation_status=None,
        )

        with (
            patch.object(
                completion_recheck.frappe.db,
                "exists",
                return_value=True,
            ),
            patch.object(
                completion_recheck.frappe,
                "get_doc",
                side_effect=[request, task],
            ),
            patch.object(
                completion_recheck.erp_task_status_sync,
                "customer_status",
                return_value="In Progress",
            ),
            patch.object(
                completion_recheck.erp_task_status_sync,
                "sync_task_status",
            ) as sync,
        ):
            result = completion_recheck.recheck_completed_task(request.name)

        self.assertFalse(result["updated"])
        sync.assert_not_called()

    def test_settlement_triggers_completion_recheck(self):
        with (
            patch.object(
                payment_accounting_hooks.accounting_reconciliation,
                "reconcile_request",
                return_value={"accounting_status": "Settled"},
            ),
            patch.object(
                payment_accounting_hooks.frappe,
                "get_all",
                return_value=[],
            ),
            patch.object(
                payment_accounting_hooks.bridge_outbox,
                "enqueue_if_eligible",
            ),
            patch.object(
                payment_accounting_hooks.completion_recheck,
                "recheck_completed_task",
            ) as recheck,
        ):
            payment_accounting_hooks.project_request_payment_state(
                "OMC-SR-RECHECK"
            )

        recheck.assert_called_once_with("OMC-SR-RECHECK")
