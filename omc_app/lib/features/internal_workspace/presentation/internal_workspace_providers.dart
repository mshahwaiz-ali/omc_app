import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../data/internal_workspace_repository.dart';
import '../domain/internal_service_case.dart';
import '../domain/internal_workspace_summary.dart';

final internalWorkspaceRepositoryProvider =
    Provider<InternalWorkspaceRepository>((ref) {
      final frappeClient = ref.watch(frappeClientProvider);

      return InternalWorkspaceRepository(frappeClient);
    });

final internalWorkspaceSummaryProvider =
    FutureProvider<InternalWorkspaceSummary>((ref) {
      final repository = ref.watch(internalWorkspaceRepositoryProvider);

      return repository.getSummary();
    });

final internalServiceCaseFiltersProvider =
    StateProvider<InternalServiceCaseFilters>((ref) {
      return const InternalServiceCaseFilters();
    });

final internalServiceCasesProvider = FutureProvider<InternalServiceCaseQueue>((
  ref,
) {
  final repository = ref.watch(internalWorkspaceRepositoryProvider);
  final filters = ref.watch(internalServiceCaseFiltersProvider);

  return repository.getServiceCases(
    search: filters.search,
    status: filters.status,
    documentStatus: filters.documentStatus,
  );
});
