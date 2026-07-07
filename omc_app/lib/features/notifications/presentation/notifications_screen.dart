import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../data/notification_item.dart';
import '../data/notifications_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(notificationsProvider);
            await ref.read(notificationsProvider.future);
          },
          child: notificationsAsync.when(
            data: (notifications) => notifications.isEmpty
                ? const _EmptyNotificationsView()
                : _NotificationsList(
                    notifications: notifications,
                    onMarkAllRead: notifications.any((item) => !item.isRead)
                        ? () => _markAllRead(context, ref)
                        : null,
                  ),
            loading: () => const _NotificationsLoadingView(),
            error: (error, _) =>
                _NotificationsErrorView(message: _cleanError(error)),
          ),
        ),
      ),
    );
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(notificationsRepositoryProvider)
          .markAllNotificationsAsRead();
      ref.invalidate(notificationsProvider);

      messenger.showSnackBar(
        const SnackBar(content: Text('All notifications marked as read.')),
      );
    } on ApiError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Notifications could not be updated right now.'),
        ),
      );
    }
  }
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList({
    required this.notifications,
    required this.onMarkAllRead,
  });

  final List<NotificationItem> notifications;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final unreadCount = notifications.where((item) => !item.isRead).length;
    final actionCount = notifications
        .where((item) => item.actionUrl != null && item.actionUrl!.isNotEmpty)
        .length;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      itemCount: notifications.length + 1,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 18 : 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _NotificationsHero(
            totalCount: notifications.length,
            unreadCount: unreadCount,
            actionCount: actionCount,
            onMarkAllRead: onMarkAllRead,
          );
        }

        return _NotificationCard(notification: notifications[index - 1]);
      },
    );
  }
}

class _NotificationsHero extends StatelessWidget {
  const _NotificationsHero({
    required this.totalCount,
    required this.unreadCount,
    required this.actionCount,
    required this.onMarkAllRead,
  });

  final int totalCount;
  final int unreadCount;
  final int actionCount;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppTheme.primaryRed.withValues(alpha: 0.10),
                  ),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppTheme.primaryRed,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Service updates, documents, payments and account alerts.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onMarkAllRead != null) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Mark all read',
                  onPressed: onMarkAllRead,
                  icon: const Icon(Icons.done_all_rounded),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              PremiumInfoChip(
                icon: Icons.inbox_outlined,
                label: '$totalCount total',
              ),
              PremiumInfoChip(
                icon: unreadCount == 0
                    ? Icons.mark_email_read_outlined
                    : Icons.mark_email_unread_outlined,
                label: unreadCount == 0 ? 'All read' : '$unreadCount unread',
              ),
              PremiumInfoChip(
                icon: Icons.touch_app_outlined,
                label: actionCount == 0 ? 'No actions' : '$actionCount actions',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final NotificationItem notification;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(notification.type);

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push(
          '/notifications/${Uri.encodeComponent(notification.id)}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(_typeIcon(notification.type), color: color),
                  ),
                  if (!notification.isRead)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: notification.isRead
                            ? FontWeight.w800
                            : FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PremiumInfoChip(
                          label: notification.type.label,
                          color: color,
                        ),
                        if (notification.reference != null)
                          PremiumInfoChip(label: notification.reference!),
                        if (notification.actionUrl != null)
                          const PremiumInfoChip(
                            label: 'Action available',
                            icon: Icons.touch_app_outlined,
                          ),
                        if (notification.createdAtLabel != null)
                          PremiumInfoChip(
                            label: notification.createdAtLabel!,
                            icon: Icons.schedule_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.documentRequest:
        return Colors.orange.shade800;
      case AppNotificationType.paymentAlert:
        return Colors.green.shade700;
      case AppNotificationType.serviceUpdate:
        return AppTheme.primaryRed;
      case AppNotificationType.general:
        return Colors.blueGrey.shade700;
    }
  }

  IconData _typeIcon(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.documentRequest:
        return Icons.folder_copy_outlined;
      case AppNotificationType.paymentAlert:
        return Icons.account_balance_wallet_outlined;
      case AppNotificationType.serviceUpdate:
        return Icons.assignment_outlined;
      case AppNotificationType.general:
        return Icons.notifications_none_rounded;
    }
  }
}

class _EmptyNotificationsView extends StatelessWidget {
  const _EmptyNotificationsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: const [
        _NotificationsHero(
          totalCount: 0,
          unreadCount: 0,
          actionCount: 0,
          onMarkAllRead: null,
        ),
        SizedBox(height: 18),
        _NotificationsStateCard(
          icon: Icons.notifications_none_rounded,
          title: 'No notifications yet',
          message:
              'Service updates, document requests and payment alerts will appear here when available.',
        ),
      ],
    );
  }
}

String _cleanError(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final message = error.toString().replaceFirst('ApiError:', '').trim();
  if (message.isEmpty) {
    return 'Notifications could not be loaded right now. Please try again.';
  }
  return message;
}

class _NotificationsErrorView extends StatelessWidget {
  const _NotificationsErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const _NotificationsHero(
          totalCount: 0,
          unreadCount: 0,
          actionCount: 0,
          onMarkAllRead: null,
        ),
        const SizedBox(height: 18),
        _NotificationsStateCard(
          icon: Icons.cloud_off_rounded,
          title: 'Notifications unavailable',
          message: message,
          isError: true,
        ),
      ],
    );
  }
}

class _NotificationsStateCard extends StatelessWidget {
  const _NotificationsStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red.shade700 : AppTheme.primaryRed;

    return PremiumCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsLoadingView extends StatelessWidget {
  const _NotificationsLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const _NotificationsLoadingHero();
        }

        return const _NotificationLoadingCard();
      },
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 18 : 12),
      itemCount: 4,
    );
  }
}

class _NotificationsLoadingHero extends StatelessWidget {
  const _NotificationsLoadingHero();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _LoadingBox(width: 58, height: 58, radius: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _LoadingBar(widthFactor: 0.55, height: 16),
                    SizedBox(height: 10),
                    _LoadingBar(widthFactor: 0.86),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _LoadingPill(width: 86),
              _LoadingPill(width: 96),
              _LoadingPill(width: 106),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationLoadingCard extends StatelessWidget {
  const _NotificationLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const PremiumCard(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          _LoadingBox(width: 48, height: 48, radius: 17),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LoadingBar(widthFactor: 0.62, height: 13),
                SizedBox(height: 10),
                _LoadingBar(widthFactor: 0.92),
                SizedBox(height: 8),
                _LoadingBar(widthFactor: 0.48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 30,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.widthFactor, this.height = 9});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
