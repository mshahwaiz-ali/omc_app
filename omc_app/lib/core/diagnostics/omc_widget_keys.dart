import 'package:flutter/widgets.dart';

abstract final class OmcWidgetKeys {
  static const splashScreen = ValueKey<String>('screen.splash');
  static const startupError = ValueKey<String>('error.startup');
  static const onboardingScreen = ValueKey<String>('screen.onboarding');
  static const onboardingSkip = ValueKey<String>('auth.onboarding.skip');

  static const loginScreen = ValueKey<String>('screen.login');
  static const loginIdentifier = ValueKey<String>('auth.login.identifier');
  static const loginPassword = ValueKey<String>('auth.login.password');
  static const loginSubmit = ValueKey<String>('auth.login.submit');
  static const loginError = ValueKey<String>('auth.login.error');
  static const underReviewScreen = ValueKey<String>('screen.under_review');
  static const underReviewLogout = ValueKey<String>('auth.under_review.logout');
  static const deviceLockScreen = ValueKey<String>('screen.device_lock');
  static const deviceLockUseAnotherAccount = ValueKey<String>(
    'auth.device_lock.use_another_account',
  );

  static const navHome = ValueKey<String>('nav.home');
  static const navServices = ValueKey<String>('nav.services');
  static const navTrack = ValueKey<String>('nav.track');
  static const navMore = ValueKey<String>('nav.more');

  static const homeScreen = ValueKey<String>('screen.home');
  static const servicesScreen = ValueKey<String>('screen.services');
  static const serviceSearch = ValueKey<String>('service.catalogue.search');
  static const serviceDetailScreen = ValueKey<String>('screen.service_detail');
  static const serviceStartRequest = ValueKey<String>('service.detail.start_request');

  static const requestDraftScreen = ValueKey<String>('screen.request_draft');
  static const requestContactName = ValueKey<String>('request.contact.name');
  static const requestContactPhone = ValueKey<String>('request.contact.phone');
  static const requestContactEmail = ValueKey<String>('request.contact.email');
  static const requestContactTaxId = ValueKey<String>('request.contact.tax_id');
  static const requestRemarks = ValueKey<String>('request.remarks');
  static const requestSubmit = ValueKey<String>('request.submit');

  static const trackScreen = ValueKey<String>('screen.track');
  static const customerCaseDetailScreen = ValueKey<String>(
    'screen.customer_case_detail',
  );
  static const customerCaseRefresh = ValueKey<String>('case.refresh');
  static const customerCasePayment = ValueKey<String>('case.payment.open');

  static const documentsScreen = ValueKey<String>('screen.documents');
  static const moreScreen = ValueKey<String>('screen.more');
  static const paymentsScreen = ValueKey<String>('screen.payments');
  static const paymentDetailScreen = ValueKey<String>('screen.payment_detail');
  static const paymentUploadReceipt = ValueKey<String>(
    'payment.upload_receipt',
  );
  static const paymentStatus = ValueKey<String>('payment.status');

  static const notificationsScreen = ValueKey<String>('screen.notifications');
  static const taxScreen = ValueKey<String>('screen.tax');
  static const expenseScreen = ValueKey<String>('screen.expense');
  static const budgetScreen = ValueKey<String>('screen.budget');
  static const knowledgeScreen = ValueKey<String>('screen.knowledge');
  static const supportScreen = ValueKey<String>('screen.support');
  static const profileScreen = ValueKey<String>('screen.profile');
  static const settingsScreen = ValueKey<String>('screen.settings');

  static const routeFailure = ValueKey<String>('error.route_failure');
  static const appError = ValueKey<String>('error.app');

  static ValueKey<String> moreAction(String actionId) {
    return ValueKey<String>('more.$actionId');
  }

  static ValueKey<String> serviceTile(String serviceId) {
    return ValueKey<String>('service.tile.$serviceId');
  }

  static ValueKey<String> requestField(String fieldname) {
    return ValueKey<String>('request.field.$fieldname');
  }

  static ValueKey<String> caseRequiredDocument(String documentKey) {
    return ValueKey<String>('case.document.$documentKey');
  }

  static ValueKey<String> caseRequiredDocumentUpload(String documentKey) {
    return ValueKey<String>('case.document.$documentKey.upload');
  }
}
