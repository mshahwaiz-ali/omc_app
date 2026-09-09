import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_state.dart';
import '../../notifications/data/notifications_repository.dart';
import '../application/home_action_access.dart';
import '../data/home_dashboard_repository.dart';
import '../data/mobile_quick_actions_repository.dart';

class InternalHomeView extends ConsumerWidget {
  const InternalHomeView({
    super.key,
    required this.displayName,
    required this.avatarUrl,
    required this.summary,
    required this.quickActions,
    required this.capabilities,
    required this.loadMessage,
    required this.onRetryHomeLoad,
    required this.onOpenNotifications,
  });

  final String displayName;
  final String? avatarUrl;
  final HomeDashboardSummary summary;
  final List<MobileQuickAction> quickActions;
  final AuthCapabilities capabilities;
  final String? loadMessage;
  final VoidCallback onRetryHomeLoad;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attention = _buildAttentionItems(summary);
    final actions = _mergeInternalActions(quickActions);
    final unreadNotifications =
        ref.watch(unreadNotificationsProvider).value ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator.adaptive(
          onRefresh: () async {
            ref.invalidate(homeDashboardSummaryProvider);
            ref.invalidate(mobileQuickActionsProvider);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 150),
            children: [
              _InternalHeader(
                displayName: displayName,
                avatarUrl: avatarUrl,
                notificationCount: unreadNotifications,
                onNotifications: onOpenNotifications,
                onAvatar: () => context.push('/profile'),
              ),
              if (loadMessage != null) ...[
                const SizedBox(height: 12),
                _HomeLoadNotice(
                  message: loadMessage!,
                  onRetry: onRetryHomeLoad,
                ),
              ],
              const SizedBox(height: 18),
              _PriorityWorkSection(
                items: attention,
                onOpenWorkspace: () => context.go('/internal-workspace'),
              ),
              const SizedBox(height: 22),
              _InternalSectionHeader(
                title: 'Queue shortcuts',
                subtitle:
                    'Open the operational queues your current capabilities allow.',
                actionLabel: 'View all',
                onAction: () => context.go('/internal-workspace'),
              ),
              const SizedBox(height: 10),
              _InternalQuickActions(
                actions: actions,
                summary: summary,
                capabilities: capabilities,
                onTap: (action) =>
                    _openQuickAction(context, action, capabilities),
              ),
              const SizedBox(height: 22),
              const _InternalSectionHeader(
                title: 'Operations snapshot',
                subtitle:
                    'Compact backend totals for context after urgent work.',
              ),
              const SizedBox(height: 10),
              _OperationsSnapshot(
                summary: summary,
                capabilities: capabilities,
                onOpen: (route) => context.push(route),
              ),
              const SizedBox(height: 22),
              _InternalSectionHeader(
                title: 'Recent activity',
                subtitle: 'Latest backend operational activity.',
                actionLabel: 'Open workspace',
                onAction: () => context.go('/internal-workspace'),
              ),
              const SizedBox(height: 10),
              _RecentActivityList(
                summary: summary,
                onOpen: () => context.go('/internal-workspace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InternalHeader extends StatelessWidget {
  const _InternalHeader({
    required this.displayName,
    required this.avatarUrl,
    required this.notificationCount,
    required this.onNotifications,
    required this.onAvatar,
  });

  final String displayName;
  final String? avatarUrl;
  final int notificationCount;
  final VoidCallback onNotifications;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    final name = displayName.trim().isEmpty
        ? 'OMC operations'
        : displayName.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.4;
        final identity = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Operations',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Semantics(
              header: true,
              child: Text(
                name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Priority work first, operational totals second',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        );
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: notificationCount > 0
                  ? 'Notifications, $notificationCount unread'
                  : 'Notifications',
              child: IconButton.outlined(
                onPressed: onNotifications,
                tooltip: 'Notifications',
                icon: Badge(
                  isLabelVisible: notificationCount > 0,
                  label: Text(
                    notificationCount > 99 ? '99+' : '$notificationCount',
                  ),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _InternalAvatar(name: name, avatarUrl: avatarUrl, onTap: onAvatar),
          ],
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [identity, const SizedBox(height: 12), actions],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: identity),
            const SizedBox(width: 12),
            actions,
          ],
        );
      },
    );
  }
}

