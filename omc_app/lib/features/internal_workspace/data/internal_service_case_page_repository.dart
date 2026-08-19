import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/network/frappe_client.dart';
import '../domain/internal_service_case.dart';

const _internalServiceCaseReadMethod =
    'omc_app.api.internal_workspace_read_guard.get_service_cases';

final internalServiceCasePageRepositoryProvider =
    Provider<InternalServiceCasePageRepository>((ref) {
      return InternalServiceCasePageRepository(
        frappeClient: ref.watch(frappeClientProvider),
      );
    });

class InternalServiceCasePage {
  const InternalServiceCasePage({
    required this.queue,
    required this.start,
    required this.pageLength,
    required this.hasMore,
    required this.nextStart,
    required this.totalCount,
  });

  final InternalServiceCaseQueue queue;
  final int start;
  final int pageLength;
  final bool hasMore;
  final int? nextStart;
  final int totalCount;
}

class InternalServiceCasePageRepository {
  const InternalServiceCasePageRepository({required this.frappeClient});

  final FrappeClient frappeClient;

  Future<InternalServiceCasePage> fetchPage({
    int start = 0,
    int limit = 50,
    String? search,
    String? status,
    String? documentStatus,
    String? customer,
    String? service,
    String? caseId,
  }) async {
    final safeStart = start < 0 ? 0 : start;
    final safeLimit = limit.clamp(1, 100).toInt();
    final response = await frappeClient.getMethod(
      _internalServiceCaseReadMethod,
      queryParameters: {
        'limit_start': safeStart,
        'limit_page_length': safeLimit,
        if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
        if (status?.trim().isNotEmpty == true) 'status': status!.trim(),
        if (documentStatus?.trim().isNotEmpty == true)
          'document_status': documentStatus!.trim(),
        if (customer?.trim().isNotEmpty == true) 'customer': customer!.trim(),
        if (service?.trim().isNotEmpty == true) 'service': service!.trim(),
        if (caseId?.trim().isNotEmpty == true) 'case_id': caseId!.trim(),
      },
    );

    final message = response['message'];
    final source = message is Map<String, dynamic> ? message : response;
    final queue = InternalServiceCaseQueue.fromResponse(response);
    final hasMore = _readBool(source['has_more']);
    final parsedNext = _readInt(source['next_start']);

    return InternalServiceCasePage(
      queue: queue,
      start: _readInt(source['limit_start']) ?? safeStart,
      pageLength: _readInt(source['limit_page_length']) ?? safeLimit,
      hasMore: hasMore,
      nextStart: hasMore
          ? (parsedNext ?? safeStart + queue.cases.length)
          : null,
      totalCount: _readInt(source['total_count']) ?? queue.cases.length,
    );
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'yes';
  }
}
