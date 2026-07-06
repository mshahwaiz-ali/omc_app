import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';

final homeDashboardRepositoryProvider = Provider<HomeDashboardRepository>((
  ref,
) {
  return HomeDashboardRepository(frappeClient: ref.watch(frappeClientProvider));
});

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
    this.fallbackMessage,
  });

  const HomeDashboardSummary.empty({this.fallbackMessage})
    : activeCases = 0,
      completedCases = 0,
      pendingDocuments = 0,
      paymentsDue = 0,
      unreadNotifications = 0,
      recentActivity = const [];

  final int activeCases;
  final int completedCases;
  final int pendingDocuments;
  final int paymentsDue;
  final int unreadNotifications;
  final List<HomeDashboardActivity> recentActivity;
  final String? fallbackMessage;
}

class HomeDashboardActivity {
  const HomeDashboardActivity({
    required this.title,
    required this.subtitle,
    this.status,
    this.createdAtLabel,
  });

  final String title;
  final String subtitle;
  final String? status;
  final String? createdAtLabel;
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
      // Dashboard is supportive UI. Do not block Home if backend dashboard
      // mapping is not ready yet.
      return HomeDashboardSummary.empty(fallbackMessage: error.message);
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
        'documents',
        'pending_documents',
        'pendingDocuments',
        'pending_docs',
        'pendingDocs',
        'documents_required',
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
    );
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
