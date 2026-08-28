import 'package:flutter/foundation.dart';

import 'env.dart';

class ApiConfig {
  const ApiConfig._();

  static const String productionOrigin = 'https://erp.omchouse.com';

  static const String _definedBaseUrl = String.fromEnvironment(
    'OMC_API_BASE_URL',
    defaultValue: '',
  );

  static const String _definedLinkBaseUrl = String.fromEnvironment(
    'OMC_LINK_BASE_URL',
    defaultValue: '',
  );

  static const String sentryDsn = String.fromEnvironment(
    'OMC_SENTRY_DSN',
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

    _validateUrl(uri, label: 'OMC_API_BASE_URL');
    return cleanUrl;
  }

  static String get currentBaseUrl => baseUrl;

  static String get linkBaseUrl {
    final resolvedUrl = _definedLinkBaseUrl.trim().isNotEmpty
        ? _definedLinkBaseUrl
        : productionOrigin;
    final cleanUrl = _withoutTrailingSlash(resolvedUrl);
    final uri = Uri.tryParse(cleanUrl);
    if (uri == null) {
      throw StateError('Invalid OMC_LINK_BASE_URL.');
    }
    _validateUrl(uri, label: 'OMC_LINK_BASE_URL');
    return cleanUrl;
  }

  static void validateBuildProfile() {
    validateResolvedBuildProfile(
      isRelease: kReleaseMode,
      environment: Env.current,
      apiBaseUrl: baseUrl,
      linkBaseUrl: linkBaseUrl,
      diagnosticsDsn: sentryDsn,
    );
  }

  @visibleForTesting
  static void validateResolvedBuildProfile({
    required bool isRelease,
    required AppEnvironment environment,
    required String apiBaseUrl,
    required String linkBaseUrl,
    String diagnosticsDsn = '',
  }) {
    if (!isRelease) return;

    final apiUri = Uri.parse(_withoutTrailingSlash(apiBaseUrl));
    final linkUri = Uri.parse(_withoutTrailingSlash(linkBaseUrl));
    final productionUri = Uri.parse(productionOrigin);

    if (environment != AppEnvironment.production ||
        apiUri.scheme != 'https' ||
        apiUri.host.toLowerCase() != productionUri.host ||
        apiUri.hasPort ||
        (apiUri.path.isNotEmpty && apiUri.path != '/') ||
        linkUri.scheme != 'https' ||
        linkUri.host.toLowerCase() != productionUri.host ||
        linkUri.hasPort ||
        diagnosticsDsn.trim().isEmpty ||
        Uri.tryParse(diagnosticsDsn)?.scheme != 'https') {
      throw StateError(
        'Release builds must use the production environment and '
        '$productionOrigin for API and app links, plus a valid HTTPS '
        'OMC_SENTRY_DSN.',
      );
    }
  }

  static String? resolveFileUrl(String? value) {
    final cleanValue = value?.trim();
    if (cleanValue == null || cleanValue.isEmpty) return null;

    final absolute =
        cleanValue.startsWith('http://') || cleanValue.startsWith('https://')
        ? cleanValue
        : cleanValue.startsWith('/')
        ? '$baseUrl$cleanValue'
        : '$baseUrl/$cleanValue';

    return Uri.parse(absolute).toString();
  }

  static String get _defaultBaseUrlForEnvironment {
    switch (Env.current) {
      case AppEnvironment.development:
        return 'http://127.0.0.1:8000';
      case AppEnvironment.production:
        return productionOrigin;
    }
  }

