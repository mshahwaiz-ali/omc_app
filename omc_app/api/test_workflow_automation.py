from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import MagicMock, patch

from omc_app.api import payments


class TestWorkflowAutomation(TestCase):
    def _case(self, status="Waiting for Payment"):
        case = MagicMock()
        case.name = "OMC-SR-TEST"
        case.service = "TEST-SERVICE"
        case.service_title = "Test Service"
        case.title = "Test Request"
        case.customer_profile = "OMC-CUST-TEST"
        case.status = status
        case.final_price = None
        case.payable_amount = 25000
        case.pricing_currency = None
        case.payment_policy_snapshot = "Full Settlement"
        case.request_state = "Pending Payment"
        return case

    @patch.object(payments.mobile, "_has_doctype", return_value=True)
    @patch.object(payments.frappe, "get_all")
    def test_existing_payment_prevents_duplicate(self, get_all, _has_doctype):
        get_all.return_value = [SimpleNamespace(name="OMC-PAY-EXISTING")]
        self.assertEqual(
            payments._ensure_payment_for_case(self._case()),
            "OMC-PAY-EXISTING",
        )

    @patch.object(payments.mobile, "_has_doctype", return_value=True)
    @patch.object(payments, "_approved_required_documents", return_value=False)
    @patch.object(payments.frappe, "get_all", return_value=[])
    def test_partial_approval_does_not_open_payment(
        self, _get_all, _approved, _has_doctype
    ):
        self.assertIsNone(payments._ensure_payment_for_case(self._case()))

    @patch.object(payments.mobile, "_has_doctype", return_value=True)
    @patch.object(payments, "_approved_required_documents", return_value=True)
    @patch.object(payments.mobile, "_create_customer_notification")
    @patch.object(payments.mobile, "_create_service_timeline_entry")
    @patch("omc_app.api.bridge_outbox.enqueue_if_eligible")
    @patch.object(payments.frappe, "new_doc")
    @patch.object(payments.frappe, "get_doc")
    @patch.object(payments.frappe, "get_all", return_value=[])
    @patch.object(payments.frappe.db, "exists", return_value=True)
    @patch.object(payments.frappe, "log_error")
    def test_zero_price_skips_payment_and_activates_erp(
        self,
        log_error,
        _exists,
        _get_all,
        get_doc,
        new_doc,
        enqueue,
        timeline,
        _notification,
        _approved,
        _has_doctype,
    ):
        service = SimpleNamespace(
            base_price=0,
            currency="PKR",
            title="Test Service",
        )
        get_doc.return_value = service

        case = self._case()
        case.assigned_staff = ""
        case.payable_amount = 0
        case.final_price = 0
        case.payment_policy_snapshot = "No Charge"
        case.request_state = "Payment Not Required"

        self.assertIsNone(
            payments._ensure_payment_for_case(case)
        )

        self.assertEqual(case.status, "Waiting for Payment")
        case.save.assert_not_called()

        new_doc.assert_not_called()
        log_error.assert_not_called()

        enqueue.assert_called_once_with(case.name)
        timeline.assert_not_called()

    @patch.object(payments.mobile, "_has_doctype", return_value=True)
    @patch.object(payments, "_approved_required_documents", return_value=True)
    @patch.object(payments.mobile, "_create_customer_notification")
    @patch.object(payments.mobile, "_create_service_timeline_entry")
    @patch.object(payments.frappe.db, "commit")
    @patch.object(payments.frappe.db, "exists", return_value=True)
    @patch.object(payments.frappe, "get_all", return_value=[])
    @patch.object(payments.frappe, "get_doc")
    @patch.object(payments.frappe, "new_doc")
    def test_final_approval_opens_payment_and_advances_case(
        self, new_doc, get_doc, _get_all, _exists, _commit, timeline,
        notification, _approved, _has_doctype
    ):
        get_doc.return_value = SimpleNamespace(
            base_price=25000, currency="PKR", title="Test Service"
        )
        payment = MagicMock()
        payment.name = "OMC-PAY-NEW"
        new_doc.return_value = payment
        case = self._case()
        result = payments._ensure_payment_for_case(case)
        self.assertEqual(result, "OMC-PAY-NEW")
        self.assertEqual(case.status, "Waiting for Payment")
        case.save.assert_not_called()
        payment.insert.assert_called_once_with(ignore_permissions=True)
        timeline.assert_called_once()
        notification.assert_called_once()
