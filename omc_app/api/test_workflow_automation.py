from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import MagicMock, patch

from omc_app.api import payments


class TestWorkflowAutomation(TestCase):
    def _case(self, status="Open"):
        case = MagicMock()
        case.name = "OMC-SR-TEST"
        case.service = "TEST-SERVICE"
        case.service_title = "Test Service"
        case.title = "Test Request"
        case.customer_profile = "OMC-CUST-TEST"
        case.status = status
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
    @patch.object(payments.frappe, "new_doc")
    @patch.object(payments.frappe, "get_doc")
    @patch.object(payments.frappe, "get_all", return_value=[])
    @patch.object(payments.frappe.db, "exists", return_value=True)
    @patch.object(payments.frappe, "log_error")
    def test_zero_price_does_not_create_payment(
        self, log_error, _exists, _get_all, get_doc, new_doc, _approved, _has_doctype
    ):
        get_doc.return_value = SimpleNamespace(base_price=0, currency="PKR")
        self.assertIsNone(payments._ensure_payment_for_case(self._case()))
        new_doc.assert_not_called()
        log_error.assert_called_once()

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
        case.save.assert_called_once_with(ignore_permissions=True)
        payment.insert.assert_called_once_with(ignore_permissions=True)
        timeline.assert_called_once()
        notification.assert_called_once()

    @patch.object(payments.frappe, "get_all")
    def test_payment_reviewer_users_include_assignee_and_managers(self, get_all):
        get_all.side_effect = [
            ["admin@example.com", "manager@example.com"],
            ["admin@example.com", "manager@example.com", "staff@example.com"],
        ]
        case = self._case()
        case.assigned_staff = "staff@example.com"

        users = payments._payment_reviewer_users(case)

        self.assertEqual(
            users,
            ["admin@example.com", "manager@example.com", "staff@example.com"],
        )

    @patch.object(payments.mobile, "_create_customer_notification")
    @patch.object(payments, "_payment_reviewer_users")
    def test_receipt_review_notifications_are_sent_to_reviewers(
        self,
        reviewer_users,
        create_notification,
    ):
        reviewer_users.return_value = [
            "admin@example.com",
            "manager@example.com",
        ]
        create_notification.side_effect = [
            SimpleNamespace(name="NOTIF-1"),
            SimpleNamespace(name="NOTIF-2"),
        ]

        result = payments._notify_payment_reviewers(
            self._case(),
            title="Payment receipt submitted",
            message="Review receipt.",
        )

        self.assertEqual(result, ["NOTIF-1", "NOTIF-2"])
        self.assertEqual(create_notification.call_count, 2)

