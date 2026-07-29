app_name = "omc_app"
app_title = "OMC App"
app_publisher = "M.Shahwaiz.Ali"
app_description = "OMC mobile backend app for ERPNext/Frappe"
app_email = "alishahwaiz96@gmail.com"
app_license = "mit"

# Install the canonical OMC role model and supported Website Settings branding.
after_install = "omc_app.setup.lifecycle.after_install"
after_migrate = "omc_app.setup.lifecycle.after_migrate"

# Secure mobile API method overrides
# ----------------------------------
# Keep customer-facing endpoints stable while enforcing server-side guards,
# backend-owned tracking data, and the canonical OMC role model.
override_whitelisted_methods = {
    "omc_app.api.mobile.sign_up": "omc_app.api.signup_policy.sign_up",
    "omc_app.api.access.sign_up": "omc_app.api.signup_policy.sign_up",
    "omc_app.api.mobile.get_mobile_capabilities": "omc_app.api.access.get_mobile_capabilities",
    "omc_app.api.mobile.get_session_user": "omc_app.api.access.get_session_user",
    "omc_app.api.mobile.get_mobile_app_config": "omc_app.api.branding_config.get_mobile_app_config",
    "omc_app.api.mobile.get_service_catalogue": "omc_app.api.public_catalogue.get_service_catalogue",
    "omc_app.api.mobile.get_service_detail": "omc_app.api.public_catalogue.get_service_detail",
    "omc_app.api.mobile.update_profile": "omc_app.api.profile_guard.update_profile",
    "omc_app.api.mobile.update_contact_info": "omc_app.api.profile_guard.update_contact_info",
    "omc_app.api.mobile.create_service": "omc_app.api.service_request_guard.create_service",
    "omc_app.api.mobile.get_service_cases": "omc_app.api.secured_mobile.get_service_cases",
    "omc_app.api.mobile.get_service_case": "omc_app.api.secured_mobile.get_service_case",
    "omc_app.api.mobile.update_service_case_status": "omc_app.api.secured_mobile.update_service_case_status",
    "omc_app.api.mobile.update_service_document_status": "omc_app.api.service_document_guard.update_service_document_status",
    "omc_app.api.customer_documents.get_document": "omc_app.api.service_document_guard.get_document",
    "omc_app.api.customer_documents.update_service_document_status": "omc_app.api.service_document_guard.update_service_document_status",
    "omc_app.api.mobile.get_support_tickets": "omc_app.api.support_ticket_read_guard.get_support_tickets",
    "omc_app.api.mobile.get_support_ticket": "omc_app.api.support_ticket_read_guard.get_support_ticket",
    "omc_app.api.support_chat.get_support_tickets": "omc_app.api.support_ticket_read_guard.get_support_tickets",
    "omc_app.api.support_chat.get_support_ticket": "omc_app.api.support_ticket_read_guard.get_support_ticket",
    "omc_app.api.support_chat.get_active_support_ticket": "omc_app.api.support_ticket_read_guard.get_active_support_ticket",
    "omc_app.api.support_chat.get_support_unread_count": "omc_app.api.support_ticket_read_state_guard.get_support_unread_count",
    "omc_app.api.support_chat.mark_support_ticket_read": "omc_app.api.support_ticket_read_state_guard.mark_support_ticket_read",
    "omc_app.api.mobile.update_support_ticket_status": "omc_app.api.support_ticket_guard.update_support_ticket_status",
    "omc_app.api.support_chat.update_support_ticket_status": "omc_app.api.support_ticket_guard.update_support_ticket_status",
    "omc_app.api.support_chat.assign_support_ticket": "omc_app.api.support_ticket_guard.assign_support_ticket",
    "omc_app.api.mobile.get_tasks": "omc_app.api.task_read_guard.get_tasks",
    "omc_app.api.mobile.get_task": "omc_app.api.task_read_guard.get_task",
    "omc_app.api.referrals.validate_referral_code": "omc_app.referral_automation.validate_referral_code",
    "omc_app.api.referrals.get_my_referral_summary": "omc_app.api.referral_analytics.get_my_referral_summary",
    "omc_app.api.referrals.get_my_referrals": "omc_app.api.referral_analytics.get_my_referrals",
    "omc_app.api.assisted_service.get_customer_selection_options": "omc_app.api.assisted_service_policy.get_customer_selection_options",
    "omc_app.api.assisted_service.create_request": "omc_app.api.assisted_service_policy.create_request",
    "omc_app.api.internal_workspace.create_service_request_for_customer": "omc_app.api.assisted_service_policy.create_service_request_for_customer",
    "omc_app.api.tax_calculator.calculate_tax": "omc_app.api.tax_calculator_guard.calculate_tax",
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


# Frappe Desk record scoping for canonical OMC roles.
permission_query_conditions = {
    "OMC Service Request": "omc_app.permissions.service_request_query",
    "OMC Customer Profile": "omc_app.permissions.customer_profile_query",
    "OMC Referral": "omc_app.permissions.referral_query",
    "OMC Task": "omc_app.permissions.task_query",
    "OMC Service Document": "omc_app.permissions.service_document_query",
    "OMC Service Payment": "omc_app.permissions.service_payment_query",
    "OMC Support Ticket": "omc_app.permissions.support_ticket_query",
    "OMC Lead": "omc_app.permissions.lead_query",
}

has_permission = {
    "OMC Service Request": "omc_app.permissions.service_request_has_permission",
    "OMC Customer Profile": "omc_app.permissions.customer_profile_has_permission",
    "OMC Referral": "omc_app.permissions.referral_has_permission",
    "OMC Task": "omc_app.permissions.task_has_permission",
    "OMC Service Document": "omc_app.permissions.service_document_has_permission",
    "OMC Service Payment": "omc_app.permissions.service_payment_has_permission",
    "OMC Support Ticket": "omc_app.permissions.support_ticket_has_permission",
    "OMC Lead": "omc_app.permissions.lead_has_permission",
}


# Validate task assignment and keep eligible internal referral codes in sync.
doc_events = {
    "User": {
        "after_insert": "omc_app.referral_automation.sync_user_referral_code",
        "on_update": "omc_app.referral_automation.sync_user_referral_code",
    },
    "OMC Task": {
        "validate": "omc_app.permissions.validate_task_assignment",
    },
}


# Workflow automation reminders, cleanup, and failure-isolated maintenance.
scheduler_events = {
    "hourly": [
        "omc_app.api.scheduler_jobs.run_hourly_jobs",
    ],
    "daily": [
        "omc_app.api.scheduler_jobs.run_daily_jobs",
    ],
}


# Frappe Desk assets and exported workspace.
fixtures = [
    {
        "doctype": "Workspace",
        "filters": [["name", "in", ["OMC App"]]],
    }
]

app_include_css = "/assets/omc_app/css/omc_desk.css"
