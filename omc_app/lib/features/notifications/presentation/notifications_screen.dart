import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_state.dart';
import '../../home/data/home_dashboard_repository.dart';
import '../data/notification_item.dart';
import '../data/notifications_repository.dart';

enum _NotificationFilter { all, unread }

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  _NotificationFilter _filter = _NotificationFilter.all;
  final Set<String> _hiddenIds = <String>{};
  final Set<String> _mutationIds = <String>{};
  final List<NotificationItem> _additionalItems = [];
  int? _nextStart;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _didSeedPage = false;

  @override
  Widget build(BuildContext context) {
    final asyncNotifications = ref.watch(notificationPageProvider);
    final canonicalUnread = ref.watch(unreadNotificationsProvider).value;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          onRefresh: _refresh,
          child: asyncNotifications.when(
            data: (page) {
              if (!_didSeedPage) {
                _didSeedPage = true;
                _nextStart = page.nextStart;
                _hasMore = page.hasMore;
              }
              final items = [...page.items, ..._additionalItems];
              final visible = items
                  .where((item) => !_hiddenIds.contains(item.id))
                  .toList();
              final loadedUnread = visible.where((item) => !item.isRead).length;
              final unreadCount = canonicalUnread ?? loadedUnread;
              final filtered = _filter == _NotificationFilter.unread
                  ? visible.where((item) => !item.isRead).toList()
                  : visible;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 144),
                children: [
                  _Header(
                    unreadCount: unreadCount,
                    onReadAll: unreadCount > 0 ? _readAll : null,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<_NotificationFilter>(
                    segments: [
                      const ButtonSegment(
                        value: _NotificationFilter.all,
                        label: Text('All'),
                      ),
                      ButtonSegment(
                        value: _NotificationFilter.unread,
                        label: Text(
                          unreadCount > 0 ? 'Unread $unreadCount' : 'Unread',
                        ),
                      ),
                    ],
                    selected: {_filter},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) =>
                        setState(() => _filter = value.first),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    _EmptyState(
                      unreadOnly: _filter == _NotificationFilter.unread,
                    )
                  else
                    _NotificationList(
                      items: filtered,
                      onOpen: _open,
                      onDismiss: _dismiss,
                    ),
                  if (_hasMore) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loadingMore ? null : _loadMore,
                      icon: _loadingMore
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: Text(_loadingMore ? 'Loading' : 'Load more'),
                    ),
                  ],
                ],
              );
            },
            loading: () => const _LoadingView(),
            error: (error, _) => _ErrorView(
              error: error,
              onRetry: () => ref.invalidate(notificationsProvider),
            ),
          ),
        ),
      ),
    );
  }

  void _invalidateNotificationSurfaces() {
    ref
      ..invalidate(notificationsProvider)
      ..invalidate(notificationPageProvider)
      ..invalidate(unreadNotificationsProvider)
      ..invalidate(homeDashboardSummaryProvider);
  }

  Future<void> _refresh() async {
    _didSeedPage = false;
    _additionalItems.clear();
    _nextStart = null;
    _hasMore = false;
    _invalidateNotificationSurfaces();
    await ref.read(notificationPageProvider.future);
  }

  Future<void> _loadMore() async {
    final start = _nextStart;
    if (_loadingMore || !_hasMore || start == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(notificationsRepositoryProvider)
          .fetchNotificationPage(start: start);
      if (!mounted) return;
      setState(() {
        final knownIds = {
          ...ref
                  .read(notificationPageProvider)
                  .value
                  ?.items
                  .map((item) => item.id) ??
              const <String>{},
          ..._additionalItems.map((item) => item.id),
        };
        _additionalItems.addAll(
          page.items.where((item) => !knownIds.contains(item.id)),
        );
        _nextStart = page.nextStart;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _readAll() async {
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .markAllNotificationsAsRead();
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _open(NotificationItem item) async {
    try {
      if (!item.isRead) {
        await ref
            .read(notificationsRepositoryProvider)
            .markNotificationAsRead(item.id);
        _invalidateNotificationSurfaces();
      }
      if (!mounted) return;
      context.push('/notifications/${Uri.encodeComponent(item.id)}');
    } catch (error) {
      _showError(error);
    }
  }

  Future<bool> _dismiss(NotificationItem item) async {
    if (_mutationIds.contains(item.id)) return false;

    _mutationIds.add(item.id);
    setState(() => _hiddenIds.add(item.id));
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .dismissNotification(item.id);
      _invalidateNotificationSurfaces();
      if (!mounted) return true;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Notification cleared.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _restore(item),
          ),
        ),
      );
      return true;
    } catch (error) {
      if (mounted) setState(() => _hiddenIds.remove(item.id));
      _showError(error);
      return false;
    } finally {
      _mutationIds.remove(item.id);
    }
  }

  Future<void> _restore(NotificationItem item) async {
    if (_mutationIds.contains(item.id)) return;

    _mutationIds.add(item.id);
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .restoreNotification(item.id);
      if (mounted) setState(() => _hiddenIds.remove(item.id));
      await _refresh();
    } catch (error) {
      _showError(error);
    } finally {
      _mutationIds.remove(item.id);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppFailureClassifier.classify(error).message)),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.unreadCount, required this.onReadAll});
  final int unreadCount;
  final VoidCallback? onReadAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notifications',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                unreadCount == 0
                    ? 'You are all caught up'
                    : '$unreadCount unread ${unreadCount == 1 ? 'update' : 'updates'}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (onReadAll != null)
          TextButton.icon(
            onPressed: onReadAll,
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('Read all'),
          ),
      ],
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({
    required this.items,
    required this.onOpen,
    required this.onDismiss,
  });
  final List<NotificationItem> items;
  final Future<void> Function(NotificationItem) onOpen;
  final Future<bool> Function(NotificationItem) onDismiss;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Dismissible(
                key: ValueKey(items[i].id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => onDismiss(items[i]),
                background: Container(
                  color: const Color(0xFFDC2626),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.clear_rounded, color: Colors.white),
                      Text(
                        'Clear',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                child: _NotificationRow(
                  item: items[i],
                  onTap: () => onOpen(items[i]),
                ),
              ),
              if (i != items.length - 1) const Divider(height: 1, indent: 64),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item, required this.onTap});
  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = _typeColour(item.type);
    return Material(
      color: item.isRead
          ? Colors.white
          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.035),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_typeIcon(item.type), color: colour, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!item.isRead)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 7),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: item.isRead
                                  ? FontWeight.w700
                                  : FontWeight.w900,
                            ),
                          ),
                        ),
                        if (item.createdAtLabel != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            item.createdAtLabel!,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        item.type.label,
                        if (item.reference != null) item.reference!,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colour,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _typeColour(AppNotificationType type) => switch (type) {
  AppNotificationType.documentRequest => const Color(0xFF4F46E5),
  AppNotificationType.paymentAlert => const Color(0xFF047857),
  AppNotificationType.serviceUpdate => const Color(0xFFB42318),
  AppNotificationType.general => const Color(0xFF475569),
};

IconData _typeIcon(AppNotificationType type) => switch (type) {
  AppNotificationType.documentRequest => Icons.description_outlined,
  AppNotificationType.paymentAlert => Icons.account_balance_wallet_outlined,
  AppNotificationType.serviceUpdate => Icons.assignment_outlined,
  AppNotificationType.general => Icons.notifications_none_rounded,
};

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.unreadOnly});
  final bool unreadOnly;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
    child: Column(
      children: [
        const Icon(
          Icons.notifications_none_rounded,
          color: AppTheme.textMuted,
          size: 38,
        ),
        const SizedBox(height: 12),
        Text(
          unreadOnly ? 'No unread notifications' : "You're all caught up",
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          unreadOnly
              ? 'New unread updates will appear here.'
              : 'Service, document, payment and account updates will appear here.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 144),
    children: [
      const _Header(unreadCount: 0, onReadAll: null),
      const SizedBox(height: 24),
      AppErrorState.fromError(
        error: error,
        onRetry: onRetry,
        fallbackTitle: 'Notifications unavailable',
        fallbackMessage:
            'We could not load your notifications. Please try again.',
        compact: true,
      ),
    ],
  );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => ListView.separated(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 144),
    itemCount: 6,
    separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 18 : 1),
    itemBuilder: (_, index) => index == 0
        ? const _Header(unreadCount: 0, onReadAll: null)
        : Container(
            height: 86,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE7EAF0)),
            ),
          ),
  );
}
