app_name = "omc_app"
app_title = "OMC App"
app_publisher = "M.Shahwaiz.Ali"
app_description = "OMC mobile backend app for ERPNext/Frappe"
app_email = "alishahwaiz96@gmail.com"
app_license = "mit"

# Install the canonical OMC role and permission model on new sites.
after_install = "omc_app.setup.roles.after_install"
after_migrate = "omc_app.setup.roles.after_migrate"

# Secure mobile API method overrides
# ----------------------------------
# Keep customer-facing endpoints stable while enforcing server-side guards,
# backend-owned tracking data, and the canonical OMC role model.
override_whitelisted_methods = {
    "omc_app.api.mobile.sign_up": "omc_app.api.access.sign_up",
    "omc_app.api.mobile.get_mobile_capabilities": "omc_app.api.access.get_mobile_capabilities",
    "omc_app.api.mobile.get_session_user": "omc_app.api.access.get_session_user",
    "omc_app.api.mobile.get_mobile_app_config": "omc_app.api.branding_config.get_mobile_app_config",
    "omc_app.api.mobile.get_service_cases": "omc_app.api.secured_mobile.get_service_cases",
    "omc_app.api.mobile.get_service_case": "omc_app.api.secured_mobile.get_service_case",
    "omc_app.api.mobile.update_service_case_status": "omc_app.api.secured_mobile.update_service_case_status",
    "omc_app.api.mobile.update_service_document_status": "omc_app.api.secured_mobile.update_service_document_status",
}


# Frappe Desk record scoping for canonical OMC roles.
permission_query_conditions = {
    "OMC Service Request": "omc_app.permissions.service_request_query",
    "OMC Customer Profile": "omc_app.permissions.customer_profile_query",
    "OMC Task": "omc_app.permissions.task_query",
    "OMC Service Document": "omc_app.permissions.service_document_query",
    "OMC Service Payment": "omc_app.permissions.service_payment_query",
    "OMC Support Ticket": "omc_app.permissions.support_ticket_query",
    "OMC Lead": "omc_app.permissions.lead_query",
}

has_permission = {
    "OMC Service Request": "omc_app.permissions.service_request_has_permission",
    "OMC Customer Profile": "omc_app.permissions.customer_profile_has_permission",
    "OMC Task": "omc_app.permissions.task_has_permission",
    "OMC Service Document": "omc_app.permissions.service_document_has_permission",
    "OMC Service Payment": "omc_app.permissions.service_payment_has_permission",
    "OMC Support Ticket": "omc_app.permissions.support_ticket_has_permission",
    "OMC Lead": "omc_app.permissions.lead_has_permission",
}
