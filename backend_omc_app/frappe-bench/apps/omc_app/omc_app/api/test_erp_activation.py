from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

from omc_app.api import erp_activation


class TestErpActivation(TestCase):
    def _request(
        self,
        *,
        final_price=25000,
        status="Waiting for Payment",
        erp_customer="",
        erp_service="",
        erp_task="",
    ):
        return SimpleNamespace(
            name="OMC-SR-TEST",
            final_price=final_price,
            status=status,
            erp_customer=erp_customer,
            erp_service=erp_service,
            erp_task=erp_task,
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
            patch.object(
                erp_activation,
                "_paid_payment_exists",
                return_value=False,
            ),
            patch.object(
                erp_activation.erp_service_task_adapter,
                "sync_request",
            ) as sync_request,
        ):
            result = erp_activation.activate_request(
                request,
                service=service,
            )

        self.assertEqual(result["status"], "Not Started")
        self.assertFalse(result["eligible"])
        self.assertFalse(result["created"])
        self.assertIn("Payment must be confirmed", result["reason"])
        sync_request.assert_not_called()

    def test_paid_service_activates_after_payment_confirmation(self):
        request = self._request()
        service = self._service()
        profile = SimpleNamespace(name="PROFILE-1")

        sync_result = {
            "status": "Synced",
            "created": True,
            "erp_customer": "CUST-1",
            "erp_service": "SERVICE-1",
            "erp_task": "TASK-1",
        }

        with (
            patch.object(
                erp_activation,
                "_paid_payment_exists",
                return_value=True,
            ),
            patch.object(
                erp_activation.erp_service_task_adapter,
                "sync_request",
                return_value=sync_result,
            ) as sync_request,
        ):
            result = erp_activation.activate_request(
                request,
                service=service,
                profile=profile,
                repair=True,
            )

        self.assertEqual(result["status"], "Synced")
        self.assertTrue(result["eligible"])
        self.assertTrue(result["created"])

        sync_request.assert_called_once_with(
            request,
            service=service,
            profile=profile,
            manual_customer=None,
            repair=True,
        )

    def test_zero_price_activates_once_in_progress(self):
        request = self._request(
            final_price=0,
            status="In Progress",
        )
        service = self._service(base_price=0)

        sync_result = {
            "status": "Synced",
            "created": True,
            "erp_customer": "CUST-1",
            "erp_service": "SERVICE-1",
            "erp_task": "TASK-1",
        }

        with (
            patch.object(
                erp_activation,
                "_paid_payment_exists",
            ) as paid_payment_exists,
            patch.object(
                erp_activation.erp_service_task_adapter,
                "sync_request",
                return_value=sync_result,
            ) as sync_request,
        ):
            result = erp_activation.activate_request(
                request,
                service=service,
            )

        self.assertTrue(result["eligible"])
        self.assertEqual(result["status"], "Synced")
        paid_payment_exists.assert_not_called()
        sync_request.assert_called_once()

    def test_zero_price_before_in_progress_is_not_eligible(self):
        request = self._request(
            final_price=0,
            status="Open",
        )
        service = self._service(base_price=0)

        with patch.object(
            erp_activation.erp_service_task_adapter,
            "sync_request",
        ) as sync_request:
            result = erp_activation.activate_request(
                request,
                service=service,
            )

        self.assertEqual(result["status"], "Not Started")
        self.assertFalse(result["eligible"])
        self.assertIn("Zero-price request", result["reason"])
        sync_request.assert_not_called()

    def test_existing_complete_erp_links_are_reconciled_without_payment_gate(self):
        request = self._request(
            erp_service="SERVICE-EXISTING",
            erp_task="TASK-EXISTING",
        )
        service = self._service()

        sync_result = {
            "status": "Synced",
            "created": False,
            "erp_customer": "CUST-1",
            "erp_service": "SERVICE-EXISTING",
            "erp_task": "TASK-EXISTING",
        }

        def exists(doctype, name):
            return (doctype, name) in {
                ("Service", "SERVICE-EXISTING"),
                ("Task", "TASK-EXISTING"),
            }

        with (
            patch.object(
                erp_activation.frappe.db,
                "exists",
                side_effect=exists,
            ),
            patch.object(
                erp_activation,
                "_paid_payment_exists",
            ) as paid_payment_exists,
            patch.object(
                erp_activation.erp_service_task_adapter,
                "sync_request",
                return_value=sync_result,
            ) as sync_request,
        ):
            result = erp_activation.activate_request(
                request,
                service=service,
                repair=True,
            )

        self.assertTrue(result["eligible"])
        self.assertFalse(result["created"])
        paid_payment_exists.assert_not_called()

        sync_request.assert_called_once_with(
            request,
            service=service,
            profile=None,
            manual_customer=None,
            repair=True,
        )
