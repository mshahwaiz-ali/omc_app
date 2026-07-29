from types import SimpleNamespace
from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.omc_app.doctype.omc_service_payment.omc_service_payment import (
    OMCServicePayment,
    _assert_payment_status_transition,
)


class TestPaymentLifecycleIntegrity(FrappeTestCase):
    def test_valid_payment_status_transition_is_allowed(self):
        _assert_payment_status_transition("Pending", "Receipt Submitted")
        _assert_payment_status_transition("Receipt Submitted", "Under Review")
        _assert_payment_status_transition("Under Review", "Paid")
        _assert_payment_status_transition("Rejected", "Receipt Submitted")

    def test_invalid_payment_status_transition_is_rejected(self):
        with self.assertRaises(frappe.ValidationError):
            _assert_payment_status_transition("Pending", "Paid")

        with self.assertRaises(frappe.ValidationError):
            _assert_payment_status_transition("Paid", "Receipt Submitted")

        with self.assertRaises(frappe.ValidationError):
            _assert_payment_status_transition("Cancelled", "Under Review")

    @patch("frappe.db.get_value", return_value="Completed")
    def test_terminal_service_request_blocks_payment_mutation(self, get_value):
        payment = OMCServicePayment(
            {
                "doctype": "OMC Service Payment",
                "service_request": "OMC-SR-TEST",
                "status": "Pending",
            }
        )

        with self.assertRaises(frappe.ValidationError):
            payment._assert_parent_is_mutable()

        get_value.assert_called_once_with(
            "OMC Service Request",
            "OMC-SR-TEST",
            "status",
        )

    @patch("frappe.db.get_value", return_value="In Progress")
    def test_non_terminal_service_request_allows_payment_mutation(self, get_value):
        payment = OMCServicePayment(
            {
                "doctype": "OMC Service Payment",
                "service_request": "OMC-SR-TEST",
                "status": "Pending",
            }
        )

        payment._assert_parent_is_mutable()
        get_value.assert_called_once()

    @patch("frappe.utils.now_datetime", return_value="2026-07-29 21:30:00")
    @patch.object(OMCServicePayment, "_assert_parent_is_mutable")
    def test_paid_on_is_set_and_cleared_consistently(
        self,
        assert_parent_is_mutable,
        now_datetime,
    ):
        payment = OMCServicePayment(
            {
                "doctype": "OMC Service Payment",
                "service_request": "OMC-SR-TEST",
                "status": "Paid",
            }
        )
        payment.get_doc_before_save = lambda: SimpleNamespace(status="Under Review")

        payment.before_save()

        self.assertEqual(payment.paid_on, "2026-07-29 21:30:00")
        assert_parent_is_mutable.assert_called_once_with()

        payment.status = "Rejected"
        payment.get_doc_before_save = lambda: SimpleNamespace(status="Under Review")
        payment.before_save()

        self.assertIsNone(payment.paid_on)
