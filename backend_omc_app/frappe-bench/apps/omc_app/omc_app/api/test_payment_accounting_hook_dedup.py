from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app.api import (
    accounting_reconciliation,
    bridge_outbox,
    completion_recheck,
    payment_accounting_hooks,
)


class TestPaymentAccountingHookDedup(FrappeTestCase):
    def test_partial_submit_does_not_reconcile_twice(self):
        payment_entry = SimpleNamespace(references=[])

        with (
            patch.object(
                payment_accounting_hooks,
                "_request_names",
                return_value={"OMC-SR-1"},
            ),
            patch.object(
                accounting_reconciliation,
                "payment_entry_submitted",
            ) as submitted,
            patch.object(
                payment_accounting_hooks,
                "project_request_payment_state",
            ) as project,
            patch.object(
                bridge_outbox,
                "_accounting_status",
                return_value="Partially Settled",
            ),
            patch.object(
                completion_recheck,
                "recheck_completed_task",
            ) as completion,
        ):
            payment_accounting_hooks.payment_entry_submitted(
                payment_entry,
                "on_submit",
            )

        submitted.assert_called_once_with(
            payment_entry,
            "on_submit",
        )
        project.assert_not_called()
        completion.assert_not_called()

    def test_settled_submit_keeps_completion_recheck(self):
        payment_entry = SimpleNamespace(references=[])

        with (
            patch.object(
                payment_accounting_hooks,
                "_request_names",
                return_value={"OMC-SR-1"},
            ),
            patch.object(
                accounting_reconciliation,
                "payment_entry_submitted",
            ) as submitted,
            patch.object(
                payment_accounting_hooks,
                "project_request_payment_state",
            ) as project,
            patch.object(
                bridge_outbox,
                "_accounting_status",
                return_value="Settled",
            ),
            patch.object(
                completion_recheck,
                "recheck_completed_task",
            ) as completion,
        ):
            payment_accounting_hooks.payment_entry_submitted(
                payment_entry,
                "on_submit",
            )

        submitted.assert_called_once_with(
            payment_entry,
            "on_submit",
        )
        project.assert_not_called()
        completion.assert_called_once_with("OMC-SR-1")

    def test_cancel_hook_does_not_reconcile_twice(self):
        payment_entry = SimpleNamespace(references=[])

        with (
            patch.object(
                payment_accounting_hooks,
                "_request_names",
                return_value={"OMC-SR-1"},
            ),
            patch.object(
                accounting_reconciliation,
                "payment_entry_cancelled",
            ) as cancelled,
            patch.object(
                payment_accounting_hooks,
                "project_request_payment_state",
            ) as project,
            patch.object(
                bridge_outbox,
                "_accounting_status",
                return_value="Partially Settled",
            ),
            patch.object(
                completion_recheck,
                "recheck_completed_task",
            ) as completion,
        ):
            payment_accounting_hooks.payment_entry_cancelled(
                payment_entry,
                "on_cancel",
            )

        cancelled.assert_called_once_with(
            payment_entry,
            "on_cancel",
        )
        project.assert_not_called()
        completion.assert_not_called()
