import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import 'support_config_data.dart';
import 'support_repository_legacy.dart' as legacy;
import 'support_ticket.dart';

export 'support_repository_legacy.dart'
    hide
        SupportRepository,
        supportRepositoryProvider,
        supportConfigProvider,
        supportTicketPageProvider,
        supportTicketsProvider,
        supportTicketDetailProvider,
        activeSupportTicketProvider,
        supportUnreadCountProvider;

enum SupportSyncTarget { config, feed, unread, ticket }

enum SupportFreshnessStatus { idle, refreshing, fresh, stale }

class SupportResourceFreshness {
  const SupportResourceFreshness({
    this.status = SupportFreshnessStatus.idle,
    this.lastSuccessAt,
    this.lastAttemptAt,
    this.message,
  });

  final SupportFreshnessStatus status;
  final DateTime? lastSuccessAt;
  final DateTime? lastAttemptAt;
  final String? message;

  bool get isStale => status == SupportFreshnessStatus.stale;
  bool get isRefreshing => status == SupportFreshnessStatus.refreshing;
  bool get hasSuccessfulSnapshot => lastSuccessAt != null;

  SupportResourceFreshness copyWith({
    SupportFreshnessStatus? status,
    DateTime? lastSuccessAt,
    DateTime? lastAttemptAt,
    String? message,
    bool clearMessage = false,
  }) {
    return SupportResourceFreshness(
      status: status ?? this.status,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

class SupportSyncState {
  const SupportSyncState({
    this.config = const SupportResourceFreshness(),
    this.feed = const SupportResourceFreshness(),
    this.unread = const SupportResourceFreshness(),
    this.tickets = const {},
  });

  final SupportResourceFreshness config;
  final SupportResourceFreshness feed;
  final SupportResourceFreshness unread;
  final Map<String, SupportResourceFreshness> tickets;

  SupportResourceFreshness ticket(String ticketId) {
    return tickets[ticketId.trim()] ?? const SupportResourceFreshness();
  }

  SupportSyncState copyWith({
    SupportResourceFreshness? config,
    SupportResourceFreshness? feed,
    SupportResourceFreshness? unread,
    Map<String, SupportResourceFreshness>? tickets,
  }) {
    return SupportSyncState(
      config: config ?? this.config,
      feed: feed ?? this.feed,
      unread: unread ?? this.unread,
      tickets: tickets ?? this.tickets,
    );
  }
}

class SupportSyncNotifier extends Notifier<SupportSyncState> {
  @override
  SupportSyncState build() => const SupportSyncState();

  void report(
    SupportSyncTarget target,
    SupportResourceFreshness freshness, {
    String? ticketId,
  }) {
    switch (target) {
      case SupportSyncTarget.config:
        state = state.copyWith(config: freshness);
      case SupportSyncTarget.feed:
        state = state.copyWith(feed: freshness);
      case SupportSyncTarget.unread:
        state = state.copyWith(unread: freshness);
      case SupportSyncTarget.ticket:
        final cleanId = ticketId?.trim() ?? '';
        if (cleanId.isEmpty) return;
        state = state.copyWith(
          tickets: Map<String, SupportResourceFreshness>.unmodifiable({
            ...state.tickets,
            cleanId: freshness,
          }),
        );
    }
  }
}

final supportSyncStateProvider =
    NotifierProvider<SupportSyncNotifier, SupportSyncState>(
      SupportSyncNotifier.new,
    );

typedef SupportSyncReporter = void Function(
  SupportSyncTarget target,
  SupportResourceFreshness freshness, {
  String? ticketId,
});

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(
    frappeClient: ref.watch(frappeClientProvider),
    reportSync: (target, freshness, {ticketId}) {
      ref
          .read(supportSyncStateProvider.notifier)
          .report(target, freshness, ticketId: ticketId);
    },
  );
});

final supportConfigProvider = FutureProvider<SupportConfigData>((ref) {
  return ref.watch(supportRepositoryProvider).fetchSupportConfig();
});

final supportTicketPageProvider = FutureProvider<legacy.SupportTicketPage>((ref) {
  return ref.watch(supportRepositoryProvider).fetchSupportTicketPage();
});

final supportTicketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  return (await ref.watch(supportTicketPageProvider.future)).items;
});

final supportTicketDetailProvider =
    FutureProvider.family<SupportTicket?, String>((ref, ticketId) {
      return ref.watch(supportRepositoryProvider).fetchSupportTicket(ticketId);
    });

final activeSupportTicketProvider = FutureProvider<SupportTicket?>((ref) {
  return ref.watch(supportRepositoryProvider).fetchActiveSupportTicket();
});

final supportUnreadCountProvider = FutureProvider<int>((ref) {
  return ref.watch(supportRepositoryProvider).fetchSupportUnreadCount();
});

class SupportRepository extends legacy.SupportRepository {
  SupportRepository({
    required FrappeClient frappeClient,
    required SupportSyncReporter reportSync,
  }) : _reportSync = reportSync,
       super(frappeClient: frappeClient);

