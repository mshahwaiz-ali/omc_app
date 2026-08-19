import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/effective_capabilities_provider.dart';
import '../../../core/widgets/data_freshness_banner.dart';
import '../data/support_repository.dart';
import 'support_screen_legacy.dart' as legacy;

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  bool _isForeground = true;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(
      SupportRefreshPolicy.feedRefreshInterval,
      (_) => _refreshLiveSupport(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) _refreshLiveSupport();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(effectiveCapabilitiesProvider);
    final sync = ref.watch(supportSyncStateProvider);
    final canReadTickets =
        capabilities.canCreateSupportTicket || capabilities.canUseSupportWorkspace;
    final configStale = sync.config.isStale;
    final feedStale = canReadTickets && sync.feed.isStale;
    final unreadStale = canReadTickets && sync.unread.isStale;
    final showBanner = configStale || feedStale || unreadStale;
    final lastSuccessAt = _latestSuccessfulSnapshot([
      if (configStale) sync.config.lastSuccessAt,
      if (feedStale) sync.feed.lastSuccessAt,
      if (unreadStale) sync.unread.lastSuccessAt,
    ]);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          if (showBanner)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: DataFreshnessBanner(
                title: lastSuccessAt == null
                    ? 'Live support data unavailable'
                    : 'Showing last synced support data',
                message: _staleMessage(
                  configStale: configStale,
                  feedStale: feedStale,
                  unreadStale: unreadStale,
                  hasSnapshot: lastSuccessAt != null,
                ),
                lastSuccessAt: lastSuccessAt,
                retrying: _retrying,
                onRetry: _retryStaleSupport,
              ),
            ),
          const Expanded(child: legacy.SupportScreen()),
        ],
      ),
    );
  }

  void _refreshLiveSupport() {
    if (!mounted || !_isForeground) return;
    final capabilities = ref.read(effectiveCapabilitiesProvider);
    final canReadTickets =
        capabilities.canCreateSupportTicket || capabilities.canUseSupportWorkspace;
    if (!canReadTickets) return;

    ref.invalidate(supportTicketPageProvider);
    ref.invalidate(supportTicketsProvider);
    ref.invalidate(supportUnreadCountProvider);
  }

  Future<void> _retryStaleSupport() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      final sync = ref.read(supportSyncStateProvider);
      final capabilities = ref.read(effectiveCapabilitiesProvider);
      final canReadTickets =
          capabilities.canCreateSupportTicket || capabilities.canUseSupportWorkspace;
      final futures = <Future<Object?>>[];

      if (sync.config.isStale) {
        ref.invalidate(supportConfigProvider);
        futures.add(ref.read(supportConfigProvider.future));
      }
      if (canReadTickets && sync.feed.isStale) {
        ref.invalidate(supportTicketPageProvider);
        futures.add(ref.read(supportTicketPageProvider.future));
      }
      if (canReadTickets && sync.unread.isStale) {
        ref.read(supportRepositoryProvider).clearUnreadCache();
        ref.invalidate(supportUnreadCountProvider);
        futures.add(ref.read(supportUnreadCountProvider.future));
      }

      if (futures.isNotEmpty) await Future.wait(futures);
    } catch (_) {
      // The freshness banner remains visible with the latest failure state.
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  DateTime? _latestSuccessfulSnapshot(List<DateTime?> values) {
    DateTime? latest;
    for (final value in values) {
      if (value == null) continue;
      if (latest == null || value.isAfter(latest)) latest = value;
    }
    return latest;
  }

  String _staleMessage({
    required bool configStale,
    required bool feedStale,
    required bool unreadStale,
    required bool hasSnapshot,
  }) {
    if (!hasSnapshot && configStale && !feedStale && !unreadStale) {
      return 'Built-in contact defaults are shown until live support configuration reconnects.';
    }
    if (!hasSnapshot) {
      return 'Support could not reach the server. Retry when your connection is available.';
    }
    if (feedStale) {
      return 'Ticket status may be older than the server. Replies and other changes still require a live connection.';
    }
    if (configStale) {
      return 'Contact details may be older than the server. Ticket changes still require a live connection.';
    }
    return 'The unread badge may be delayed until the next successful refresh.';
  }
}
