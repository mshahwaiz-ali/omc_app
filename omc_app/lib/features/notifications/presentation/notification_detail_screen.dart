import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../internal_workspace/presentation/internal_workspace_providers.dart';
import '../../payments/data/payments_repository.dart';
import '../../service_requests/data/service_case_repository.dart';
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
      appBar: const AppBackHeader(title: 'Alert details'),
      body: SafeArea(
        top: false,
        child: notificationAsync.when(
          data: (notification) {
            if (notification == null) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: AppEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'Alert unavailable',
                  message:
                      'This alert may have been removed or is no longer available.',
                ),
              );
            }

            return _NotificationDetailBody(notification: notification);
          },
          loading: () => const _NotificationDetailLoadingView(),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: AppErrorState.fromError(
              error: error,
              fallbackTitle: 'Alert unavailable',
              fallbackMessage:
                  'Alert details could not be loaded right now. Please try again.',
              onRetry: () =>
                  ref.invalidate(notificationDetailProvider(notificationId)),
            ),
          ),
        ),
      ),
    );
  }
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
  bool _autoReadQueued = false;

  NotificationItem get notification => widget.notification;

  @override
  void initState() {
    super.initState();
    _queueAutoMarkAsRead();
  }

  @override
  void didUpdateWidget(covariant _NotificationDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notification.id != widget.notification.id ||
        oldWidget.notification.isRead != widget.notification.isRead) {
      _autoReadQueued = false;
      _queueAutoMarkAsRead();
    }
  }

  void _queueAutoMarkAsRead() {
    if (_autoReadQueued || notification.isRead) return;
    _autoReadQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || notification.isRead) return;
      _markNotificationAsRead(showSnack: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(notification.type);
    final relatedAction = _relatedActionLabel(notification);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OmcStatusBadge(
                    label: notification.type.label,
                    color: color,
                    icon: _typeIcon(notification.type),
                  ),
                  OmcStatusBadge(
                    label: notification.isRead ? 'Read' : 'Unread',
                    color: notification.isRead
                        ? AppTheme.textSecondary
                        : AppTheme.info,
                    icon: notification.isRead
                        ? Icons.done_rounded
                        : Icons.circle_notifications_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  notification.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 21,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                notification.message,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PremiumCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Alert information',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _DetailRow(
                label: 'Reference',
                value: notification.reference ?? 'Not available',
              ),
              _DetailRow(
                label: 'Created',
                value: notification.createdAtLabel ?? 'Not available',
              ),
              _DetailRow(
                label: 'Action',
                value: notification.actionUrl == null
                    ? 'Related record routing'
                    : 'Action link available',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PremiumCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Related action',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _relatedActionDescription(notification),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _openRelatedRecord(context, notification),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(relatedAction),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _markNotificationAsRead({bool showSnack = true}) async {
    if (_isMarkingRead || notification.isRead) return;

    final repository = ref.read(notificationsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isMarkingRead = true);

    try {
      await repository.markNotificationAsRead(notification.id);

      if (!mounted) return;

      ref
        ..invalidate(notificationsProvider)
        ..invalidate(notificationDetailProvider(notification.id));

      if (showSnack) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Notification marked as read.')),
        );
      }
    } catch (error) {
      if (!mounted || !showSnack) return;

      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Read status not updated',
        fallbackMessage: 'Could not mark this notification as read yet.',
      );
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
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
      case AppNotificationType.taskUpdate:
        return 'Open task';
      case AppNotificationType.general:
        return 'Open related record';
    }
  }

  String _relatedActionDescription(NotificationItem notification) {
    if (notification.actionUrl?.trim().isNotEmpty == true) {
      return 'Open the destination supplied with this alert. Internal destinations are restricted to approved app routes; external links are limited to web URLs.';
    }
    if (notification.reference?.trim().isEmpty ?? true) {
      return 'This alert does not currently include a related record reference.';
    }
    return 'Open the app record associated with this alert using its existing reference.';
  }

  void _openRelatedRecord(BuildContext context, NotificationItem notification) {
    _invalidateRelatedState(notification);

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
      case AppNotificationType.taskUpdate:
        context.push('/tasks/${Uri.encodeComponent(reference)}');
        return;
      case AppNotificationType.general:
        _showBackendPendingSnack(
          context,
          'This notification type does not have a specific app destination yet.',
        );
        return;
    }
  }

  void _invalidateRelatedState(NotificationItem notification) {
    ref
      ..invalidate(notificationsProvider)
      ..invalidate(paymentsProvider)
      ..invalidate(serviceCasesProvider)
      ..invalidate(internalServiceCasesProvider);

    final reference = notification.reference?.trim();
    if (reference == null || reference.isEmpty) return;

    switch (notification.type) {
      case AppNotificationType.paymentAlert:
        ref.invalidate(paymentDetailProvider(reference));
        break;
      case AppNotificationType.documentRequest:
      case AppNotificationType.serviceUpdate:
        ref.invalidate(serviceCaseDetailProvider(reference));
        break;
      case AppNotificationType.taskUpdate:
        break;
      case AppNotificationType.general:
        break;
    }
  }

  Future<void> _openActionUrl(BuildContext context, String url) async {
    if (url.startsWith('/')) {
      final destination = _safeInternalDestination(url);
      if (destination == null) {
        _showBackendPendingSnack(
          context,
          'This notification action is not supported in the app.',
        );
        return;
      }
      context.push(destination);
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

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!context.mounted) return;

      if (!opened) {
        _showBackendPendingSnack(
          context,
          'Notification action could not be opened right now.',
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Notification action unavailable',
        fallbackMessage: 'Notification action could not be opened right now.',
      );
      _showBackendPendingSnack(context, failure.message);
    }
  }

  Uri? _notificationUri(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    if (uri.hasScheme) {
      return _isAllowedExternalScheme(uri.scheme) ? uri : null;
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

  String? _safeInternalDestination(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isNotEmpty || uri.scheme.isNotEmpty) {
      return null;
    }

    const allowedPrefixes = <String>[
      '/my-services/',
      '/payments/',
      '/documents/',
      '/notifications/',
      '/services/',
      '/support',
      '/tasks/',
      '/my-commissions/',
    ];
    return allowedPrefixes.any(uri.path.startsWith) ? uri.toString() : null;
  }

  bool _isAllowedExternalScheme(String scheme) {
    final normalized = scheme.toLowerCase();
    return normalized == 'https' || normalized == 'http';
  }

  void _showBackendPendingSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Color _typeColor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.documentRequest:
        return AppTheme.warning;
      case AppNotificationType.paymentAlert:
        return AppTheme.success;
      case AppNotificationType.serviceUpdate:
        return AppTheme.info;
      case AppNotificationType.taskUpdate:
        return AppTheme.info;
      case AppNotificationType.general:
        return AppTheme.textSecondary;
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
      case AppNotificationType.taskUpdate:
        return Icons.task_alt_outlined;
      case AppNotificationType.general:
        return Icons.notifications_none_rounded;
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack =
              constraints.maxWidth < 330 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.4;
          final labelWidget = Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          );
          final valueWidget = Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          );

          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 4), valueWidget],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 90, child: labelWidget),
              const SizedBox(width: 12),
              Expanded(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationDetailLoadingView extends StatelessWidget {
  const _NotificationDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const SizedBox.square(
                dimension: 46,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Loading alert details...',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
