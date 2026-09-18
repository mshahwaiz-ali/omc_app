from datetime import date
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import bridge_outbox, pay_later, request_lifecycle, workflow_automation
from omc_app.omc_app.doctype.omc_service_payment.omc_service_payment import (
    OMCServicePayment,
    _assert_payment_status_transition,
)


class TestPhase7PayLater(FrappeTestCase):
    def _request(
        self,
        *,
        policy="Full Settlement",
        mode="Prepaid",
        state="Pending Payment",
        status="Waiting for Payment",
    ):
        request = MagicMock()
        request.name = "OMC-SR-PAY-LATER"
        request.title = "Test Service"
        request.payment_policy_snapshot = policy
        request.payment_execution_mode = mode
        request.request_state = state
        request.status = status
        request.payable_amount = 30000
        request.post_paid_approved_by = None
        request.post_paid_approved_at = None
        request.pay_later_reason = ""
        request.expires_at = "2026-09-20 00:00:00"
        request.customer_profile = "OMC-CUST-1"
        return request

    def _payment(self, *, status="Pending", receipt_attachment=""):
        payment = MagicMock()
        payment.name = "OMC-PAY-LATER"
        payment.service_request = "OMC-SR-PAY-LATER"
        payment.status = status
        payment.amount = 30000
        payment.accounted_amount = 0
        payment.accounting_status = "Unmatched"
        payment.linked_invoice = ""
        payment.linked_payment_entry = ""
        payment.receipt_attachment = receipt_attachment
        payment.receipt_status = (
            "Rejected" if status == "Rejected" else "Not Submitted"
        )
        return payment

    def test_deferred_is_terminal_and_only_reachable_before_accounting(self):
        _assert_payment_status_transition("Pending", "Deferred")
        _assert_payment_status_transition("Rejected", "Deferred")

        with self.assertRaises(frappe.ValidationError):
            _assert_payment_status_transition("Deferred", "Receipt Submitted")

        with self.assertRaises(frappe.ValidationError):
            _assert_payment_status_transition("Under Review", "Deferred")

    @patch.object(pay_later, "_accounting_activity_exists", return_value=False)
    @patch.object(pay_later, "_unresolved_receipt_exists", return_value=False)
    def test_rejected_receipt_is_resolved_and_can_move_to_pay_later(
        self,
        _unresolved,
        _accounting,
    ):
        reason = pay_later._approval_block_reason(
            self._request(),
            self._payment(
                status="Rejected",
                receipt_attachment="/private/files/rejected.pdf",
            ),
        )
        self.assertEqual(reason, "")

    @patch.object(pay_later, "_accounting_activity_exists", return_value=False)
    @patch.object(pay_later, "_unresolved_receipt_exists", return_value=True)
    def test_unresolved_receipt_blocks_pay_later(
        self,
        _unresolved,
        _accounting,
    ):
        reason = pay_later._approval_block_reason(
            self._request(),
            self._payment(
                status="Pending",
                receipt_attachment="/private/files/receipt.pdf",
            ),
        )
        self.assertIn("Resolve or reject", reason)

    @patch.object(pay_later, "_accounting_activity_exists", return_value=True)
    @patch.object(pay_later, "_unresolved_receipt_exists", return_value=False)
    def test_existing_accounting_history_blocks_pay_later(
        self,
        _unresolved,
        _accounting,
    ):
        reason = pay_later._approval_block_reason(
            self._request(),
            self._payment(),
        )
        self.assertIn("accounting history", reason)

    @patch.object(pay_later.frappe, "new_doc")
    @patch.object(pay_later.bridge_outbox, "enqueue_if_eligible", return_value="OMC-BRIDGE-1")
    @patch.object(pay_later.security, "audit_event")
    @patch.object(pay_later.mobile, "_create_customer_notification")
    @patch.object(pay_later.mobile, "_create_service_timeline_entry")
    @patch.object(pay_later.frappe.db, "get_value", return_value="Ready for Activation")
    @patch.object(pay_later.frappe.db, "set_value")
    @patch.object(pay_later.frappe.db, "savepoint")
    @patch.object(pay_later.idempotency, "begin", return_value=None)
    @patch.object(pay_later.idempotency, "request_key", return_value="desk-pay-later:valid")
    @patch.object(pay_later.payments, "_assert_service_request_payment_access")
    @patch.object(pay_later, "_approval_block_reason", return_value="")
    @patch.object(pay_later, "_approval_capabilities")
    @patch.object(pay_later.security, "enforce_rate_limit")
    @patch.object(pay_later, "_current_user", return_value="finance@example.com")
    @patch.object(pay_later, "now_datetime", return_value="2026-09-19 01:00:00")
    @patch.object(pay_later, "_load_payment_request")
    def test_approval_defers_payment_without_creating_erp_accounting(
        self,
        load_pair,
        _now,
        _user,
        _rate,
        _capabilities,
        _block_reason,
        _scope,
        _key,
        _begin,
        _savepoint,
        set_value,
        _get_value,
        timeline,
        notification,
        audit,
        enqueue,
        new_doc,
    ):
        request = self._request()
        payment = self._payment()
        load_pair.return_value = (payment, request)

        result = pay_later.approve_pay_later(
            payment_id=payment.name,
            reason="Approved credit exception.",
            idempotency_key="desk-pay-later:1234567890",
        )

        self.assertTrue(result["updated"])
        self.assertEqual(result["payment_execution_mode"], "Pay Later")
        self.assertEqual(result["payment_status"], "Deferred")
        self.assertEqual(payment.status, "Deferred")
        payment.save.assert_called_once_with(ignore_permissions=True)
        self.assertEqual(request.payment_execution_mode, "Pay Later")
        self.assertEqual(request.post_paid_approved_by, "finance@example.com")
        self.assertEqual(request.pay_later_reason, "Approved credit exception.")
        self.assertIsNone(request.expires_at)
        enqueue.assert_called_once_with(request.name)
        timeline.assert_called_once()
        notification.assert_called_once()
        audit.assert_called_once()
        new_doc.assert_not_called()

        request_values = set_value.call_args_list[0].args[2]
        self.assertEqual(request_values["payment_execution_mode"], "Pay Later")
        self.assertIsNone(request_values["expires_at"])

    @patch.object(pay_later.frappe.db, "rollback")
    @patch.object(pay_later.idempotency, "begin", return_value=None)
    @patch.object(pay_later.idempotency, "request_key", return_value="desk-pay-later:valid")
    @patch.object(pay_later.security, "enforce_rate_limit")
    @patch.object(pay_later, "_approval_capabilities")
    @patch.object(pay_later, "_current_user", return_value="finance@example.com")
    @patch.object(pay_later.frappe.db, "savepoint")
    @patch.object(pay_later, "_load_payment_request")
    def test_reason_is_required(
        self,
        load_pair,
        _savepoint,
        _user,
        _capabilities,
        _rate,
        _key,
        _begin,
        _rollback,
    ):
        request = self._request()
        payment = self._payment()
        load_pair.return_value = (payment, request)

        with self.assertRaisesRegex(frappe.ValidationError, "reason is required"):
            pay_later.approve_pay_later(
                payment_id=payment.name,
                reason="",
                idempotency_key="desk-pay-later:1234567890",
            )

        payment.save.assert_not_called()

    def test_pay_later_bridge_eligibility_uses_request_mode_not_frozen_policy(self):
        request = SimpleNamespace(
            name="OMC-SR-PAY-LATER",
            request_state="Pending Payment",
            payment_policy_snapshot="Full Settlement",
            payment_execution_mode="Pay Later",
            payable_amount=30000,
            post_paid_approved_by="finance@example.com",
            post_paid_approved_at="2026-09-19 01:00:00",
            pay_later_reason="Approved credit exception.",
        )
        with (
            patch.object(bridge_outbox, "_accounting_status", return_value=""),
            patch.object(bridge_outbox, "_accounted_amount", return_value=0),
            patch.object(bridge_outbox.frappe.db, "exists", return_value=False),
        ):
            result = bridge_outbox.eligibility(request)

        self.assertTrue(result["eligible"])

    def test_legacy_post_paid_policy_does_not_auto_activate_prepaid_request(self):
        request = SimpleNamespace(
            name="OMC-SR-LEGACY-POLICY",
            request_state="Pending Payment",
            payment_policy_snapshot="Post-paid Approval",
            payment_execution_mode="Prepaid",
            payable_amount=30000,
            post_paid_approved_by="finance@example.com",
            post_paid_approved_at="2026-09-19 01:00:00",
            pay_later_reason="",
        )
        with (
            patch.object(bridge_outbox, "_accounting_status", return_value=""),
            patch.object(bridge_outbox, "_accounted_amount", return_value=0),
            patch.object(bridge_outbox.frappe.db, "exists", return_value=False),
        ):
            result = bridge_outbox.eligibility(request)

        self.assertFalse(result["eligible"])
        self.assertIn("ERP-reconciled", result["reason"])

    def test_positive_accounting_invalidates_pay_later_bridge_evidence(self):
        request = SimpleNamespace(
            name="OMC-SR-PAY-LATER",
            request_state="Pending Payment",
            payment_policy_snapshot="Full Settlement",
            payment_execution_mode="Pay Later",
            payable_amount=30000,
            post_paid_approved_by="finance@example.com",
            post_paid_approved_at="2026-09-19 01:00:00",
            pay_later_reason="Approved credit exception.",
        )
        with (
            patch.object(
                bridge_outbox,
                "_accounting_status",
                return_value="Partially Settled",
            ),
            patch.object(bridge_outbox, "_accounted_amount", return_value=15000),
            patch.object(bridge_outbox.frappe.db, "exists", return_value=False),
        ):
            result = bridge_outbox.eligibility(request)

        self.assertFalse(result["eligible"])
        self.assertIn("positive ERP payment evidence", result["reason"])

    @patch.object(request_lifecycle, "transition_request_state")
    @patch.object(request_lifecycle, "_lock_request")
    def test_pay_later_request_never_expires_as_pending_payment(
        self,
        lock_request,
        transition,
    ):
        lock_request.return_value = SimpleNamespace(
            name="OMC-SR-PAY-LATER",
            request_state="Pending Payment",
            payment_execution_mode="Pay Later",
            expires_at="2026-09-18 00:00:00",
        )

        self.assertFalse(
            request_lifecycle.expire_request("OMC-SR-PAY-LATER")
        )
        transition.assert_not_called()

    @patch.object(workflow_automation, "_notify_once")
    @patch.object(workflow_automation, "_reviewer_users", return_value=[])
    @patch.object(workflow_automation, "getdate", return_value=date(2026, 9, 19))
    @patch.object(workflow_automation.frappe, "get_all")
    def test_daily_payment_pending_reminder_is_suppressed_for_pay_later(
        self,
        get_all,
        _today,
        _reviewers,
        notify,
    ):
        get_all.return_value = [
            SimpleNamespace(
                name="OMC-SR-PAY-LATER",
                title="Service",
                status="Waiting for Payment",
                customer_profile="OMC-CUST-1",
                assigned_staff=None,
                expected_completion_date=None,
                payment_execution_mode="Pay Later",
                modified="2026-09-19 00:00:00",
            )
        ]

        summary = workflow_automation.run_daily_workflow_checks()

        self.assertEqual(summary["customer_reminders_created"], 0)
        notify.assert_not_called()

    def test_pay_later_completion_requires_linked_invoice_but_not_paid_status(self):
        request = SimpleNamespace(
            name="OMC-SR-PAY-LATER",
            payment_policy_snapshot="Full Settlement",
            payment_execution_mode="Pay Later",
            post_paid_approved_by="finance@example.com",
            post_paid_approved_at="2026-09-19 01:00:00",
            pay_later_reason="Approved credit exception.",
        )
        payments = [SimpleNamespace(status="Deferred")]

        with patch.object(
            workflow_automation,
            "_pay_later_invoice_linked",
            return_value=False,
        ):
            self.assertFalse(
                workflow_automation._payment_completion_satisfied(
                    request,
                    payments,
                )
            )

        with patch.object(
            workflow_automation,
            "_pay_later_invoice_linked",
            return_value=True,
        ):
            self.assertTrue(
                workflow_automation._payment_completion_satisfied(
                    request,
                    payments,
                )
            )

    @patch.object(
        frappe.db,
        "get_value",
        return_value=SimpleNamespace(
            payment_execution_mode="Pay Later",
            post_paid_approved_by="finance@example.com",
            post_paid_approved_at="2026-09-19 01:00:00",
            pay_later_reason="Approved credit exception.",
        ),
    )
    def test_deferred_payment_controller_requires_guarded_request_approval(
        self,
        get_value,
    ):
        payment = OMCServicePayment(
            {
                "doctype": "OMC Service Payment",
                "service_request": "OMC-SR-PAY-LATER",
                "status": "Deferred",
                "amount": 30000,
            }
        )
        payment._assert_deferred_authorization()
        get_value.assert_called_once()