class _InternalAvatar extends StatelessWidget {
  const _InternalAvatar({
    required this.name,
    required this.avatarUrl,
    required this.onTap,
  });

  final String name;
  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = avatarUrl?.trim();
    final initial = name.trim().isEmpty ? 'O' : name.trim()[0].toUpperCase();

    return Semantics(
      button: true,
      label: 'Profile',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primarySoft,
            border: Border.all(color: AppTheme.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: cleanUrl == null || cleanUrl.isEmpty
              ? Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : Image.network(
                  cleanUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _PriorityWorkSection extends StatelessWidget {
  const _PriorityWorkSection({
    required this.items,
    required this.onOpenWorkspace,
  });

  final List<_AttentionItem> items;
  final VoidCallback onOpenWorkspace;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InternalSectionHeader(
          title: 'Needs attention',
          subtitle: items.isEmpty
              ? 'No urgent backend work is currently surfaced.'
              : 'Financial holds and activation failures are shown before routine review queues.',
          actionLabel: 'Workspace',
          onAction: onOpenWorkspace,
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const PremiumCard(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OmcIconBadge(
                  icon: Icons.check_circle_outline_rounded,
                  color: AppTheme.success,
                  size: 42,
                  iconSize: 21,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No urgent operational item is currently reported by the Home dashboard.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (var index = 0; index < items.length; index++) ...[
            _AttentionCard(item: items[index]),
            if (index != items.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.item});

  final _AttentionItem item;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      semanticLabel: '${item.title}. ${item.subtitle}',
      semanticHint: 'Open operational item',
      onTap: () => context.push(item.route),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OmcIconBadge(
              icon: item.icon,
              color: item.color,
              size: 44,
              iconSize: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InternalQuickActions extends StatelessWidget {
  const _InternalQuickActions({
    required this.actions,
    required this.summary,
    required this.capabilities,
    required this.onTap,
  });

  final List<MobileQuickAction> actions;
  final HomeDashboardSummary summary;
  final AuthCapabilities capabilities;
  final ValueChanged<MobileQuickAction> onTap;

  @override
  Widget build(BuildContext context) {
    final visible = actions
        .where(
          (action) => canUseHomeActionCapability(
            action.requiredCapability,
            capabilities,
            allowWithoutRequirement: false,
          ),
        )
        .take(5)
        .toList(growable: false);

    if (visible.isEmpty) {
      return const PremiumCard(
        padding: EdgeInsets.all(16),
        child: Text(
          'No operational shortcuts are available for the current capability set.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final singleColumn = constraints.maxWidth < 330 || textScale >= 1.5;
        final tileWidth = singleColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final action in visible)
              Builder(
                builder: (context) {
                  final count = _actionCount(action, summary);
                  return SizedBox(
                    width: tileWidth,
                    child: PremiumCard(
                      padding: EdgeInsets.zero,
                      onTap: () => onTap(action),
                      semanticLabel:
                          '${action.title}${count == null ? '' : ', $count items'}',
                      semanticHint: 'Open operational queue',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 72),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OmcIconBadge(
                                icon: _actionIcon(action.iconKey),
                                color: _actionColor(action.iconKey),
                                size: 42,
                                iconSize: 21,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      action.title,
                                      softWrap: true,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 15,
                                        height: 1.25,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (count != null) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        '$count items',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppTheme.textSecondary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _OperationsSnapshot extends StatelessWidget {
  const _OperationsSnapshot({
    required this.summary,
    required this.capabilities,
    required this.onOpen,
  });

  final HomeDashboardSummary summary;
  final AuthCapabilities capabilities;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final operations = summary.operationsSummary;
    final metrics = <_Metric>[
      _Metric(
        label: 'Active services',
        value: operations.activeServices,
        icon: Icons.work_outline_rounded,
        route: '/internal-workspace',
        requiredCapability: 'can_access_internal_workspace',
      ),
      _Metric(
        label: 'Docs to review',
        value: operations.documentsWaitingReview,
        icon: Icons.fact_check_outlined,
        route: '/internal-workspace/documents',
        requiredCapability: 'can_review_documents',
      ),
      _Metric(
        label: 'Pending payments',
        value: operations.pendingPayments,
        icon: Icons.payments_outlined,
        route: '/internal-workspace/payments',
        requiredCapability: 'can_review_payments',
      ),
      _Metric(
        label: 'Pending tasks',
        value: operations.pendingTasks,
        icon: Icons.task_alt_outlined,
        route: '/tasks',
        requiredCapability: 'can_manage_tasks',
      ),
    ];

    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var index = 0; index < metrics.length; index++) ...[
            _MetricRow(
              metric: metrics[index],
              available: canUseHomeActionCapability(
                metrics[index].requiredCapability,
                capabilities,
                allowWithoutRequirement: false,
              ),
              onOpen: onOpen,
            ),
            if (index != metrics.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.metric,
    required this.available,
    required this.onOpen,
  });

  final _Metric metric;
  final bool available;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Icon(metric.icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  available
                      ? metric.value == 0
                            ? '0 items'
                            : '${metric.value} items'
                      : 'Not available for this role',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (available)
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
        ],
      ),
    );

    if (!available) return child;
    return InkWell(onTap: () => onOpen(metric.route), child: child);
  }
}

class _RecentActivityList extends StatelessWidget {
  const _RecentActivityList({required this.summary, required this.onOpen});

  final HomeDashboardSummary summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final activities = summary.recentActivity.take(6).toList(growable: false);
    if (activities.isEmpty) {
      return const PremiumCard(
        padding: EdgeInsets.all(16),
        child: Text(
          'No recent operational activity is available from the dashboard.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      );
    }

    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var index = 0; index < activities.length; index++) ...[
            _ActivityRow(activity: activities[index], onTap: onOpen),
            if (index != activities.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, required this.onTap});

  final HomeDashboardActivity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = activity.subtitle.trim();
    final status = activity.status?.trim() ?? '';
    final time = activity.createdAtLabel?.trim() ?? '';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.history_rounded,
                size: 20,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title.trim().isEmpty
                        ? 'Operational activity'
                        : activity.title.trim(),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (status.isNotEmpty || time.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (status.isNotEmpty)
                          Text(
                            status,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (time.isNotEmpty)
                          Text(
                            time,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ],
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
    );
  }
}

class _InternalSectionHeader extends StatelessWidget {
  const _InternalSectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 330 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.5;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 21,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],
          ],
        );
        if (actionLabel == null || onAction == null) return text;
        final action = TextButton(
          onPressed: onAction,
          child: Text(actionLabel!),
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 6), action],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: text),
            const SizedBox(width: 12),
            action,
          ],
        );
      },
    );
  }
}

class _HomeLoadNotice extends StatelessWidget {
  const _HomeLoadNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack =
              constraints.maxWidth < 330 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.5;
          final body = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppTheme.warning,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          );
          final retry = TextButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          );
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [body, const SizedBox(height: 8), retry],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: body),
              const SizedBox(width: 8),
              retry,
            ],
          );
        },
      ),
    );
  }
}

