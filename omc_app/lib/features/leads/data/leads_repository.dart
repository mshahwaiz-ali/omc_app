import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/network/mutation_intent.dart';
import '../domain/lead_item.dart';

final leadsRepositoryProvider = Provider<LeadsRepository>((ref) {
  ref.watch(sessionEpochProvider);
  final frappeClient = ref.watch(frappeClientProvider);

  return LeadsRepository(frappeClient);
});

final leadsProvider = FutureProvider.autoDispose<List<LeadItem>>((ref) {
  final repository = ref.watch(leadsRepositoryProvider);

  return repository.fetchLeads();
});

final leadDetailProvider = FutureProvider.autoDispose.family<LeadItem?, String>(
  (ref, leadId) {
    final repository = ref.watch(leadsRepositoryProvider);

    return repository.fetchLeadDetail(leadId);
  },
);

class LeadsRepository {
  LeadsRepository(this._frappeClient);

  final FrappeClient _frappeClient;
  final MutationIntent _createIntent = MutationIntent();

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

  Future<LeadItem> createLead({
    required String title,
    String? customerName,
    String? phone,
    String? email,
    String? source,
    String? serviceInterest,
    String? notes,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const ApiError(message: 'Lead title is required.');
    }

    try {
      final data = {
        'title': cleanTitle,
        'lead_name': (customerName ?? cleanTitle).trim(),
        'phone': phone?.trim() ?? '',
        'email': email?.trim() ?? '',
        'source': source?.trim().isNotEmpty == true
            ? source!.trim()
            : 'Mobile App',
        'service_interest': serviceInterest?.trim() ?? '',
        'notes': notes?.trim() ?? '',
      };
      final key = _createIntent.keyFor(data);
      final response = await _frappeClient.postMethod(
        ApiConfig.createLeadMethod,
        data: {...data, 'idempotency_key': key},
        idempotencyKey: key,
      );

      final created = _mapLeadDetailResponse(response);
      if (created == null) {
        throw const ApiError(
          message: 'Lead was created but response was empty.',
        );
      }
      _createIntent.complete();
      return created;
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message: 'Lead could not be created right now.',
        code: 'lead_create_failed',
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
        ? message['leads'] ??
              message['lead_list'] ??
              message['data'] ??
              message['items'] ??
              message['rows'] ??
              message['results'] ??
              message['records']
        : data['leads'] ??
              data['lead_list'] ??
              data['data'] ??
              data['items'] ??
              data['rows'] ??
              data['results'] ??
              data['records'];

    if (rawLeads is! List) return const [];

    return rawLeads
        .whereType<Map<String, dynamic>>()
        .map(LeadItem.fromJson)
        .toList(growable: false);
  }

  LeadItem? _mapLeadDetailResponse(Map<String, dynamic> data) {
    final message = data['message'];

    final rawLead = message is Map<String, dynamic>
        ? message['lead'] ??
              message['lead_detail'] ??
              message['data'] ??
              message['item'] ??
              message['record'] ??
              message
        : data['lead'] ??
              data['lead_detail'] ??
              data['data'] ??
              data['item'] ??
              data['record'];

    if (rawLead is! Map<String, dynamic>) return null;

    return LeadItem.fromJson(rawLead);
  }
}