  static void _validateUrl(Uri uri, {required String label}) {
    if (!uri.hasScheme || uri.host.trim().isEmpty) {
      throw StateError(
        'Invalid $label. Provide a full URL such as $productionOrigin',
      );
    }
    if (uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw StateError(
        '$label must not contain credentials, query, or fragment.',
      );
    }
  }

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 25);
  static const Duration sendTimeout = Duration(seconds: 25);

  static const String apiMethodPath = '/api/method';
  static const String apiResourcePath = '/api/resource';

  static const String loginMethod = 'login';
  static const String multiIdentifierLoginMethod =
      'omc_app.api.auth_login.login';
  static const String requestPasswordResetMethod =
      'omc_app.api.password_reset.request_reset';
  static const String resetPasswordMethod =
      'omc_app.api.password_reset.reset_password';
  static const String requestCustomerActivationMethod =
      'omc_app.api.customer_activation.request_activation';
  static const String completeCustomerActivationMethod =
      'omc_app.api.customer_activation.complete_activation';
  static const String changePasswordMethod =
      'omc_app.api.account_security.change_password';
  static const String verifyCurrentPasswordMethod =
      'omc_app.api.account_security.verify_current_password';

  static const String logoutMethod = 'logout';
  static const String googleLoginMethod =
      'omc_app.api.mobile.google_mobile_login';
  static const String startRegistrationMethod =
      'omc_app.api.pending_registration.start_registration';
  static const String resendVerificationMethod =
      'omc_app.api.pending_registration.resend_verification';
  static const String verifyRegistrationMethod =
      'omc_app.api.pending_registration.verify_registration';
  static const String suggestUsernameMethod =
      'omc_app.api.access.suggest_username';
  static const String checkUsernameAvailabilityMethod =
      'omc_app.api.access.check_username_availability';
  static const String validateReferralCodeMethod =
      'omc_app.api.referrals.validate_referral_code';
  static const String getSessionUserMethod =
      'omc_app.api.access_v2.get_session_user';
  static const String createGuestSessionMethod =
      'omc_app.api.guest_session.create_guest_session';
  static const String updateGuestActivityMethod =
      'omc_app.api.guest_session.update_guest_activity';

  static const String createServiceMethod =
      'omc_app.api.service_requests.create_service';
  static const String assistedCustomerSelectionMethod =
      'omc_app.api.assisted_service.get_customer_selection_options';
  static const String createLeadMethod = 'omc_app.api.mobile.create_lead';
  static const String dashboardDataMethod =
      'omc_app.api.dashboard.get_dashboard_data';

  static const String mobileQuickActionsMethod =
      'omc_app.api.quick_actions.get_mobile_quick_actions';

  static const String taxCalculatorConfigMethod =
      'omc_app.api.tax_calculator.get_tax_calculator_config';
  static const String taxCalculatorMethod =
      'omc_app.api.tax_calculator.calculate_tax';
  static const String taxCalculationHistoryMethod =
      'omc_app.api.tax_calculator.get_tax_calculation_history';
  static const String downloadTaxEstimatePdfMethod =
      'omc_app.api.tax_calculator_mutations.download_tax_estimate_pdf';
  static const String shareTaxEstimateWithConsultantMethod =
      'omc_app.api.tax_calculator_mutations.share_tax_estimate_with_consultant';
  static const String startTaxServiceFromCalculationMethod =
      'omc_app.api.tax_calculator_mutations.start_service_from_calculation';

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

  static const String documentsMethod =
      'omc_app.api.customer_documents.get_documents';
  static const String documentDetailMethod =
      'omc_app.api.customer_documents.get_document';
  static const String uploadServiceDocumentMethod =
      'omc_app.api.document_upload.upload_service_document';
  static const String updateServiceDocumentStatusMethod =
      'omc_app.api.customer_documents.update_service_document_status';

  static const String paymentsMethod = 'omc_app.api.payments.get_payments';
  static const String paymentDetailMethod = 'omc_app.api.payments.get_payment';
  static const String downloadPaymentInvoiceMethod =
      'omc_app.api.payment_read_guard.download_invoice_pdf';
  static const String uploadPaymentReceiptMethod =
      'omc_app.api.mobile.upload_payment_receipt';
  static const String uploadPaymentReceiptFileMethod =
      'omc_app.api.payments.upload_payment_receipt_file';
  static const String uploadPaymentReceiptMultipartMethod =
      'omc_app.api.payments.upload_payment_receipt_multipart';
  static const String reviewPaymentReceiptMethod =
      'omc_app.api.payments.review_payment_receipt';

  static const String profileMethod = 'omc_app.api.access_v2.get_profile';
  static const String updateProfileMethod =
      'omc_app.api.profile_self_service.update_profile';
  static const String updateWorkAddressMethod =
      'omc_app.api.profile_self_service.update_work_address';
  static const String dismissWorkAddressPromptMethod =
      'omc_app.api.profile_self_service.dismiss_work_address_prompt';
  static const String updateContactMethod =
      'omc_app.api.mobile.update_contact_info';
  static const String uploadProfileImageMethod =
      'omc_app.api.profile.upload_profile_image';

  static const String knowledgeMethod = 'omc_app.api.mobile.get_knowledge';
  static const String knowledgeDetailMethod =
      'omc_app.api.mobile.get_knowledge_article';
  static const String appBannersMethod = 'omc_app.api.mobile.get_app_banners';
  static const String onboardingSlidesMethod =
      'omc_app.api.mobile.get_onboarding_slides';
  static const String faqsMethod = 'omc_app.api.mobile.get_faqs';

  static const String notificationsMethod =
      'omc_app.api.notifications.get_notifications';
  static const String unreadNotificationCountMethod =
      'omc_app.api.notifications.get_unread_notification_count';
  static const String markNotificationReadMethod =
      'omc_app.api.notifications.mark_notification_read';
  static const String notificationPreferencesMethod =
      'omc_app.api.notification_preferences.get_preferences';
  static const String updateNotificationPreferencesMethod =
      'omc_app.api.notification_preferences.update_preferences';
  static const String registerPushTokenMethod =
      'omc_app.api.push_notifications.register_token';
  static const String unregisterPushTokenMethod =
      'omc_app.api.push_notifications.unregister_token';

  static const String supportTicketsMethod =
      'omc_app.api.support.get_support_tickets';
  static const String supportTicketDetailMethod =
      'omc_app.api.support.get_support_ticket';
  static const String createSupportTicketMethod =
      'omc_app.api.support.create_support_ticket';
  static const String addSupportMessageMethod =
      'omc_app.api.support.add_support_message';

  static const String expenseCategoriesMethod =
      'omc_app.api.expense.get_expense_categories';
  static const String expenseEntriesMethod =
      'omc_app.api.expense.get_expense_entries';
  static const String saveExpenseEntryMethod =
      'omc_app.api.expense.save_expense_entry';
  static const String deleteExpenseEntryMethod =
      'omc_app.api.expense.delete_expense_entry';
  static const String expenseSummaryMethod =
      'omc_app.api.expense.get_expense_summary';
  static const String expenseBudgetMethod =
      'omc_app.api.expense.get_budget';
  static const String saveExpenseBudgetMethod =
      'omc_app.api.expense.save_budget';

  static const String deviceLockStatusMethod =
      'omc_app.api.account_security.get_device_lock_status';
  static const String updateDeviceLockStatusMethod =
      'omc_app.api.account_security.update_device_lock_status';

  static String methodUrl(String method) => '$apiMethodPath/$method';

  static String _withoutTrailingSlash(String value) {
    var cleaned = value.trim();
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }
}
