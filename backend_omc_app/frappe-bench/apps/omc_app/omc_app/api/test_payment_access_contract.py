from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import call, patch

import frappe

from omc_app.api import mobile, payments


class TestPaymentAccessScope(TestCase):
    @patch.object(payments, "_customer_profile_name_for_user")
    @patch.object(payments, "_owned_referral_profile_names")
    @patch.object(payments.frappe, "get_all")
    def test_internal_scope_contains_only_own_and_owned_referral_cases(
        self,
        get_all,
        referral_profiles,
        own_profile,
    ):
        own_profile.return_value = "CUST-OWN"
        referral_profiles.return_value = ["CUST-REF-1", "CUST-REF-2"]
        get_all.side_effect = [
            ["CASE-OWN"],
            ["CASE-REF-1", "CASE-REF-2"],
        ]

        names = payments._accessible_service_request_names(
            internal_user="staff@example.com"
        )

        self.assertEqual(
            names,
            {"CASE-OWN", "CASE-REF-1", "CASE-REF-2"},
        )
        self.assertEqual(
            get_all.call_args_list,
            [
                call(
                    "OMC Service Request",
                    filters={"customer_profile": "CUST-OWN"},
                    pluck="name",
                ),
                call(
                    "OMC Service Request",
                    filters={
                        "customer_mode": "My Referral",
                        "referral_owner": "staff@example.com",
                        "customer_profile": [
                            "in",
                            ["CUST-REF-1", "CUST-REF-2"],
                        ],
                    },
                    pluck="name",
                ),
            ],
        )

    @patch.object(payments, "_customer_profile_name_for_user", return_value=None)
    @patch.object(payments, "_owned_referral_profile_names", return_value=[])
    def test_internal_scope_is_empty_without_own_or_referral_relationship(
        self,
        _referral_profiles,
        _own_profile,
    ):
        self.assertEqual(
            payments._accessible_service_request_names(
                internal_user="unrelated@example.com"
            ),
            set(),
        )

    @patch.object(
        payments,
        "_accessible_service_request_names",
        return_value={"CASE-ALLOWED"},
    )
    def test_guessed_unrelated_payment_case_is_denied(self, _accessible):
        with self.assertRaises(frappe.PermissionError):
            payments._assert_service_request_payment_access(
                "CASE-OTHER",
                internal_user="staff@example.com",
            )

    @patch.object(payments.frappe, "get_all")
    def test_referral_profiles_require_active_assistance_consent(self, get_all):
        get_all.return_value = ["CUST-REF"]

        result = payments._owned_referral_profile_names("staff@example.com")

        self.assertEqual(result, ["CUST-REF"])
        get_all.assert_called_once_with(
            "OMC Customer Profile",
            filters={
                "referred_by": "staff@example.com",
                "referral_assistance_consent": 1,
            },
            pluck="name",
        )


class TestPaymentNotificationRouting(TestCase):
    def _case(self):
        return SimpleNamespace(
            name="CASE-1",
            customer_profile="CUST-1",
        )

    @patch.object(payments.mobile, "_create_customer_notification")
    def test_payment_notification_can_reference_exact_payment(
        self,
        create_notification,
    ):
        payments._notify_customer(
            self._case(),
            title="Payment is ready",
            message="Proceed with payment.",
            notification_type="Payment",
            reference_doctype=payments.PAYMENT_DOCTYPE,
            reference_name="PAY-1",
        )

        create_notification.assert_called_once_with(
            customer_profile="CUST-1",
            title="Payment is ready",
            message="Proceed with payment.",
            notification_type="Payment",
            reference_doctype=payments.PAYMENT_DOCTYPE,
            reference_name="PAY-1",
        )


