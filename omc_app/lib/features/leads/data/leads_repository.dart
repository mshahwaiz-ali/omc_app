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

final leadDetailProvider = FutureProvider.family<LeadItem?, String>((
  ref,
  leadId,
) {
  final repository = ref.watch(leadsRepositoryProvider);

  return repository.fetchLeadDetail(leadId);
});

class LeadsRepository {
  const LeadsRepository(this._frappeClient);

  final FrappeClient _frappeClient;

  Future<List<LeadItem>> fetchLeads() async {
    try {
      final response = await _frappeClient.getMethod(ApiConfig.leadsMethod);
      return _mapLeadsResponse(response);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message: 'Leads could not be loaded from the server right now.',
        code: 'leads_unavailable',
        details: error,
      );
    }
  }

  Future<LeadItem?> fetchLeadDetail(String leadId) async {
    final cleanLeadId = leadId.trim();
    if (cleanLeadId.isEmpty) return null;

    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.leadDetailMethod,
        queryParameters: {'lead_id': cleanLeadId, 'name': cleanLeadId},
      );

      return _mapLeadDetailResponse(response);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message: 'Lead details could not be loaded from the server right now.',
        code: 'lead_detail_unavailable',
        details: error,
      );
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

  LeadItem? _mapLeadDetailResponse(Map<String, dynamic> data) {
    final message = data['message'];

    final rawLead = message is Map<String, dynamic>
        ? message['lead'] ?? message['data'] ?? message['item'] ?? message
        : data['lead'] ?? data['data'] ?? data['item'];

    if (rawLead is! Map<String, dynamic>) return null;

    return LeadItem.fromJson(rawLead);
  }
}