List<_AttentionItem> _buildAttentionItems(HomeDashboardSummary summary) {
  final critical = <_AttentionItem>[];
  final routine = <_AttentionItem>[];

  for (final service in summary.serviceSnapshots) {
    final requestId = service.id.trim();
    if (requestId.isEmpty) continue;
    final route =
        '/internal-workspace/service-cases/${Uri.encodeComponent(requestId)}';
    final lifecycle = service.lifecycleState.trim().toLowerCase();
    final operational = service.effectiveOperationalStatus.trim().toLowerCase();
    final title = service.customerName.trim().isNotEmpty
        ? service.customerName.trim()
        : service.title.trim().isEmpty
        ? 'OMC service request'
        : service.title.trim();

    if (lifecycle == 'financial hold') {
      critical.add(
        _AttentionItem(
          title: title,
          subtitle:
              'Financial hold requires internal review before work can continue.',
          icon: Icons.account_balance_wallet_outlined,
          color: AppTheme.danger,
          route: route,
        ),
      );
      continue;
    }

    if (lifecycle == 'activation failed') {
      critical.add(
        _AttentionItem(
          title: title,
          subtitle: 'Activation failed and requires operational recovery.',
          icon: Icons.sync_problem_rounded,
          color: AppTheme.danger,
          route: route,
        ),
      );
      continue;
    }

    if (service.documentSummary.missing > 0 ||
        service.documentSummary.underReview > 0) {
      final count = service.documentSummary.missing > 0
          ? service.documentSummary.missing
          : service.documentSummary.underReview;
      routine.add(
        _AttentionItem(
          title: title,
          subtitle: service.documentSummary.missing > 0
              ? '$count missing ${count == 1 ? 'document' : 'documents'}'
              : '$count ${count == 1 ? 'document is' : 'documents are'} awaiting review',
          icon: Icons.description_outlined,
          color: AppTheme.warning,
          route: route,
        ),
      );
      continue;
    }

    final paymentNeedsReview =
        service.paymentSummary.receiptSubmitted +
        service.paymentSummary.underReview +
        service.paymentSummary.receiptUnderReview;
    if (paymentNeedsReview > 0) {
      routine.add(
        _AttentionItem(
          title: title,
          subtitle: 'Payment receipt awaiting review.',
          icon: Icons.payments_outlined,
          color: AppTheme.warning,
          route: route,
        ),
      );
      continue;
    }

    if (lifecycle == 'pending payment' ||
        operational.contains('overdue') ||
        operational.contains('pending') ||
        operational.contains('waiting') ||
        operational.contains('review')) {
      routine.add(
        _AttentionItem(
          title: title,
          subtitle: service.statusLabel.trim().isEmpty
              ? 'Request needs attention.'
              : service.statusLabel.trim(),
          icon: Icons.assignment_turned_in_outlined,
          color: AppTheme.info,
          route: route,
        ),
      );
    }
  }

  return [...critical, ...routine].take(3).toList(growable: false);
}

