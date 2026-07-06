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

  static const String loginMethod = 'login';
  static const String googleLoginMethod =
      'omc_app.api.mobile.google_mobile_login';
  static const String signUpMethod = 'omc_app.api.mobile.sign_up';
  static const String getSessionUserMethod =
      'omc_app.api.mobile.get_session_user';
  static const String createServiceMethod =
      'omc_app.api.mobile.create_service';
  static const String createLeadMethod = 'omc_app.api.mobile.create_lead';
  static const String dashboardDataMethod =
      'omc_app.api.mobile.get_dashboard_data';

  static const String taxCalculatorMethod = 'omc_app.api.mobile.calculate_tax';

  static const String serviceCatalogueMethod =
      'omc_app.api.mobile.get_service_catalogue';

  static const String serviceCasesMethod =
      'omc_app.api.mobile.get_service_cases';
  static const String serviceCaseDetailMethod =
      'omc_app.api.mobile.get_service_case';

  static const String documentsMethod = 'omc_app.api.mobile.get_documents';
  static const String documentDetailMethod = 'omc_app.api.mobile.get_document';
  static const String uploadServiceDocumentMethod =
      'omc_app.api.mobile.upload_service_document';
  static const String updateServiceDocumentStatusMethod =
      'omc_app.api.mobile.update_service_document_status';

  static const String paymentsMethod = 'omc_app.api.mobile.get_payments';
  static const String paymentDetailMethod = 'omc_app.api.mobile.get_payment';
  static const String uploadPaymentReceiptMethod =
      'omc_app.api.mobile.upload_payment_receipt';

  static const String profileMethod = 'omc_app.api.mobile.get_profile';
  static const String updateProfileMethod = 'omc_app.api.mobile.update_profile';
  static const String updateContactMethod =
      'omc_app.api.mobile.update_contact_info';

  static const String knowledgeMethod = 'omc_app.api.mobile.get_knowledge';
  static const String knowledgeDetailMethod =
      'omc_app.api.mobile.get_knowledge_article';

  static const String notificationsMethod =
      'omc_app.api.mobile.get_notifications';

  static const String notificationDetailMethod =
      'omc_app.api.mobile.get_notification_detail';

  static const String markNotificationReadMethod =
      'omc_app.api.mobile.mark_notification_read';

  static const String settingsPreferencesMethod =
      'omc_app.api.mobile.get_settings_preferences';
  static const String updateSettingsPreferencesMethod =
      'omc_app.api.mobile.update_settings_preferences';

  static const String createSupportTicketMethod =
      'omc_app.api.mobile.create_support_ticket';
  static const String supportTicketsMethod =
      'omc_app.api.mobile.get_support_tickets';
  static const String supportTicketDetailMethod =
      'omc_app.api.mobile.get_support_ticket';

  static const String internalWorkspaceSummaryMethod =
      'omc_app.api.mobile.get_internal_workspace_summary';

  static const String leadsMethod = 'omc_app.api.mobile.get_leads';
  static const String leadDetailMethod = 'omc_app.api.mobile.get_lead';

  static const String customersMethod = 'omc_app.api.mobile.get_customers';
  static const String customerDetailMethod = 'omc_app.api.mobile.get_customer';

  static const String tasksMethod = 'omc_app.api.mobile.get_tasks';
  static const String taskDetailMethod = 'omc_app.api.mobile.get_task';

  static const String serviceRequestUploadDoctype = 'OMC Service Request';

  static const String documentUploadDoctype = 'OMC Service Document';

  static const String paymentUploadDoctype = 'OMC Service Payment';

  static const String uploadFileMethod = 'upload_file';

  static String _withoutTrailingSlash(String value) {
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }
}
