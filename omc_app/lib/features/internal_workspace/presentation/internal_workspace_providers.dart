import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../data/internal_workspace_repository.dart';
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