List<MobileQuickAction> _mergeInternalActions(
  List<MobileQuickAction> backendActions,
) {
  const fallbacks = <MobileQuickAction>[
    MobileQuickAction(
      id: 'internal-documents',
      title: 'Review Documents',
      subtitle: 'Awaiting review',
      iconKey: 'documents',
      targetType: MobileQuickActionTargetType.route,
      targetValue: '/internal-workspace/documents',
      requiredCapability: 'can_review_documents',
      badgeType: 'documents',
      sortOrder: 10,
    ),
    MobileQuickAction(
      id: 'internal-payments',
      title: 'Review Payments',
      subtitle: 'Pending review',
      iconKey: 'payments',
      targetType: MobileQuickActionTargetType.route,
      targetValue: '/internal-workspace/payments',
      requiredCapability: 'can_review_payments',
      badgeType: 'payments',
      sortOrder: 20,
    ),
    MobileQuickAction(
      id: 'internal-customers',
      title: 'Customers',
      subtitle: 'View customers',
      iconKey: 'dashboard',
      targetType: MobileQuickActionTargetType.route,
      targetValue: '/internal-workspace/customers',
      requiredCapability: 'can_manage_customers',
      badgeType: 'customers',
      sortOrder: 30,
    ),
    MobileQuickAction(
      id: 'internal-leads',
      title: 'Leads',
      subtitle: 'Pipeline',
      iconKey: 'leads',
      targetType: MobileQuickActionTargetType.route,
      targetValue: '/leads',
      requiredCapability: 'can_manage_leads',
      badgeType: 'leads',
      sortOrder: 40,
    ),
    MobileQuickAction(
      id: 'internal-tasks',
      title: 'Tasks',
      subtitle: 'Due today',
      iconKey: 'tasks',
      targetType: MobileQuickActionTargetType.route,
      targetValue: '/tasks',
      requiredCapability: 'can_manage_tasks',
      badgeType: 'tasks',
      sortOrder: 50,
    ),
  ];

  final result = <MobileQuickAction>[];
  final identities = <String>{};

  String identity(MobileQuickAction action) {
    final target = action.targetValue.trim().toLowerCase().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    if (target.isNotEmpty) return target;
    return action.title.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
  }

  final sortedBackend = [...backendActions]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  for (final action in [...sortedBackend, ...fallbacks]) {
    if (!_looksInternal(action)) continue;
    final key = identity(action);
    if (key.isEmpty || !identities.add(key)) continue;
    result.add(action);
  }

  return result.take(5).toList(growable: false);
}

