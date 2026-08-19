from unittest.mock import patch

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.api import (
    account_security,
    cors,
    expense_guard,
    guest_session,
    manual_customer_conversion,
    mobile_state_mutations,
    password_reset,
    pending_registration,
    profile,
    profile_guard,
    profile_self_service,
    service_request_mutations,
    tax_calculator_guard,
    tax_calculator_mutations,
)


class TestHttpSecurityContract(FrappeTestCase):
    def _assert_post_only(self, function):
        methods = set(frappe.allowed_http_methods_for_whitelisted_func.get(function) or [])
        self.assertEqual(methods, {"POST"}, function.__name__)

    def test_sensitive_mutations_are_post_only(self):
        functions = (
            pending_registration.start_registration,
            pending_registration.resend_verification,
            pending_registration.complete_registration,
            pending_registration.verify_registration,
            password_reset.request_reset,
            password_reset.reset_password,
            account_security.verify_current_password,
            account_security.change_password,
            account_security.delete_account,
            guest_session.create_guest_session,
            guest_session.update_guest_activity,
            profile.upload_profile_image,
            profile_guard.update_profile,
            profile_guard.update_contact_info,
            profile_self_service.update_work_address,
            profile_self_service.dismiss_work_address_prompt,
            service_request_mutations.cancel_service_request,
            service_request_mutations.update_service_case_status,
            manual_customer_conversion.convert_manual_customer,
            expense_guard.upload_expense_receipt,
            tax_calculator_guard.calculate_tax,
            tax_calculator_mutations.share_tax_estimate_with_consultant,
            tax_calculator_mutations.download_tax_estimate_pdf,
            tax_calculator_mutations.start_service_from_calculation,
            mobile_state_mutations.mark_notification_read,
            mobile_state_mutations.mark_notification_unread,
            mobile_state_mutations.mark_all_notifications_read,
            mobile_state_mutations.dismiss_notification,
            mobile_state_mutations.restore_notification,
            mobile_state_mutations.register_push_token,
            mobile_state_mutations.unregister_push_token,
            mobile_state_mutations.update_settings_preferences,
            mobile_state_mutations.upload_payment_receipt,
        )
        for function in functions:
            with self.subTest(function=function.__name__):
                self._assert_post_only(function)

    def test_verification_status_endpoint_is_read_only_get_compatible(self):
        methods = set(
            frappe.allowed_http_methods_for_whitelisted_func.get(
                pending_registration.get_registration_verification_status
            )
            or []
        )
        self.assertTrue(not methods or "GET" in methods)

    def test_cors_rejects_wildcard_null_and_non_origin_values(self):
        self.assertEqual(cors._valid_origin("*"), "")
        self.assertEqual(cors._valid_origin("null"), "")
        self.assertEqual(cors._valid_origin("https://example.com/path"), "")
        self.assertEqual(cors._valid_origin("https://user:pass@example.com"), "")
        self.assertEqual(cors._valid_origin("https://example.com"), "https://example.com")

    def test_cors_has_no_implicit_localhost_allowlist(self):
        with patch.object(frappe, "conf", {}):
            self.assertEqual(cors._allowed_origins(), frozenset())
