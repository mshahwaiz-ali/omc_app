import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';

final homeDashboardRepositoryProvider = Provider<HomeDashboardRepository>(
  (ref) {
    return HomeDashboardRepository(frappeClient: ref.watch(frappeClientProvider));
  },
);

final homeDashboardSummaryProvider = FutureProvider<HomeDashboardSummary>((
  ref,
) async {
  final repository = ref.watch(homeDashboardRepositoryProvider);
  return repository.fetchSummary();
});

class HomeDashboardSummary {
  const HomeDashboardSummary({
    required this.activeCases,
    required this.completedCases,
    required this.pendingDocuments,
    this.paymentsDue = 0,
    this.unreadNotifications = 0,
    this.recentActivity = const [],
    this.serviceSnapshots = const [],
    this.documentSummary = const HomeDashboardDocumentSummary.empty(),
    this.paymentSummary = const HomeDashboardPaymentSummary.empty(),
    this.supportSummary = const HomeDashboardSupportSummary.empty(),
    this.operationsSummary = const HomeDashboardOperationsSummary.empty(),
    this.nextAction,
    this.fallbackMessage,
  });

  const HomeDashboardSummary.empty({this.fallbackMessage})
    : activeCases = 0,
      completedCases = 0,
      pendingDocuments = 0,
      paymentsDue = 0,
      unreadNotifications = 0,
      recentActivity = const [],
      serviceSnapshots = const [],
      documentSummary = const HomeDashboardDocumentSummary.empty(),
      paymentSummary = const HomeDashboardPaymentSummary.empty(),
      supportSummary = const HomeDashboardSupportSummary.empty(),
      operationsSummary = const HomeDashboardOperationsSummary.empty(),
      nextAction = null;

  final int activeCases;
  final int completedCases;
  final int pendingDocuments;
  final int paymentsDue;
  final int unreadNotifications;
  final List<HomeDashboardActivity> recentActivity;
  final List<HomeDashboardServiceSnapshot> serviceSnapshots;
  final HomeDashboardDocumentSummary documentSummary;
  final HomeDashboardPaymentSummary paymentSummary;
  final HomeDashboardSupportSummary supportSummary;
  final HomeDashboardOperationsSummary operationsSummary;
  final HomeDashboardNextAction? nextAction;
  final String? fallbackMessage;
}

class HomeDashboardDocumentSummary {
  const HomeDashboardDocumentSummary({
    required this.missing,
    required this.uploaded,
    required this.underReview,
    required this.approved,
    required this.rejected,
    required this.total,
  });

  const HomeDashboardDocumentSummary.empty()
    : missing = 0,
      uploaded = 0,
      underReview = 0,
      approved = 0,
      rejected = 0,
      total = 0;

  final int missing;
  final int uploaded;
  final int underReview;
  final int approved;
  final int rejected;
  final int total;
}

class HomeDashboardPaymentSummary {
  const HomeDashboardPaymentSummary({
    required this.pending,
    required this.receiptSubmitted,
    required this.underReview,
    required this.receiptUnderReview,
    required this.paid,
    required this.rejected,
    required this.total,
  });

  const HomeDashboardPaymentSummary.empty()
    : pending = 0,
      receiptSubmitted = 0,
      underReview = 0,
      receiptUnderReview = 0,
      paid = 0,
      rejected = 0,
      total = 0;

  final int pending;
  final int receiptSubmitted;
  final int underReview;
  final int receiptUnderReview;
  final int paid;
  final int rejected;
  final int total;
}

class HomeDashboardSupportSummary {
  const HomeDashboardSupportSummary({
    required this.open,
    required this.waitingCustomer,
    required this.total,
  });

  const HomeDashboardSupportSummary.empty()
    : open = 0,
      waitingCustomer = 0,
      total = 0;

  final int open;
  final int waitingCustomer;
  final int total;
}

class HomeDashboardOperationsSummary {
  const HomeDashboardOperationsSummary({
    required this.openLeads,
    required this.activeCustomers,
    required this.pendingTasks,
    required this.pendingPayments,
    required this.documentsWaitingReview,
    required this.activeServices,
    required this.waitingCustomer,
  });