bool _looksInternal(MobileQuickAction action) {
  final haystack = [
    action.id,
    action.title,
    action.targetValue,
    action.requiredCapability ?? '',
  ].join(' ').toLowerCase();

  return haystack.contains('internal') ||
      haystack.contains('document') ||
      haystack.contains('payment') ||
      haystack.contains('customer') ||
      haystack.contains('lead') ||
      haystack.contains('task');
}

void _openQuickAction(
  BuildContext context,
  MobileQuickAction action,
  AuthCapabilities capabilities,
) {
  if (!canUseHomeActionCapability(
    action.requiredCapability,
    capabilities,
    allowWithoutRequirement: false,
  )) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You do not have access to this internal action.'),
      ),
    );
    return;
  }

  final target = action.targetValue.trim();
  if (target.isEmpty) return;

  if (action.targetType == MobileQuickActionTargetType.route) {
    final route = target.startsWith('/') ? target : '/$target';
    context.push(route);
    return;
  }

  if (action.targetType == MobileQuickActionTargetType.feature) {
    switch (target.toLowerCase()) {
      case 'documents':
        context.push('/internal-workspace/documents');
        return;
      case 'payments':
        context.push('/internal-workspace/payments');
        return;
      case 'customers':
        context.push('/internal-workspace/customers');
        return;
      case 'leads':
        context.push('/leads');
        return;
      case 'tasks':
        context.push('/tasks');
        return;
      default:
        context.go('/internal-workspace');
        return;
    }
  }

  context.go('/internal-workspace');
}

int? _actionCount(MobileQuickAction action, HomeDashboardSummary summary) {
  final text = '${action.title} ${action.targetValue}'.toLowerCase();
  final operations = summary.operationsSummary;
  if (text.contains('document')) return operations.documentsWaitingReview;
  if (text.contains('payment')) return operations.pendingPayments;
  if (text.contains('task')) return operations.pendingTasks;
  if (text.contains('service') || text.contains('case')) {
    return operations.activeServices;
  }
  if (text.contains('lead')) return operations.openLeads;
  return null;
}

IconData _actionIcon(String key) {
  final normalized = key.trim().toLowerCase();
  if (normalized.contains('document')) return Icons.description_outlined;
  if (normalized.contains('payment')) return Icons.payments_outlined;
  if (normalized.contains('task')) return Icons.task_alt_outlined;
  if (normalized.contains('lead')) return Icons.trending_up_rounded;
  if (normalized.contains('customer')) return Icons.people_outline_rounded;
  return Icons.dashboard_outlined;
}

Color _actionColor(String key) {
  final normalized = key.trim().toLowerCase();
  if (normalized.contains('document')) return AppTheme.info;
  if (normalized.contains('payment')) return AppTheme.warning;
  if (normalized.contains('task')) return AppTheme.success;
  if (normalized.contains('lead')) return AppTheme.danger;
  return AppTheme.textSecondary;
}

class _AttentionItem {
  const _AttentionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
}

class _Metric {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.route,
    required this.requiredCapability,
  });

  final String label;
  final int value;
  final IconData icon;
  final String route;
  final String requiredCapability;
}
