import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../home/data/home_dashboard_repository.dart';
import '../data/notification_item.dart';
import '../data/notifications_repository.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final Set<String> _hiddenIds = <String>{};
  final Set<String> _mutationIds = <String>{};
  final List<NotificationItem> _additionalItems = [];
  int? _nextStart;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _didSeedPage = false;
  bool _markingAllRead = false;

  @override
  Widget build(BuildContext context) {
    final asyncNotifications = ref.watch(notificationPageProvider);
    return Scaffold(
      key: OmcWidgetKeys.notificationsScreen,
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

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
                children: [
                  _Header(
                    unreadCount: loadedUnread,
                    onReadAll: loadedUnread > 0 && !_markingAllRead
                        ? () => _markAllAsRead()
                        : null,
                    markingAllRead: _markingAllRead,
                  ),
                  const SizedBox(height: 18),
                  if (visible.isEmpty)
                    const _EmptyState(unreadOnly: false)
                  else
                    _NotificationList(
                      items: visible,
                      onOpen: _open,
                      onDismiss: _dismiss,
                    ),
                  if (_hasMore) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _loadingMore ? null : _loadMore,
                      icon: _loadingMore
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: Text(
                        _loadingMore ? 'Loading alerts' : 'Load more alerts',
                      ),
                    ),
                  ],
                ],
              );
            },
            loading: () => const _LoadingView(),
            error: (error, _) => _ErrorView(error: error, onRetry: _retryPage),
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

  void _resetPagingState() {
    _didSeedPage = false;
    _additionalItems.clear();
    _nextStart = null;
    _hasMore = false;
  }

  void _retryPage() {
    setState(_resetPagingState);
    ref.invalidate(notificationPageProvider);
  }

  Future<void> _refresh() async {
    setState(_resetPagingState);
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

  Future<void> _markAllAsRead() async {
    if (_markingAllRead) return;
    setState(() => _markingAllRead = true);
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .markAllNotificationsAsRead();
      if (!mounted) return;
      _invalidateNotificationSurfaces();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
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
  const _Header({
    required this.unreadCount,
    required this.onReadAll,
    required this.markingAllRead,
  });

  final int unreadCount;
  final VoidCallback? onReadAll;
  final bool markingAllRead;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 350 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.4;
        final identity = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Semantics(
              header: true,
              child: Text(
                'Alerts',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  height: 1.12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              unreadCount == 0
                  ? 'You are all caught up'
                  : '$unreadCount unread ${unreadCount == 1 ? 'update' : 'updates'}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
        final action = onReadAll == null
            ? null
            : TextButton.icon(
                onPressed: onReadAll,
                icon: markingAllRead
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all_rounded),
                label: Text(markingAllRead ? 'Marking read' : 'Mark all read'),
              );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              identity,
              if (action != null) ...[
                const SizedBox(height: 8),
                action,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: identity),
            if (action != null) ...[
              const SizedBox(width: 12),
              action,
            ],
          ],
        );
      },
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
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Dismissible(
            key: ValueKey(items[i].id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => onDismiss(items[i]),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.clear_rounded, color: Colors.white),
                  SizedBox(height: 3),
                  Text(
                    'Clear',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
          if (i != items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(item.type);

    return Semantics(
      button: true,
      label:
          '${item.isRead ? 'Read' : 'Unread'} ${item.type.label}: ${item.title}. ${item.message}',
      child: PremiumCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_typeIcon(item.type), color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                height: 1.3,
                                fontWeight: item.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!item.isRead) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 9,
                              height: 9,
                              margin: const EdgeInsets.only(top: 5),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.message,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            item.type.label,
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (item.reference?.trim().isNotEmpty == true)
                            Text(
                              item.reference!.trim(),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (item.createdAtLabel?.trim().isNotEmpty == true)
                            Text(
                              item.createdAtLabel!.trim(),
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _typeColor(AppNotificationType type) => switch (type) {
  AppNotificationType.documentRequest => AppTheme.warning,
  AppNotificationType.paymentAlert => AppTheme.success,
  AppNotificationType.serviceUpdate => AppTheme.info,
  AppNotificationType.taskUpdate => AppTheme.info,
  AppNotificationType.general => AppTheme.textSecondary,
};

IconData _typeIcon(AppNotificationType type) => switch (type) {
  AppNotificationType.documentRequest => Icons.description_outlined,
  AppNotificationType.paymentAlert => Icons.account_balance_wallet_outlined,
  AppNotificationType.serviceUpdate => Icons.assignment_outlined,
  AppNotificationType.taskUpdate => Icons.task_alt_outlined,
  AppNotificationType.general => Icons.notifications_none_rounded,
};

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.unreadOnly});

  final bool unreadOnly;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: AppTheme.textMuted,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            unreadOnly ? 'No unread alerts' : "You're all caught up",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            unreadOnly
                ? 'New unread updates will appear here.'
                : 'Service, document, payment and account updates will appear here.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
      children: [
        const _Header(
          unreadCount: 0,
          onReadAll: null,
          markingAllRead: false,
        ),
        const SizedBox(height: 20),
        AppErrorState.fromError(
          error: error,
          onRetry: onRetry,
          fallbackTitle: 'Alerts unavailable',
          fallbackMessage: 'We could not load your alerts. Please try again.',
          compact: true,
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
      children: [
        const _Header(
          unreadCount: 0,
          onReadAll: null,
          markingAllRead: false,
        ),
        const SizedBox(height: 18),
        for (var index = 0; index < 4; index++) ...[
          PremiumCard(
            padding: const EdgeInsets.all(16),
            child: Container(
              height: 76,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (index != 3) const SizedBox(height: 10),
        ],
      ],
    );
  }
}
