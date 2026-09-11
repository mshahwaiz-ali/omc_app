from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests.utils import FrappeTestCase

from omc_app import hooks
from omc_app.api import payment_mutation_guard


class TestPartialPaymentReceiptContinuation(FrappeTestCase):
    def _payment(self):
        return SimpleNamespace(
            name="OMC-PAY-PARTIAL",
            service_request="OMC-SR-PARTIAL",
            status="Partially Paid",
        )

    def test_flutter_multipart_route_is_guarded(self):
        self.assertEqual(
            hooks.override_whitelisted_methods[
                "omc_app.api.payments.upload_payment_receipt_multipart"
            ],
            "omc_app.api.payment_mutation_guard.upload_payment_receipt_multipart",
        )

    def test_follow_up_receipt_preserves_activated_service_status(self):
        payment = self._payment()
        with (
            patch.object(
                payment_mutation_guard,
                "_load_mutable_payment",
                return_value=payment,
            ),
            patch.object(
                payment_mutation_guard,
                "_activated_case_snapshot",
                return_value="In Progress",
            ),
            patch.object(
                payment_mutation_guard.payments,
                "upload_payment_receipt_multipart",
                return_value={"updated": True, "status": "Receipt Submitted"},
            ) as upload,
            patch.object(
                payment_mutation_guard,
                "_restore_activated_case_status",
            ) as restore,
        ):
            result = payment_mutation_guard.upload_payment_receipt_multipart(
                payment_id=payment.name,
                payment_reference="BANK-2",
                remarks="Second installment",
                idempotency_key="receipt-2",
            )

        self.assertTrue(result["updated"])
        upload.assert_called_once_with(
            payment_id=payment.name,
            payment_reference="BANK-2",
            remarks="Second installment",
            idempotency_key="receipt-2",
        )
        restore.assert_called_once_with(payment, "In Progress")

    def test_restore_only_applies_while_request_remains_activated(self):
        payment = self._payment()
        with (
            patch.object(
                payment_mutation_guard.frappe.db,
                "get_value",
                return_value="Activated",
            ),
            patch.object(
                payment_mutation_guard.frappe.db,
                "set_value",
            ) as set_value,
        ):
            payment_mutation_guard._restore_activated_case_status(
                payment,
                "In Progress",
            )

        set_value.assert_called_once_with(
            "OMC Service Request",
            payment.service_request,
            "status",
            "In Progress",
            update_modified=False,
        )
