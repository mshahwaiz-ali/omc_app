from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import bridge_outbox, erp_sync_recovery


class TestBridgeRecovery(FrappeTestCase):
    def test_terminal_failed_operation_requires_explicit_recovery(self):
        operation = SimpleNamespace(
            name="bridge-failed-1",
            state="Failed",
            service_request="OMC-SR-1",
            operation_key="op-key-1",
        )
        request = SimpleNamespace(
            name="OMC-SR-1",
            request_state="Activation Failed",
        )
        ready_request = SimpleNamespace(
            name="OMC-SR-1",
            request_state="Ready for Activation",
        )

        with (
            patch.object(bridge_outbox.frappe.db, "get_value", return_value=operation.name),
            patch.object(bridge_outbox.frappe, "get_doc", return_value=operation),
            patch.object(
                bridge_outbox.request_lifecycle,
                "_lock_request",
                side_effect=[request, ready_request],
            ),
            patch.object(
                bridge_outbox.request_lifecycle,
                "transition_request_state",
                return_value=SimpleNamespace(request=ready_request),
            ) as transition,
            patch.object(
                bridge_outbox,
                "eligibility",
                return_value={"eligible": True, "reason": ""},
            ),
            patch.object(bridge_outbox.frappe.db, "set_value") as set_value,
            patch.object(bridge_outbox.security, "audit_event") as audit_event,
            patch.object(bridge_outbox, "_enqueue_operation") as enqueue,
        ):
            result = bridge_outbox._recover_failed_operation(
                operation.name,
                actor="manager@example.com",
                reason="Manual recovery",
            )

        self.assertTrue(result["recovered"])
        self.assertEqual(result["state"], "Retry")
        transition.assert_called_once()
        enqueue.assert_called_once_with(operation.name)
        self.assertTrue(set_value.called)
        audit_event.assert_called_once()

    def test_stale_processing_recovers_activating_request_before_retry(self):
        operation = SimpleNamespace(
            doctype="OMC Bridge Operation",
            name="bridge-stale-1",
            state="Processing",
            last_attempt_at=None,
            service_request="OMC-SR-2",
            operation_key="op-key-2",
            attempt_count=1,
        )
        request = SimpleNamespace(
            doctype="OMC Service Request",
            name="OMC-SR-2",
            request_state="Activating",
            payment_policy_snapshot="Full Settlement",
            service="service-1",
        )
        failed_request = SimpleNamespace(
            doctype="OMC Service Request",
            name="OMC-SR-2",
            request_state="Activation Failed",
            payment_policy_snapshot="Full Settlement",
            service="service-1",
        )

        def get_value(doctype, *args, **kwargs):
            if doctype == "OMC Bridge Operation":
                return operation.name
            if doctype == "OMC Service Request":
                return request.name
            return None

        with (
            patch.object(bridge_outbox.frappe.db, "get_value", side_effect=get_value),
            patch.object(
                bridge_outbox.frappe,
                "get_doc",
                side_effect=[operation, request],
            ),
            patch.object(bridge_outbox.frappe.db, "set_value"),
            patch.object(
                bridge_outbox.request_lifecycle,
                "transition_request_state",
                return_value=SimpleNamespace(request=failed_request),
            ) as transition,
            patch.object(
                bridge_outbox,
                "eligibility",
                return_value={"eligible": False, "reason": "stop after stale recovery"},
            ),
        ):
            result = bridge_outbox.process_operation(operation.name)

        self.assertEqual(result["status"], "ineligible")
        transition.assert_called_once()
        self.assertEqual(transition.call_args.args[1], "Activation Failed")

    def test_automatic_recovery_does_not_revive_terminal_bridge_failure(self):
        row = SimpleNamespace(name="OMC-SR-3", erp_next_attempt_at=None)
        operation = SimpleNamespace(
            name="bridge-failed-3",
            state="Failed",
            attempt_count=5,
            next_attempt_at=None,
        )
        lock = MagicMock()
        lock.acquire.return_value = True

        with (
            patch.object(erp_sync_recovery, "_job_lock", return_value=lock),
            patch.object(erp_sync_recovery.frappe, "get_all", return_value=[row]),
            patch.object(erp_sync_recovery, "_bridge_operation", return_value=operation),
            patch.object(erp_sync_recovery.erp_activation, "activate_request") as activate,
        ):
            summary = erp_sync_recovery.run_automatic_erp_sync_recovery()

        self.assertEqual(summary["manual_recovery_required"], 1)
        self.assertEqual(summary["retried"], 0)
        activate.assert_not_called()
