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
  });

  const HomeDashboardSummary.empty()
    : activeCases = 0,
      completedCases = 0,
      pendingDocuments = 0;

  final int activeCases;
  final int completedCases;
  final int pendingDocuments;
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
    } on ApiError {
      // Dashboard is supportive UI. Do not block Home if backend dashboard
      // mapping is not ready yet.
      return const HomeDashboardSummary.empty();
    } catch (_) {
      return const HomeDashboardSummary.empty();
    }
  }

  HomeDashboardSummary _summaryFromResponse(Map<String, dynamic> response) {
    final message = response['message'];
    final data = message is Map<String, dynamic> ? message : response;

    return HomeDashboardSummary(
      activeCases: _readInt(data, const [
        'active_cases',
        'activeCases',
        'in_progress',
        'inProgress',
        'total_active',
      ]),
      completedCases: _readInt(data, const [
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
      ]),
    );
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
