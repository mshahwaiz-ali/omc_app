import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/app_back_header.dart';
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
      appBar: const AppBackHeader(title: 'Notification Details'),
      body: SafeArea(
        child: notificationAsync.when(
          data: (notification) {
            if (notification == null) {
              return PremiumEmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Notification details unavailable',
                message:
                    'Notification $notificationId could not be loaded right now. Full message, reference, and actions will appear when data is available.',
              );
            }

            return _NotificationDetailBody(notification: notification);
          },
          loading: () => const _NotificationDetailLoadingView(),
          error: (error, _) => PremiumEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Notification unavailable',
            message: _cleanError(error),
          ),
        ),
      ),
    );
  }
}

String _cleanError(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final message = error.toString().replaceFirst('ApiError:', '').trim();
  if (message.isEmpty) {
    return 'Notification details could not be loaded right now. Please try again.';
  }
  return message;
}

class _NotificationDetailBody extends ConsumerStatefulWidget {
  const _NotificationDetailBody({required this.notification});

  final NotificationItem notification;

  @override
  ConsumerState<_NotificationDetailBody> createState() =>
      _NotificationDetailBodyState();
}

class _NotificationDetailBodyState
    extends ConsumerState<_NotificationDetailBody> {
  bool _isMarkingRead = false;

  NotificationItem get notification => widget.notification;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(notification.type);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      children: [
        _NotificationHeroCard(
          notification: notification,
          color: color,
          icon: _typeIcon(notification.type),
        ),
        const SizedBox(height: 18),
        _DetailSection(
          title: 'Notification details',
          subtitle: 'Reference, time and backend metadata for this update.',
          children: [
            _DetailTile(
              icon: Icons.tag_rounded,
              label: 'Reference',
              value: notification.reference ?? 'Not available',
            ),
            const _DividerIndent(),
            _DetailTile(
              icon: Icons.schedule_rounded,
              label: 'Created',
              value: notification.createdAtLabel ?? 'Not available',
            ),
            const _DividerIndent(),
            _DetailTile(
              icon: Icons.link_rounded,
              label: 'Action link',
              value: notification.actionUrl == null
                  ? 'Not available'
                  : 'Available',
            ),
            const _DividerIndent(),
            _DetailTile(
              icon: Icons.fingerprint_rounded,
              label: 'Notification ID',
              value: notification.id,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _ActionsCard(
          relatedActionLabel: _relatedActionLabel(notification),
          isRead: notification.isRead,
          isMarkingRead: _isMarkingRead,
          onOpenRelated: () => _openRelatedRecord(context, notification),
          onMarkRead: notification.isRead || _isMarkingRead
              ? null
              : _markNotificationAsRead,
        ),
      ],
    );
  }

  Future<void> _markNotificationAsRead() async {
    final repository = ref.read(notificationsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isMarkingRead = true);

    try {
      await repository.markNotificationAsRead(notification.id);

      if (!mounted) return;

      ref
        ..invalidate(notificationsProvider)
        ..invalidate(notificationDetailProvider(notification.id));

      messenger.showSnackBar(
        const SnackBar(content: Text('Notification marked as read.')),
      );
    } catch (error) {
      if (!mounted) return;

      final message = error is ApiError && error.message.trim().isNotEmpty
          ? error.message.trim()
          : error.toString().replaceFirst('ApiError:', '').trim();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty
                ? 'Could not mark this notification as read yet.'
                : message,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMarkingRead = false);
      }
    }
  }

  String _relatedActionLabel(NotificationItem notification) {
    final reference = notification.reference?.trim();
    final actionUrl = notification.actionUrl?.trim();

    if (actionUrl != null && actionUrl.isNotEmpty) {
      return 'Open notification action';
    }

    if (reference == null || reference.isEmpty) {
      return 'No related record';
    }

    switch (notification.type) {
      case AppNotificationType.documentRequest:
        return 'Open service documents';
      case AppNotificationType.serviceUpdate:
        return 'Open service case';
      case AppNotificationType.paymentAlert:
        return 'Open payment reference';
      case AppNotificationType.general:
        return 'Open related record';
    }
  }

  void _openRelatedRecord(BuildContext context, NotificationItem notification) {
    final actionUrl = notification.actionUrl?.trim();
    if (actionUrl != null && actionUrl.isNotEmpty) {
      _openActionUrl(context, actionUrl);
      return;
    }

    final reference = notification.reference?.trim();
    if (reference == null || reference.isEmpty) {
      _showBackendPendingSnack(
        context,
        'This notification does not include a related reference yet.',
      );
      return;
    }

    switch (notification.type) {
      case AppNotificationType.documentRequest:
      case AppNotificationType.serviceUpdate:
        context.push('/my-services/${Uri.encodeComponent(reference)}');
        return;
      case AppNotificationType.paymentAlert:
        context.push('/payments/${Uri.encodeComponent(reference)}');
        return;
      case AppNotificationType.general:
        _showBackendPendingSnack(
          context,
          'This notification type does not have a specific app destination yet.',
        );
        return;
    }
  }

  Future<void> _openActionUrl(BuildContext context, String url) async {
    if (url.startsWith('/')) {
      context.push(url);
      return;
    }

    final uri = _notificationUri(url);
    if (uri == null) {
      _showBackendPendingSnack(
        context,
        'Invalid notification action link received.',
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;

    if (!opened) {
      _showBackendPendingSnack(
        context,
        'Notification action could not be opened right now.',
      );
    }
  }

  Uri? _notificationUri(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    if (uri.hasScheme) {
      return uri;
    }

    if (!url.startsWith('/')) {
      return null;
    }

    final baseUri = Uri.tryParse(ApiConfig.baseUrl);
    if (baseUri == null || !baseUri.hasScheme) {
      return null;
    }

    return baseUri.resolve(url);
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

class _NotificationHeroCard extends StatelessWidget {
  const _NotificationHeroCard({
    required this.notification,
    required this.color,
    required this.icon,
  });

  final NotificationItem notification;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              top: -42,
              right: -34,
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
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
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Icon(icon, color: color, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoPill(
                              label: notification.type.label,
                              color: color,
                            ),
                            _InfoPill(
                              label: notification.isRead ? 'Read' : 'Unread',
                              color: notification.isRead
                                  ? Colors.green.shade700
                                  : AppTheme.primaryRed,
                            ),
                            if (notification.actionUrl != null)
                              const _InfoPill(label: 'Action available'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    notification.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 23,
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
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 12),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.relatedActionLabel,
    required this.isRead,
    required this.isMarkingRead,
    required this.onOpenRelated,
    required this.onMarkRead,
  });

  final String relatedActionLabel;
  final bool isRead;
  final bool isMarkingRead;
  final VoidCallback onOpenRelated;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: AppTheme.primaryRed, size: 20),
              SizedBox(width: 8),
              Text(
                'Actions',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Open the related record or update notification status.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _ActionButton(
            icon: Icons.open_in_new_rounded,
            label: relatedActionLabel,
            onTap: onOpenRelated,
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: isMarkingRead
                ? Icons.hourglass_top_rounded
                : Icons.done_all_rounded,
            label: isRead
                ? 'Already marked read'
                : isMarkingRead
                ? 'Marking as read...'
                : 'Mark as read',
            onTap: onMarkRead,
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final pillColor = color ?? AppTheme.primaryRed;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Text(
          label,
          style: TextStyle(
            color: pillColor,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: AppTheme.primaryRed, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isEnabled
              ? Colors.white
              : AppTheme.primaryRed.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.62),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(
                  alpha: isEnabled ? 0.08 : 0.04,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: isEnabled ? AppTheme.primaryRed : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isEnabled
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
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

class _NotificationDetailLoadingView extends StatelessWidget {
  const _NotificationDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: const [
        PremiumCard(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _LoadingBox(width: 58, height: 58, radius: 22),
                  SizedBox(width: 14),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _LoadingPill(width: 96),
                        _LoadingPill(width: 74),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18),
              _LoadingBar(widthFactor: 0.82, height: 17),
              SizedBox(height: 10),
              _LoadingBar(widthFactor: 0.95),
              SizedBox(height: 8),
              _LoadingBar(widthFactor: 0.68),
            ],
          ),
        ),
        SizedBox(height: 20),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _LoadingDetailTile(),
              _DividerIndent(),
              _LoadingDetailTile(),
              _DividerIndent(),
              _LoadingDetailTile(),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingDetailTile extends StatelessWidget {
  const _LoadingDetailTile();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          _LoadingBox(width: 42, height: 42, radius: 15),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LoadingBar(widthFactor: 0.35),
                SizedBox(height: 9),
                _LoadingBar(widthFactor: 0.72),
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
      height: 28,
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

class _DividerIndent extends StatelessWidget {
  const _DividerIndent();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 76);
  }
}
