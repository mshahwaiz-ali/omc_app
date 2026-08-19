from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

from omc_app.api import bridge_outbox, erp_activation


class TestErpActivation(TestCase):
    def _request(
        self,
        *,
        final_price=25000,
        status="Waiting for Payment",
        erp_customer="",
        erp_service="",
        erp_task="",
        request_state="Pending Payment",
        payment_policy_snapshot="Full Settlement",
        payable_amount=None,
    ):
        return SimpleNamespace(
            name="OMC-SR-TEST",
            final_price=final_price,
            status=status,
            erp_customer=erp_customer,
            erp_service=erp_service,
            erp_task=erp_task,
            request_state=request_state,
            payment_policy_snapshot=payment_policy_snapshot,
            payable_amount=final_price if payable_amount is None else payable_amount,
            post_paid_approved_by="",
            post_paid_approved_at=None,
            activation_version=1,
        )

    def _service(self, base_price=25000):
        return SimpleNamespace(
            name="OMC-SERVICE-TEST",
            base_price=base_price,
            erp_task_type="GST Registration",
        )

    def test_paid_service_unpaid_does_not_create_erp_records(self):
        request = self._request()
        service = self._service()

        with (
            patch.object(bridge_outbox.frappe.db, "exists", return_value=False),
            patch.object(bridge_outbox, "enqueue_if_eligible") as enqueue,
        ):
            result = erp_activation.activate_request(
                request,
                service=service,
            )

        self.assertEqual(result["status"], "Not Started")
        self.assertFalse(result["eligible"])
        self.assertFalse(result["created"])
        self.assertIn("settlement", result["reason"].lower())
        enqueue.assert_not_called()

    def test_paid_service_activates_after_payment_confirmation(self):
        request = self._request()
        service = self._service()
        profile = SimpleNamespace(name="PROFILE-1")

        with (
            patch.object(bridge_outbox.frappe.db, "exists", return_value=True),
            patch.object(
                bridge_outbox, "enqueue_if_eligible", return_value="BRIDGE-OP-1"
            ) as enqueue,
        ):
            result = erp_activation.activate_request(
                request,
                service=service,
                profile=profile,
                repair=True,
            )

        self.assertEqual(result["status"], "Pending")
        self.assertTrue(result["eligible"])
        self.assertFalse(result["created"])
        self.assertEqual(result["operation"], "BRIDGE-OP-1")
        enqueue.assert_called_once_with(request.name)

    def test_zero_price_activates_once_in_progress(self):
        request = self._request(
            final_price=0,
            status="Open",
            request_state="Payment Not Required",
            payment_policy_snapshot="No Charge",
            payable_amount=0,
        )
        service = self._service(base_price=0)

        with patch.object(
            bridge_outbox, "enqueue_if_eligible", return_value="BRIDGE-OP-1"
        ) as enqueue:
            result = erp_activation.activate_request(
                request,
                service=service,
            )

        self.assertTrue(result["eligible"])
        self.assertEqual(result["status"], "Pending")
        enqueue.assert_called_once_with(request.name)

    def test_zero_price_before_in_progress_is_not_eligible(self):
        request = self._request(
            final_price=0,
            status="Open",
            request_state="Draft",
            payment_policy_snapshot="No Charge",
            payable_amount=0,
        )
        service = self._service(base_price=0)

        with patch.object(bridge_outbox, "enqueue_if_eligible") as enqueue:
            result = erp_activation.activate_request(
                request,
                service=service,
            )

        self.assertEqual(result["status"], "Not Started")
        self.assertFalse(result["eligible"])
        self.assertIn("not ready", result["reason"])
        enqueue.assert_not_called()

    def test_existing_erp_links_do_not_bypass_settlement_gate(self):
        request = self._request(
            erp_service="SERVICE-EXISTING",
            erp_task="TASK-EXISTING",
        )
        service = self._service()

        with (
            patch.object(bridge_outbox.frappe.db, "exists", return_value=False),
            patch.object(bridge_outbox, "enqueue_if_eligible") as enqueue,
        ):
            result = erp_activation.activate_request(
                request,
                service=service,
                repair=True,
            )

        self.assertFalse(result["eligible"])
        self.assertFalse(result["created"])
        enqueue.assert_not_called()
