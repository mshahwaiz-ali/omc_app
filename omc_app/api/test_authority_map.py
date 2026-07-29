from frappe.tests.utils import FrappeTestCase

from omc_app import hooks


class TestAuthorityMap(FrappeTestCase):
    def test_guarded_endpoint_authority_map(self):
        expected = {
            "omc_app.api.mobile.create_service": "omc_app.api.service_request_guard.create_service",
            "omc_app.api.mobile.get_service_cases": "omc_app.api.secured_mobile.get_service_cases",
            "omc_app.api.mobile.get_service_case": "omc_app.api.secured_mobile.get_service_case",
            "omc_app.api.mobile.update_service_case_status": "omc_app.api.secured_mobile.update_service_case_status",
            "omc_app.api.customer_documents.get_document": "omc_app.api.service_document_guard.get_document",
            "omc_app.api.customer_documents.update_service_document_status": "omc_app.api.service_document_guard.update_service_document_status",
            "omc_app.api.mobile.get_support_tickets": "omc_app.api.support_ticket_read_guard.get_support_tickets",
            "omc_app.api.mobile.get_support_ticket": "omc_app.api.support_ticket_read_guard.get_support_ticket",
            "omc_app.api.support_chat.get_active_support_ticket": "omc_app.api.support_ticket_read_guard.get_active_support_ticket",
            "omc_app.api.support_chat.get_support_unread_count": "omc_app.api.support_ticket_read_state_guard.get_support_unread_count",
            "omc_app.api.support_chat.mark_support_ticket_read": "omc_app.api.support_ticket_read_state_guard.mark_support_ticket_read",
            "omc_app.api.support_chat.update_support_ticket_status": "omc_app.api.support_ticket_guard.update_support_ticket_status",
            "omc_app.api.support_chat.assign_support_ticket": "omc_app.api.support_ticket_guard.assign_support_ticket",
            "omc_app.api.mobile.get_tasks": "omc_app.api.task_read_guard.get_tasks",
            "omc_app.api.mobile.get_task": "omc_app.api.task_read_guard.get_task",
            "omc_app.api.mobile.get_leads": "omc_app.api.lead_read_guard.get_leads",
            "omc_app.api.mobile.get_lead": "omc_app.api.lead_read_guard.get_lead",
            "omc_app.api.dashboard.get_dashboard_data": "omc_app.api.dashboard_read_guard.get_dashboard_data",
            "omc_app.api.referrals.validate_referral_code": "omc_app.referral_automation.validate_referral_code",
            "omc_app.api.referrals.get_my_referral_summary": "omc_app.api.referral_analytics.get_my_referral_summary",
            "omc_app.api.referrals.get_my_referrals": "omc_app.api.referral_analytics.get_my_referrals",
            "omc_app.api.assisted_service.get_customer_selection_options": "omc_app.api.assisted_service_policy.get_customer_selection_options",
            "omc_app.api.assisted_service.create_request": "omc_app.api.assisted_service_policy.create_request",
            "omc_app.api.internal_workspace.create_service_request_for_customer": "omc_app.api.assisted_service_policy.create_service_request_for_customer",
            "omc_app.api.expense.get_expense_entries": "omc_app.api.expense_read_guard.get_expense_entries",
            "omc_app.api.expense.get_expense_summary": "omc_app.api.expense_read_guard.get_expense_summary",
            "omc_app.api.expense.get_expense_budgets": "omc_app.api.expense_read_guard.get_expense_budgets",
            "omc_app.api.expense.create_expense_entry": "omc_app.api.expense_write_guard.create_expense_entry",
            "omc_app.api.expense.update_expense_entry": "omc_app.api.expense_write_guard.update_expense_entry",
            "omc_app.api.expense.bulk_sync_expense_entries": "omc_app.api.expense_write_guard.bulk_sync_expense_entries",
            "omc_app.api.expense.save_expense_budget": "omc_app.api.expense_write_guard.save_expense_budget",
            "omc_app.api.expense.upload_expense_receipt": "omc_app.api.expense_guard.upload_expense_receipt",
            "omc_app.api.payments.get_payments": "omc_app.api.payment_read_guard.get_payments",
            "omc_app.api.payments.get_payment": "omc_app.api.payment_read_guard.get_payment",
            "omc_app.api.payments.upload_payment_receipt_file": "omc_app.api.payment_mutation_guard.upload_payment_receipt_file",
            "omc_app.api.payments.review_payment_receipt": "omc_app.api.payment_mutation_guard.review_payment_receipt",
        }

        for endpoint, target in expected.items():
            self.assertEqual(hooks.override_whitelisted_methods.get(endpoint), target)
