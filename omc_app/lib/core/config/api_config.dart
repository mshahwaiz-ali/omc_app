import 'env.dart';

class ApiConfig {
  const ApiConfig._();

  static const String _definedBaseUrl = String.fromEnvironment(
    'OMC_API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    final resolvedUrl = _definedBaseUrl.trim().isNotEmpty
        ? _definedBaseUrl
        : _defaultBaseUrlForEnvironment;

    final cleanUrl = _withoutTrailingSlash(resolvedUrl);
    final uri = Uri.tryParse(cleanUrl);

    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      throw StateError(
        'Invalid OMC_API_BASE_URL. Provide a full URL such as https://erp.omchouse.com',
      );
    }

    if (Env.isProduction && uri.scheme != 'https') {
      throw StateError('Production OMC_API_BASE_URL must use HTTPS.');
    }

    return cleanUrl;
  }

  static String get _defaultBaseUrlForEnvironment {
    switch (Env.current) {
      case AppEnvironment.development:
        return 'https://erp.omchouse.com';
      case AppEnvironment.staging:
        return 'https://erp.omchouse.com';
      case AppEnvironment.production:
        return 'https://erp.omchouse.com';
    }
  }

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 25);
  static const Duration sendTimeout = Duration(seconds: 25);

  static const String apiMethodPath = '/api/method';
  static const String apiResourcePath = '/api/resource';

  static const String loginMethod = 'lead_app.lead_app.apis.login';
  static const String googleLoginMethod =
      'lead_app.lead_app.apis.google_mobile_login';
  static const String signUpMethod = 'lead_app.lead_app.apis.sign_up';
  static const String createServiceMethod =
      'lead_app.lead_app.apis.create_service';
  static const String createLeadMethod = 'lead_app.lead_app.apis.create_lead';
  static const String dashboardDataMethod =
      'lead_app.lead_app.apis.get_dashboard_data';

  // TODO(backend): Replace with confirmed OMC/Frappe tax calculator API.
  static const String taxCalculatorMethod = 'omc_app.api.mobile.calculate_tax';

  // TODO(backend): Replace with confirmed OMC/Frappe service catalogue API.
  static const String serviceCatalogueMethod =
      'omc_app.api.mobile.get_service_catalogue';

  // TODO(backend): Replace these with confirmed OMC/Frappe tracking APIs.
  // Keep centralized so My Services can be wired without hardcoded
  // placeholder method names inside feature repositories.
  static const String serviceCasesMethod =
      'omc_app.api.mobile.get_service_cases';
  static const String serviceCaseDetailMethod =
      'omc_app.api.mobile.get_service_case';

  // TODO(backend): Replace with confirmed OMC/Frappe documents API.
  static const String documentsMethod = 'omc_app.api.mobile.get_documents';
  static const String documentDetailMethod = 'omc_app.api.mobile.get_document';

  // TODO(backend): Replace with confirmed OMC/Frappe payments API.
  static const String paymentsMethod = 'omc_app.api.mobile.get_payments';
  static const String paymentDetailMethod = 'omc_app.api.mobile.get_payment';

  // TODO(backend): Replace with confirmed OMC/Frappe profile API.
  static const String profileMethod = 'omc_app.api.mobile.get_profile';
  static const String updateProfileMethod = 'omc_app.api.mobile.update_profile';
  static const String updateContactMethod =
      'omc_app.api.mobile.update_contact_info';

  // TODO(backend): Replace with confirmed OMC/Frappe knowledge/news API.
  static const String knowledgeMethod = 'omc_app.api.mobile.get_knowledge';
  static const String knowledgeDetailMethod =
      'omc_app.api.mobile.get_knowledge_article';

  // TODO(backend): Replace with confirmed OMC/Frappe notifications API.
  static const String notificationsMethod =
      'omc_app.api.mobile.get_notifications';

  // TODO(backend): Replace with confirmed OMC/Frappe notification detail API.
  static const String notificationDetailMethod =
      'omc_app.api.mobile.get_notification_detail';

  // TODO(backend): Replace with confirmed OMC/Frappe notification mark-read API.
  static const String markNotificationReadMethod =
      'omc_app.api.mobile.mark_notification_read';

  // TODO(backend): Replace with confirmed OMC/Frappe settings preferences API.
  static const String settingsPreferencesMethod =
      'omc_app.api.mobile.get_settings_preferences';
  static const String updateSettingsPreferencesMethod =
      'omc_app.api.mobile.update_settings_preferences';

  // TODO(backend): Replace with confirmed OMC/Frappe support ticket API.
  static const String createSupportTicketMethod =
      'omc_app.api.mobile.create_support_ticket';

  // TODO(backend): Replace with confirmed OMC/Frappe internal workspace API.
  static const String internalWorkspaceSummaryMethod =
      'omc_app.api.mobile.get_internal_workspace_summary';

  // TODO(backend): Replace with confirmed OMC/Frappe CRM APIs.
  static const String leadsMethod = 'omc_app.api.mobile.get_leads';
  static const String leadDetailMethod = 'omc_app.api.mobile.get_lead';

  static const String customersMethod = 'omc_app.api.mobile.get_customers';
  static const String customerDetailMethod = 'omc_app.api.mobile.get_customer';

  static const String tasksMethod = 'omc_app.api.mobile.get_tasks';
  static const String taskDetailMethod = 'omc_app.api.mobile.get_task';

  static const String serviceRequestUploadDoctype = 'Service Request';

  // TODO(backend): Replace with confirmed OMC/Frappe document doctype.
  static const String documentUploadDoctype = 'OMC Document';

  // TODO(backend): Replace with confirmed OMC/Frappe payment doctype.
  static const String paymentUploadDoctype = 'Sales Invoice';

  static const String uploadFileMethod = 'upload_file';

  static String _withoutTrailingSlash(String value) {
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }
}
