import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import '../domain/lead_item.dart';

final leadsRepositoryProvider = Provider<LeadsRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);

  return LeadsRepository(frappeClient);
});

final leadsProvider = FutureProvider<List<LeadItem>>((ref) {
  final repository = ref.watch(leadsRepositoryProvider);

  return repository.fetchLeads();
});

class LeadsRepository {
  const LeadsRepository(this._frappeClient);

  final FrappeClient _frappeClient;

  Future<List<LeadItem>> fetchLeads() async {
    try {
      final response = await _frappeClient.getMethod(ApiConfig.leadsMethod);

      return _mapLeadsResponse(response);
    } on ApiError {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  List<LeadItem> _mapLeadsResponse(Map<String, dynamic> data) {
    final message = data['message'];

    final rawLeads = message is List
        ? message
        : message is Map<String, dynamic>
        ? message['leads'] ?? message['data'] ?? message['items']
        : data['leads'] ?? data['data'] ?? data['items'];

    if (rawLeads is! List) return const [];

    return rawLeads
        .whereType<Map<String, dynamic>>()
        .map(LeadItem.fromJson)
        .toList(growable: false);
  }
}