  static const detailFreshnessWindow = Duration(seconds: 15);
  static const unreadFreshnessWindow = Duration(seconds: 15);

  final SupportSyncReporter _reportSync;

  SupportConfigData? _configCache;
  DateTime? _configCachedAt;
  legacy.SupportTicketPage? _feedCache;
  DateTime? _feedCachedAt;
  int? _unreadCache;
  DateTime? _unreadCachedAt;
  final Map<String, _TicketCacheEntry> _ticketCache = {};

  @override
  Future<SupportConfigData> fetchSupportConfig() async {
    final previous = _freshnessFor(
      cachedAt: _configCachedAt,
      target: SupportSyncTarget.config,
    );
    _reportSync(
      SupportSyncTarget.config,
      _refreshing(previous),
    );

    try {
      final response = await frappeClient.getMethod(ApiConfig.supportConfigMethod);
      final config = SupportConfigData.fromApiResponse(response);
      final now = DateTime.now();
      _configCache = config;
      _configCachedAt = now;
      _reportSync(SupportSyncTarget.config, _fresh(now));
      return config;
    } catch (error) {
      if (_configCache != null && _canUseStale(error)) {
        _reportSync(
          SupportSyncTarget.config,
          _stale(_configCachedAt, error),
        );
        return _configCache!;
      }
      _configCache = null;
      _configCachedAt = null;
      _reportSync(SupportSyncTarget.config, _stale(null, error));
      rethrow;
    }
  }

  @override
  Future<legacy.SupportTicketPage> fetchSupportTicketPage({
    int start = 0,
    int limit = 20,
  }) async {
    final isFirstPage = start <= 0;
    if (isFirstPage) {
      final previous = _freshnessFor(
        cachedAt: _feedCachedAt,
        target: SupportSyncTarget.feed,
      );
      _reportSync(SupportSyncTarget.feed, _refreshing(previous));
    }

    try {
      final page = await super.fetchSupportTicketPage(start: start, limit: limit);
      if (isFirstPage) {
        final now = DateTime.now();
        _feedCache = page;
        _feedCachedAt = now;
        _reportSync(SupportSyncTarget.feed, _fresh(now));
      }
      return page;
    } catch (error) {
      if (isFirstPage && _feedCache != null && _canUseStale(error)) {
        _reportSync(SupportSyncTarget.feed, _stale(_feedCachedAt, error));
        return _feedCache!;
      }
      if (isFirstPage) {
        if (!_canUseStale(error)) {
          _feedCache = null;
          _feedCachedAt = null;
        }
        _reportSync(SupportSyncTarget.feed, _stale(_feedCachedAt, error));
      }
      rethrow;
    }
  }

  @override
  Future<SupportTicket?> fetchSupportTicket(String ticketId) async {
    final cleanId = ticketId.trim();
    if (cleanId.isEmpty) return super.fetchSupportTicket(ticketId);

    final cached = _ticketCache[cleanId];
    final now = DateTime.now();
    if (cached != null && now.difference(cached.cachedAt) < detailFreshnessWindow) {
      return cached.ticket;
    }

    final previous = cached == null
        ? const SupportResourceFreshness()
        : SupportResourceFreshness(
            status: SupportFreshnessStatus.fresh,
            lastSuccessAt: cached.cachedAt,
          );
    _reportSync(
      SupportSyncTarget.ticket,
      _refreshing(previous),
      ticketId: cleanId,
    );

    try {
      final ticket = await super.fetchSupportTicket(cleanId);
      if (ticket == null) {
        _ticketCache.remove(cleanId);
        _reportSync(
          SupportSyncTarget.ticket,
          _fresh(now),
          ticketId: cleanId,
        );
        return null;
      }
      final fetchedAt = DateTime.now();
      _ticketCache[cleanId] = _TicketCacheEntry(ticket, fetchedAt);
      _trimTicketCache();
      _reportSync(
        SupportSyncTarget.ticket,
        _fresh(fetchedAt),
        ticketId: cleanId,
      );
      return ticket;
    } catch (error) {
      if (cached != null && _canUseStale(error)) {
        _reportSync(
          SupportSyncTarget.ticket,
          _stale(cached.cachedAt, error),
          ticketId: cleanId,
        );
        return cached.ticket;
      }
      if (!_canUseStale(error)) _ticketCache.remove(cleanId);
      _reportSync(
        SupportSyncTarget.ticket,
        _stale(cached?.cachedAt, error),
        ticketId: cleanId,
      );
      rethrow;
    }
  }

