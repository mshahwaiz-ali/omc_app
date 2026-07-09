app_name = "omc_app"
app_title = "OMC App"
app_publisher = "M.Shahwaiz.Ali"
app_description = "OMC mobile backend app for ERPNext/Frappe"
app_email = "alishahwaiz96@gmail.com"
app_license = "mit"

# Secure mobile API method overrides
# ----------------------------------
# Keep customer-facing endpoints stable while enforcing server-side guards,
# backend-owned tracking data, and the canonical OMC role model.
override_whitelisted_methods = {
    "omc_app.api.mobile.sign_up": "omc_app.api.access.sign_up",
    "omc_app.api.mobile.get_mobile_capabilities": "omc_app.api.access.get_mobile_capabilities",
    "omc_app.api.mobile.get_session_user": "omc_app.api.access.get_session_user",
    "omc_app.api.mobile.get_service_cases": "omc_app.api.secured_mobile.get_service_cases",
    "omc_app.api.mobile.get_service_case": "omc_app.api.secured_mobile.get_service_case",
    "omc_app.api.mobile.update_service_case_status": "omc_app.api.secured_mobile.update_service_case_status",
    "omc_app.api.mobile.update_service_document_status": "omc_app.api.secured_mobile.update_service_document_status",
}
