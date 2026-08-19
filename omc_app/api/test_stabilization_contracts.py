from __future__ import annotations

import inspect

import frappe
from frappe.tests.utils import FrappeTestCase

from omc_app.setup import lifecycle


POST_ONLY_METHODS = (
    "omc_app.api.account_security.change_password",
    "omc_app.api.account_security.verify_current_password",
    "omc_app.api.customer_activation.request_activation",
    "omc_app.api.customer_activation.complete_activation",
    "omc_app.api.pending_registration.start_registration",
    "omc_app.api.pending_registration.resend_verification",
    "omc_app.api.pending_registration.complete_registration",
    "omc_app.api.pending_registration.verify_registration",
    "omc_app.api.guest_session.create_guest_session",
    "omc_app.api.guest_session.update_guest_activity",
    "omc_app.api.mobile_entry_mutations.google_mobile_login",
    "omc_app.api.mobile_entry_mutations.create_lead",
    "omc_app.api.service_requests.create_service",
    "omc_app.api.assisted_service.create_request",
    "omc_app.api.service_request_mutations.cancel_service_request",
    "omc_app.api.service_request_mutations.update_service_case_status",
    "omc_app.api.document_upload.upload_service_document",
    "omc_app.api.service_document_guard.update_service_document_status",
    "omc_app.api.payment_mutation_guard.upload_payment_receipt_file",
    "omc_app.api.payment_mutation_guard.review_payment_receipt",
    "omc_app.api.profile.upload_profile_image",
    "omc_app.api.profile_self_service.update_profile",
    "omc_app.api.profile_self_service.update_work_address",
    "omc_app.api.profile_self_service.dismiss_work_address_prompt",
    "omc_app.api.tax_calculator_guard.calculate_tax",
    "omc_app.api.tax_calculator_mutations.share_tax_estimate_with_consultant",
    "omc_app.api.tax_calculator_mutations.download_tax_estimate_pdf",
    "omc_app.api.tax_calculator_mutations.start_service_from_calculation",
    "omc_app.api.expense_write_guard.create_expense_entry",
    "omc_app.api.expense_write_guard.update_expense_entry",
    "omc_app.api.expense_write_guard.delete_expense_entry",
    "omc_app.api.expense_write_guard.bulk_sync_expense_entries",
    "omc_app.api.expense_write_guard.save_expense_budget",
    "omc_app.api.expense_guard.upload_expense_receipt",
    "omc_app.api.mobile_state_mutations.mark_notification_read",
    "omc_app.api.mobile_state_mutations.mark_notification_unread",
    "omc_app.api.mobile_state_mutations.mark_all_notifications_read",
    "omc_app.api.mobile_state_mutations.dismiss_notification",
    "omc_app.api.mobile_state_mutations.restore_notification",
    "omc_app.api.mobile_state_mutations.register_push_token",
    "omc_app.api.mobile_state_mutations.unregister_push_token",
    "omc_app.api.mobile_state_mutations.update_settings_preferences",
    "omc_app.api.mobile_state_mutations.upload_payment_receipt",
    "omc_app.api.support_chat.create_support_ticket",
    "omc_app.api.support_chat.add_support_ticket_reply",
    "omc_app.api.support_chat.mark_support_ticket_read",
    "omc_app.api.support_ticket_guard.update_support_ticket_status",
    "omc_app.api.support_ticket_guard.assign_support_ticket",
    "omc_app.api.pricing_guard.review_discount",
    "omc_app.api.accounting_policy.link_sales_invoice",
    "omc_app.api.bridge_outbox.recover_failed_operation",
)


class TestStabilizationContracts(FrappeTestCase):
    def test_sensitive_mutations_are_post_only(self):
        for dotted_path in POST_ONLY_METHODS:
            method = frappe.get_attr(dotted_path)
            allowed = frappe.allowed_http_methods_for_whitelisted_func.get(method)
            self.assertIsNotNone(allowed, dotted_path)
            self.assertEqual(
                {str(value).upper() for value in allowed},
                {"POST"},
                dotted_path,
            )

    def test_registration_get_routes_remain_read_only(self):
        for dotted_path in (
            "omc_app.api.pending_registration.get_registration_verification_status",
            "omc_app.api.pending_registration.verify_registration_web",
        ):
            method = frappe.get_attr(dotted_path)
            allowed = frappe.allowed_http_methods_for_whitelisted_func.get(method)
            self.assertIsNotNone(allowed, dotted_path)
            self.assertIn("GET", {str(value).upper() for value in allowed})

        web_source = inspect.getsource(
            frappe.get_attr("omc_app.api.pending_registration.verify_registration_web")
        )
        forbidden = (
            "complete_registration(",
            "create_pending_registration(",
            ".insert(",
            ".save(",
            "frappe.db.commit(",
        )
        for token in forbidden:
            self.assertNotIn(token, web_source)

    def test_after_migrate_is_validation_only(self):
        source = inspect.getsource(lifecycle.after_migrate)
        self.assertIn("validate_site()", source)
        for forbidden in (
            "initialize_site(",
            "sync_roles(",
            "apply_branding(",
            "sync_workspace(",
            "frappe.db.commit(",
        ):
            self.assertNotIn(forbidden, source)