  @override
  Future<int> fetchSupportUnreadCount() async {
    final now = DateTime.now();
    if (_unreadCache != null &&
        _unreadCachedAt != null &&
        now.difference(_unreadCachedAt!) < unreadFreshnessWindow) {
      return _unreadCache!;
    }

    final previous = _freshnessFor(
      cachedAt: _unreadCachedAt,
      target: SupportSyncTarget.unread,
    );
    _reportSync(SupportSyncTarget.unread, _refreshing(previous));
    try {
      final count = await super.fetchSupportUnreadCount();
      final fetchedAt = DateTime.now();
      _unreadCache = count;
      _unreadCachedAt = fetchedAt;
      _reportSync(SupportSyncTarget.unread, _fresh(fetchedAt));
      return count;
    } catch (error) {
      if (_unreadCache != null && _canUseStale(error)) {
        _reportSync(
          SupportSyncTarget.unread,
          _stale(_unreadCachedAt, error),
        );
        return _unreadCache!;
      }
      if (!_canUseStale(error)) {
        _unreadCache = null;
        _unreadCachedAt = null;
      }
      _reportSync(SupportSyncTarget.unread, _stale(_unreadCachedAt, error));
      rethrow;
    }
  }

  @override
  Future<int> markSupportTicketRead(String ticketId) async {
    final result = await super.markSupportTicketRead(ticketId);
    clearUnreadCache();
    return result;
  }

  @override
  Future<Map<String, dynamic>> addSupportTicketReply({
    required String ticketId,
    String message = '',
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
  }) async {
    final result = await super.addSupportTicketReply(
      ticketId: ticketId,
      message: message,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      attachmentType: attachmentType,
    );
    clearTicketCache(ticketId);
    clearFeedCache();
    clearUnreadCache();
    return result;
  }

  @override
  Future<SupportTicket?> updateSupportTicketStatus({
    required String ticketId,
    required String status,
    String? remarks,
  }) async {
    final result = await super.updateSupportTicketStatus(
      ticketId: ticketId,
      status: status,
      remarks: remarks,
    );
    clearTicketCache(ticketId);
    clearFeedCache();
    return result;
  }

  @override
  Future<SupportTicket?> assignSupportTicket({
    required String ticketId,
    required String assignedTo,
  }) async {
    final result = await super.assignSupportTicket(
      ticketId: ticketId,
      assignedTo: assignedTo,
    );
    clearTicketCache(ticketId);
    clearFeedCache();
    return result;
  }

  @override
  Future<Map<String, dynamic>> createSupportTicket({
    required String topic,
    required String message,
  }) async {
    final result = await super.createSupportTicket(topic: topic, message: message);
    clearFeedCache();
    clearUnreadCache();
    return result;
  }

  void clearConfigCache() {
    _configCache = null;
    _configCachedAt = null;
  }

  void clearFeedCache() {
    _feedCache = null;
    _feedCachedAt = null;
  }

  void clearUnreadCache() {
    _unreadCache = null;
    _unreadCachedAt = null;
  }

  void clearTicketCache(String ticketId) {
    _ticketCache.remove(ticketId.trim());
  }

  void clearAllReadCaches() {
    clearConfigCache();
    clearFeedCache();
    clearUnreadCache();
    _ticketCache.clear();
  }

  SupportResourceFreshness _freshnessFor({
    required DateTime? cachedAt,
    required SupportSyncTarget target,
  }) {
    if (cachedAt == null) return const SupportResourceFreshness();
    return SupportResourceFreshness(
      status: SupportFreshnessStatus.fresh,
      lastSuccessAt: cachedAt,
    );
  }

  SupportResourceFreshness _refreshing(SupportResourceFreshness previous) {
    return previous.copyWith(
      status: SupportFreshnessStatus.refreshing,
      lastAttemptAt: DateTime.now(),
      clearMessage: true,
    );
  }

  SupportResourceFreshness _fresh(DateTime at) {
    return SupportResourceFreshness(
      status: SupportFreshnessStatus.fresh,
      lastSuccessAt: at,
      lastAttemptAt: at,
    );
  }

  SupportResourceFreshness _stale(DateTime? lastSuccessAt, Object error) {
    return SupportResourceFreshness(
      status: SupportFreshnessStatus.stale,
      lastSuccessAt: lastSuccessAt,
      lastAttemptAt: DateTime.now(),
      message: _errorMessage(error),
    );
  }

  bool _canUseStale(Object error) {
    if (error is! ApiError) return false;
    if (error.retryable) return true;
    if (error.statusCode == 408 || error.statusCode == 429) return true;
    if ((error.statusCode ?? 0) >= 500) return true;
    return error.category == ApiFailureCategory.timeout ||
        error.category == ApiFailureCategory.offline ||
        error.category == ApiFailureCategory.server;
  }

  String _errorMessage(Object error) {
    if (error is ApiError && error.message.trim().isNotEmpty) {
      return error.message.trim();
    }
    return 'Live support data could not be refreshed.';
  }

  void _trimTicketCache() {
    if (_ticketCache.length <= 24) return;
    final oldest = _ticketCache.entries.toList()
      ..sort((a, b) => a.value.cachedAt.compareTo(b.value.cachedAt));
    for (final entry in oldest.take(_ticketCache.length - 24)) {
      _ticketCache.remove(entry.key);
    }
  }
}

class _TicketCacheEntry {
  const _TicketCacheEntry(this.ticket, this.cachedAt);

  final SupportTicket ticket;
  final DateTime cachedAt;
}
