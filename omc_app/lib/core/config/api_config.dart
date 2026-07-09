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

    return cleanUrl;
  }

  static String get _defaultBaseUrlForEnvironment {
    switch (Env.current) {
      case AppEnvironment.development:
        return 'http://127.0.0.1:8000';
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
  static const String logoutMethod = 'logout';
  static const String googleLoginMethod =
      'omc_app.api.mobile.google_mobile_login';
  static const String signUpMethod = 'omc_app.api.mobile.sign_up';
  static const String getSessionUserMethod =
      'omc_app.api.mobile.get_session_user';
  static const String createGuestSessionMethod =
      'omc_app.api.guest_session.create_guest_session';
  static const String updateGuestActivityMethod =
      'omc_app.api.guest_session.update_guest_activity';

  static const String createServiceMethod = 'omc_app.api.mobile.create_service';
  static const String createLeadMethod = 'omc_app.api.mobile.create_lead';
  static const String dashboardDataMethod =
      'omc_app.api.mobile.get_dashboard_data';

  static const String mobileQuickActionsMethod =
      'omc_app.api.quick_actions.get_mobile_quick_actions';

  static const String taxCalculatorConfigMethod =
      'omc_app.api.tax_calculator.get_tax_calculator_config';
  static const String taxCalculatorMethod =
      'omc_app.api.tax_calculator.calculate_tax';
  static const String taxCalculationHistoryMethod =
      'omc_app.api.tax_calculator.get_tax_calculation_history';
  static const String downloadTaxEstimatePdfMethod =
      'omc_app.api.tax_calculator.download_tax_estimate_pdf';
  static const String shareTaxEstimateWithConsultantMethod =
      'omc_app.api.tax_calculator.share_tax_estimate_with_consultant';
  static const String startTaxServiceFromCalculationMethod =
      'omc_app.api.tax_calculator.start_service_from_calculation';

  static const String serviceCatalogueMethod =
      'omc_app.api.mobile.get_service_catalogue';
  static const String serviceTemplateMethod =
      'omc_app.api.service_templates.get_service_template';

  static const String serviceCasesMethod =
      'omc_app.api.secured_mobile.get_service_cases';
  static const String serviceCaseDetailMethod =
      'omc_app.api.secured_mobile.get_service_case';
  static const String updateServiceCaseStatusMethod =
      'omc_app.api.secured_mobile.update_service_case_status';
  static const String cancelServiceRequestMethod =
      'omc_app.api.secured_mobile.cancel_service_request';

  static const String documentsMethod = 'omc_app.api.mobile.get_documents';
  static const String documentDetailMethod = 'omc_app.api.mobile.get_document';
  static const String uploadServiceDocumentMethod =
      'omc_app.api.document_upload.upload_service_document';
  static const String updateServiceDocumentStatusMethod =
      'omc_app.api.secured_mobile.update_service_document_status';

  static const String paymentsMethod = 'omc_app.api.payments.get_payments';
  static const String paymentDetailMethod = 'omc_app.api.payments.get_payment';
  static const String uploadPaymentReceiptMethod =
      'omc_app.api.mobile.upload_payment_receipt';
  static const String uploadPaymentReceiptFileMethod =
      'omc_app.api.payments.upload_payment_receipt_file';
  static const String reviewPaymentReceiptMethod =
      'omc_app.api.mobile.review_payment_receipt';

  static const String profileMethod = 'omc_app.api.mobile.get_profile';
  static const String updateProfileMethod = 'omc_app.api.mobile.update_profile';
  static const String updateContactMethod =
      'omc_app.api.mobile.update_contact_info';

  static const String knowledgeMethod = 'omc_app.api.mobile.get_knowledge';
  static const String knowledgeDetailMethod =
      'omc_app.api.mobile.get_knowledge_article';
  static const String appBannersMethod = 'omc_app.api.mobile.get_app_banners';
  static const String faqsMethod = 'omc_app.api.mobile.get_faqs';

  static const String notificationsMethod =
      'omc_app.api.mobile.get_notifications';

  static const String notificationDetailMethod =
      'omc_app.api.mobile.get_notification_detail';

  static const String markNotificationReadMethod =
      'omc_app.api.mobile.mark_notification_read';

  static const String markAllNotificationsReadMethod =
      'omc_app.api.mobile.mark_all_notifications_read';

  static const String registerPushTokenMethod =
      'omc_app.api.mobile.register_push_token';

  static const String unregisterPushTokenMethod =
      'omc_app.api.mobile.unregister_push_token';

  static const String settingsPreferencesMethod =
      'omc_app.api.mobile.get_settings_preferences';
  static const String updateSettingsPreferencesMethod =
      'omc_app.api.mobile.update_settings_preferences';

  static const String createSupportTicketMethod =
      'omc_app.api.support_chat.create_support_ticket';
  static const String supportTicketsMethod =
      'omc_app.api.support_chat.get_support_tickets';
  static const String supportTicketDetailMethod =
      'omc_app.api.support_chat.get_support_ticket';
  static const String addSupportTicketReplyMethod =
      'omc_app.api.support_chat.add_support_ticket_reply';
  static const String updateSupportTicketStatusMethod =
      'omc_app.api.support_chat.update_support_ticket_status';
  static const String uploadSupportTicketAttachmentMethod =
      'omc_app.api.support_chat.upload_support_ticket_attachment';
  static const String supportConfigMethod =
      'omc_app.api.mobile.get_support_config';
  static const String mobileAppConfigMethod =
      'omc_app.api.mobile.get_mobile_app_config';

  static const String expenseCategoriesMethod =
      'omc_app.api.expense.get_expense_categories';
  static const String expenseEntriesMethod =
      'omc_app.api.expense.get_expense_entries';
  static const String createExpenseEntryMethod =
      'omc_app.api.expense.create_expense_entry';
  static const String updateExpenseEntryMethod =
      'omc_app.api.expense.update_expense_entry';
  static const String deleteExpenseEntryMethod =
      'omc_app.api.expense.delete_expense_entry';
  static const String expenseSummaryMethod =
      'omc_app.api.expense.get_expense_summary';

  static const String internalWorkspaceSummaryMethod =
      'omc_app.api.mobile.get_internal_workspace_summary';
  static const String internalServiceCasesMethod =
      'omc_app.api.internal_workspace.get_service_cases';
  static const String createServiceRequestForCustomerMethod =
      'omc_app.api.internal_workspace.create_service_request_for_customer';

  static const String leadsMethod = 'omc_app.api.mobile.get_leads';
  static const String leadDetailMethod = 'omc_app.api.mobile.get_lead';

  static const String customersMethod = 'omc_app.api.mobile.get_customers';
  static const String customerDetailMethod = 'omc_app.api.mobile.get_customer';

  static const String tasksMethod = 'omc_app.api.mobile.get_tasks';
  static const String taskDetailMethod = 'omc_app.api.mobile.get_task';

  static const String serviceRequestUploadDoctype = 'OMC Service Request';

  static const String documentUploadDoctype = 'OMC Service Document';

  static const String paymentUploadDoctype = 'OMC Service Payment';

  static const String supportTicketUploadDoctype = 'OMC Support Ticket';

  static const String uploadFileMethod = 'upload_file';

  static String _withoutTrailingSlash(String value) {
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }
}
