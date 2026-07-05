import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../data/notification_item.dart';
import '../data/notifications_repository.dart';

class NotificationDetailScreen extends ConsumerWidget {
  const NotificationDetailScreen({required this.notificationId, super.key});

  final String notificationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationAsync = ref.watch(
      notificationDetailProvider(notificationId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Details')),
      body: notificationAsync.when(
        data: (notification) {
          if (notification == null) {
            return PremiumEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Notification detail unavailable',
              message:
                  'Notification $notificationId is ready for the backend detail endpoint. Full message, reference, and actions will appear once data is available.',
            );
          }

          return _NotificationDetailBody(notification: notification);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => PremiumEmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'Notification detail unavailable',
          message:
              'Notification $notificationId could not be loaded right now. Please try again later.',
        ),
      ),
    );
  }
}

class _NotificationDetailBody extends StatelessWidget {
  const _NotificationDetailBody({required this.notification});

  final NotificationItem notification;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(notification.type);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(_typeIcon(notification.type), color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      notification.type.label,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _ReadPill(isRead: notification.isRead),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                notification.title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                notification.message,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _DetailTile(
                icon: Icons.tag_rounded,
                label: 'Reference',
                value: notification.reference ?? 'Not available',
              ),
              const Divider(height: 1, indent: 76),
              _DetailTile(
                icon: Icons.schedule_rounded,
                label: 'Created',
                value: notification.createdAtLabel ?? 'Not available',
              ),
              const Divider(height: 1, indent: 76),
              _DetailTile(
                icon: Icons.fingerprint_rounded,
                label: 'Notification ID',
                value: notification.id,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PremiumCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Actions',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _ActionButton(
                icon: Icons.open_in_new_rounded,
                label: 'Open related record',
                onTap: () => _showBackendPendingSnack(
                  context,
                  'Related record deep link is not connected yet.',
                ),
              ),
              const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.done_all_rounded,
                label: notification.isRead
                    ? 'Already marked read'
                    : 'Mark as read',
                onTap: () => _showBackendPendingSnack(
                  context,
                  'Mark-as-read endpoint is not connected yet.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showBackendPendingSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

class _ReadPill extends StatelessWidget {
  const _ReadPill({required this.isRead});

  final bool isRead;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          isRead ? 'Read' : 'Unread',
          style: const TextStyle(
            color: AppTheme.primaryRed,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: AppTheme.primaryRed),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryRed),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