  const HomeDashboardOperationsSummary.empty()
    : openLeads = 0,
      activeCustomers = 0,
      pendingTasks = 0,
      pendingPayments = 0,
      documentsWaitingReview = 0,
      activeServices = 0,
      waitingCustomer = 0;

  final int openLeads;
  final int activeCustomers;
  final int pendingTasks;
  final int pendingPayments;
  final int documentsWaitingReview;
  final int activeServices;
  final int waitingCustomer;
}

class HomeDashboardNextAction {
  const HomeDashboardNextAction({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.buttonLabel,
  });

  final String type;
  final String title;
  final String subtitle;
  final String route;
  final String buttonLabel;
}

class HomeDashboardServiceSnapshot {
  const HomeDashboardServiceSnapshot({
    required this.id,
    required this.title,
    required this.status,
    required this.customerName,
    required this.documentSummary,
    required this.paymentSummary,
    required this.progress,
    this.colorFamily,
  });

  final String id;
  final String title;
  final String status;
  final String customerName;
  final HomeDashboardDocumentSummary documentSummary;
  final HomeDashboardPaymentSummary paymentSummary;
  final double progress;
  final String? colorFamily;
}

class HomeDashboardActivity {
  const HomeDashboardActivity({
    required this.title,
    required this.subtitle,
    this.status,
    this.createdAtLabel,
    this.colorFamily,
  });

  final String title;
  final String subtitle;
  final String? status;
  final String? createdAtLabel;
  final String? colorFamily;
}

class HomeDashboardRepository {
  const HomeDashboardRepository({required this._frappeClient});

  final FrappeClient _frappeClient;

  Future<HomeDashboardSummary> fetchSummary() async {
    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.dashboardDataMethod,
      );