class TestServiceCasePaymentContract(TestCase):
    def _case(self, *, status="Open", service="SERVICE-1"):
        return SimpleNamespace(
            name="CASE-1",
            status=status,
            service=service,
            final_price=25000,
        )

    def _required_template(self):
        return {
            "title": "CNIC",
            "document_title": "CNIC",
            "type": "Identity",
            "document_type": "Identity",
            "is_required": 1,
        }

    @patch.object(mobile.frappe.db, "exists", return_value=True)
    @patch.object(mobile.frappe.db, "get_value", return_value=25000)
    @patch.object(mobile.frappe, "get_all", return_value=[])
    def test_incomplete_documents_block_payment(
        self,
        _get_all,
        _get_value,
        _exists,
    ):
        result = mobile._service_case_payment_contract(
            self._case(),
            documents=[],
            required_document_templates=[self._required_template()],
        )

        self.assertFalse(result["documents_complete"])
        self.assertFalse(result["payment_eligible"])
        self.assertEqual(
            result["payment_block_reason"],
            "required_documents_not_approved",
        )
        self.assertEqual(result["next_action"], "upload_documents")

    @patch.object(mobile.frappe.db, "exists", return_value=True)
    @patch.object(mobile.frappe.db, "get_value", return_value=25000)
    @patch.object(mobile.frappe, "get_all", return_value=[])
    def test_approved_documents_without_payment_wait_for_opening(
        self,
        _get_all,
        _get_value,
        _exists,
    ):
        result = mobile._service_case_payment_contract(
            self._case(),
            documents=[
                {
                    "title": "CNIC",
                    "type": "Identity",
                    "status": "Approved",
                    "file_url": "/private/files/cnic.pdf",
                }
            ],
            required_document_templates=[self._required_template()],
        )

        self.assertTrue(result["documents_complete"])
        self.assertTrue(result["payment_eligible"])
        self.assertEqual(result["payment_id"], "")
        self.assertEqual(
            result["payment_block_reason"],
            "payment_not_opened",
        )
        self.assertEqual(result["next_action"], "await_payment_opening")

    @patch.object(mobile.frappe.db, "exists", return_value=True)
    @patch.object(mobile.frappe.db, "get_value", return_value=25000)
    @patch.object(mobile.frappe, "get_all")
    def test_receipt_under_review_has_stable_action(
        self,
        get_all,
        _get_value,
        _exists,
    ):
        get_all.return_value = [
            SimpleNamespace(
                name="PAY-1",
                status="Receipt Submitted",
                amount=25000,
                currency="PKR",
                receipt_attachment="/private/files/receipt.pdf",
            )
        ]

        result = mobile._service_case_payment_contract(
            self._case(status="Waiting for Payment"),
            documents=[
                {
                    "title": "CNIC",
                    "type": "Identity",
                    "status": "Approved",
                    "file_url": "/private/files/cnic.pdf",
                }
            ],
            required_document_templates=[self._required_template()],
        )

        self.assertEqual(result["payment_id"], "PAY-1")
        self.assertEqual(result["payment_status"], "Receipt Submitted")
        self.assertEqual(
            result["payment_block_reason"],
            "receipt_under_review",
        )
        self.assertEqual(result["next_action"], "await_payment_review")

    @patch.object(mobile.frappe.db, "exists", return_value=True)
    @patch.object(mobile.frappe.db, "get_value", return_value=25000)
    @patch.object(mobile.frappe, "get_all")
    def test_paid_payment_advances_to_service_processing(
        self,
        get_all,
        _get_value,
        _exists,
    ):
        get_all.return_value = [
            SimpleNamespace(
                name="PAY-1",
                status="Paid",
                amount=25000,
                currency="PKR",
                receipt_attachment="/private/files/receipt.pdf",
            )
        ]

        result = mobile._service_case_payment_contract(
            self._case(status="In Progress"),
            documents=[],
            required_document_templates=[],
        )

        self.assertTrue(result["documents_complete"])
        self.assertFalse(result["payment_eligible"])
        self.assertEqual(
            result["payment_block_reason"],
            "payment_completed",
        )
        self.assertEqual(result["next_action"], "service_processing")
