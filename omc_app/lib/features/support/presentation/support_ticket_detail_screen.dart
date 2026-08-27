import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/data_freshness_banner.dart';
import '../data/support_repository.dart';
import 'support_ticket_detail_legacy_screen.dart' as legacy;

class SupportTicketDetailScreen extends ConsumerWidget {
  const SupportTicketDetailScreen({required this.ticketId, super.key});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cleanId = ticketId.trim();
    final freshness = ref.watch(
      supportSyncStateProvider.select((state) => state.ticket(cleanId)),
    );
    final showingPreviousSnapshot =
        freshness.hasSuccessfulSnapshot &&
        (freshness.isStale || freshness.isRefreshing);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          if (showingPreviousSnapshot)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: DataFreshnessBanner(
                title: freshness.isStale
                    ? 'Showing last synced conversation'
                    : 'Refreshing conversation',
                message: freshness.isStale
                    ? 'New replies or status changes may not be visible yet. Sending a reply still requires the live server.'
                    : 'Keeping the current conversation visible while OMC checks for updates.',
                lastSuccessAt: freshness.lastSuccessAt,
                retrying: freshness.isRefreshing,
                onRetry: freshness.isRefreshing
                    ? null
                    : () => _retryNow(ref, cleanId),
              ),
            ),
          Expanded(child: legacy.SupportTicketDetailScreen(ticketId: ticketId)),
        ],
      ),
    );
  }

  void _retryNow(WidgetRef ref, String ticketId) {
    if (ticketId.isEmpty) return;
    final repository = ref.read(supportRepositoryProvider);
    repository.clearTicketCache(ticketId);
    repository.clearUnreadCache();
    ref.invalidate(supportTicketDetailProvider(ticketId));
    ref.invalidate(supportUnreadCountProvider);
  }
}