      return _summaryFromResponse(response);
    } on ApiError catch (error) {
      final statusCode = error.statusCode;
      final isAuthError = statusCode == 401 || statusCode == 403;
      final message = isAuthError
          ? 'Dashboard summary is not available for this account yet.'
          : error.message;

      return HomeDashboardSummary.empty(fallbackMessage: message);
    } catch (_) {
      return const HomeDashboardSummary.empty(
        fallbackMessage:
            'Dashboard summary could not be loaded from the backend right now.',
      );
    }
  }

  HomeDashboardSummary _summaryFromResponse(Map<String, dynamic> response) {
    final message = response['message'];
    final data = message is Map<String, dynamic> ? message : response;
    final documentSummary = _documentSummary(data['document_summary']);
    final paymentSummary = _paymentSummary(data['payment_summary']);

    return HomeDashboardSummary(
      activeCases: _readInt(data, const [
        'open_services',
        'active_cases',
        'activeCases',
        'in_progress',
        'inProgress',
        'total_active',
      ]),
      completedCases: _readInt(data, const [
        'completed_services',
        'completed_cases',
        'completedCases',
        'completed',
        'total_completed',
      ]),
      pendingDocuments: _readInt(data, const [
        'pending_documents',
        'pendingDocuments',
        'pending_docs',
        'pendingDocs',
        'documents_required',
        'documents',
      ]),
      paymentsDue: _readInt(data, const [
        'payments_due',
        'due_payments',
        'pending_payments',
        'paymentsDue',
      ]),
      unreadNotifications: _readInt(data, const [
        'notifications',
        'unread_notifications',
        'unreadNotifications',
      ]),
      recentActivity: _activityList(
        data['recent_activity'] ?? data['timeline'] ?? data['activity'],
      ),
      serviceSnapshots: _serviceSnapshots(
        data['service_snapshots'] ?? data['active_services'] ?? data['services'],
      ),
      documentSummary: documentSummary,
      paymentSummary: paymentSummary,
      supportSummary: _supportSummary(data['support_summary']),
      operationsSummary: _operationsSummary(data['operations_summary']),
      nextAction: _nextAction(data['next_action']),
    );
  }

  HomeDashboardDocumentSummary _documentSummary(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return const HomeDashboardDocumentSummary.empty();
    }

    return HomeDashboardDocumentSummary(
      missing: _readInt(value, const ['missing', 'pending', 'documents']),
      uploaded: _readInt(value, const ['uploaded']),
      underReview: _readInt(value, const ['under_review', 'underReview']),
      approved: _readInt(value, const ['approved']),
      rejected: _readInt(value, const ['rejected']),
      total: _readInt(value, const ['total']),
    );
  }

  HomeDashboardPaymentSummary _paymentSummary(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return const HomeDashboardPaymentSummary.empty();
    }

    return HomeDashboardPaymentSummary(
      pending: _readInt(value, const ['pending', 'payments_due']),
      receiptSubmitted: _readInt(value, const ['receipt_submitted']),
      underReview: _readInt(value, const ['under_review', 'underReview']),
      receiptUnderReview: _readInt(value, const ['receipt_under_review']),
      paid: _readInt(value, const ['paid']),
      rejected: _readInt(value, const ['rejected']),
      total: _readInt(value, const ['total']),
    );
  }

  HomeDashboardSupportSummary _supportSummary(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return const HomeDashboardSupportSummary.empty();
    }

    return HomeDashboardSupportSummary(
      open: _readInt(value, const ['open']),
      waitingCustomer: _readInt(value, const ['waiting_customer']),
      total: _readInt(value, const ['total']),
    );
  }

  HomeDashboardOperationsSummary _operationsSummary(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return const HomeDashboardOperationsSummary.empty();
    }

    return HomeDashboardOperationsSummary(
      openLeads: _readInt(value, const ['open_leads']),
      activeCustomers: _readInt(value, const ['active_customers']),
      pendingTasks: _readInt(value, const ['pending_tasks']),
      pendingPayments: _readInt(value, const ['pending_payments']),
      documentsWaitingReview: _readInt(value, const ['documents_waiting_review']),
      activeServices: _readInt(value, const ['active_services']),
      waitingCustomer: _readInt(value, const ['waiting_customer']),
    );
  }

  HomeDashboardNextAction? _nextAction(dynamic value) {
    if (value is! Map<String, dynamic>) return null;

    return HomeDashboardNextAction(
      type: _readString(value, const ['type']),
      title: _readString(value, const ['title']),
      subtitle: _readString(value, const ['subtitle']),
      route: _readString(value, const ['route']),
      buttonLabel: _readString(value, const ['button_label', 'buttonLabel']),
    );
  }

  List<HomeDashboardServiceSnapshot> _serviceSnapshots(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final progressValue = item['progress'];
          final progress = progressValue is num
              ? progressValue.toDouble().clamp(0, 1).toDouble()
              : 0.0;

          return HomeDashboardServiceSnapshot(
            id: _readString(item, const ['id', 'name']),
            title: _readString(item, const ['title', 'service_title', 'service']),
            status: _readString(item, const ['status']),
            customerName: _readString(item, const ['customer_name']),
            documentSummary: _documentSummary(
              item['document_summary'] ?? item['documents'],
            ),
            paymentSummary: _paymentSummary(
              item['payment_summary'] ?? item['payments'],
            ),
            progress: progress,
            colorFamily: _readNullableString(item, const [
              'color_family',
              'service_color_family',
              'family',
              'module',
            ]),
          );
        })
        .where((item) => item.title.isNotEmpty || item.id.isNotEmpty)
        .toList(growable: false);
  }

  List<HomeDashboardActivity> _activityList(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => HomeDashboardActivity(
            title: _readString(item, const [
              'title',
              'activity_type',
              'status',
              'subject',
            ]),
            subtitle: _readString(item, const [
              'subtitle',
              'description',
              'remarks',
              'message',
            ]),
            status: _readNullableString(item, const ['status']),
            createdAtLabel: _readNullableString(item, const [
              'created_at_label',
              'creation',
              'created',
              'modified',
              'event_time',
            ]),
            colorFamily: _readNullableString(item, const [
              'color_family',
              'service_color_family',
              'family',
              'module',
            ]),
          ),
        )
        .where((item) => item.title.isNotEmpty || item.subtitle.isNotEmpty)
        .toList(growable: false);
  }

  String _readString(Map<String, dynamic> data, List<String> keys) {
    return _readNullableString(data, keys) ?? '';
  }

  String? _readNullableString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      final text = value?.toString().trim();

      if (text != null && text.isNotEmpty) return text;
    }

    return null;
  }

  int _readInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value is int) return value;
      if (value is num) return value.round();

      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }

    return 0;
  }
}
