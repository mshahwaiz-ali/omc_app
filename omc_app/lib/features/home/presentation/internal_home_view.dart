import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_state.dart';
import '../data/home_dashboard_repository.dart';
import '../data/mobile_quick_actions_repository.dart';
import '../application/home_action_access.dart';

const Color _omcRed = Color(0xFFE50924);
const Color _ink = Color(0xFF111827);
const Color _muted = Color(0xFF667085);
const Color _border = Color(0xFFE8EAF0);
const Color _surface = Color(0xFFFFFFFF);
const Color _pageBackground = Color(0xFFF8F9FC);

class InternalHomeView extends ConsumerWidget {
  const InternalHomeView({
    super.key,
    required this.displayName,
    required this.avatarUrl,
    required this.summary,
    required this.quickActions,
    required this.capabilities,
    required this.onOpenNotifications,
  });

  final String displayName;
  final String? avatarUrl;
  final HomeDashboardSummary summary;
  final List<MobileQuickAction> quickActions;
  final AuthCapabilities capabilities;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operations = summary.operationsSummary;
    final needsAttention = _buildAttentionItems(summary);
    final actions = _mergeInternalActions(quickActions);

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator.adaptive(
          onRefresh: () async {
            ref.invalidate(homeDashboardSummaryProvider);
            ref.invalidate(mobileQuickActionsProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _Header(
                    displayName: displayName,
                    avatarUrl: avatarUrl,
                    notificationCount: summary.unreadNotifications,
                    onNotifications: onOpenNotifications,
                    onAvatar: () => context.push('/profile'),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _OperationsHero(
                    summary: summary,
                    onOpen: () => context.go('/internal-workspace'),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionCard(
                    title: 'Quick actions',
                    actionLabel: 'View all',
                    onAction: () => context.go('/internal-workspace'),
                    child: _QuickActions(
                      actions: actions,
                      summary: summary,
                      capabilities: capabilities,
                      onTap: (action) =>
                          _openQuickAction(context, action, capabilities),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionCard(
                    title: 'Needs attention',
                    actionLabel: 'View all',
                    onAction: () => context.go('/internal-workspace'),
                    child: needsAttention.isEmpty
                        ? const _EmptyState(
                            icon: Icons.task_alt_rounded,
                            title: 'Nothing needs immediate attention',
                            message:
                                'New document, payment and task items will appear here.',
                          )
                        : _AttentionList(
                            items: needsAttention,
                            onTap: (item) => context.push(item.route),
                          ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionCard(
                    title: 'Operations at a glance',
                    child: _OperationsGrid(
                      items: [
                        _MetricItem(
                          value: operations.activeServices,
                          label: 'Active Requests',
                          icon: Icons.trending_up_rounded,
                          accent: _omcRed,
                          route: '/internal-workspace',
                        ),
                        _MetricItem(
                          value: operations.documentsWaitingReview,
                          label: 'Documents Awaiting',
                          icon: Icons.description_outlined,
                          accent: const Color(0xFFE11D48),
                          route: '/internal-workspace/documents',
                        ),
                        _MetricItem(
                          value: operations.pendingPayments,
                          label: 'Payments Pending',
                          icon: Icons.account_balance_wallet_outlined,
                          accent: const Color(0xFFF97316),
                          route: '/internal-workspace/payments',
                        ),
                        _MetricItem(
                          value: operations.pendingTasks,
                          label: 'Tasks Due Today',
                          icon: Icons.task_alt_outlined,
                          accent: const Color(0xFF16A34A),
                          route: '/tasks',
                        ),
                      ],
                      onTap: (item) => context.push(item.route),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: _SectionCard(
                    title: 'Recent activity',
                    actionLabel: 'View all',
                    onAction: () => context.go('/internal-workspace'),
                    child: summary.recentActivity.isEmpty
                        ? const _EmptyState(
                            icon: Icons.history_rounded,
                            title: 'No recent activity',
                            message:
                                'Backend activity will appear here when available.',
                          )
                        : _RecentActivityList(
                            activities: summary.recentActivity
                                .take(6)
                                .toList(growable: false),
                            onTap: () => context.go('/internal-workspace'),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_AttentionItem> _buildAttentionItems(HomeDashboardSummary summary) {
    final result = <_AttentionItem>[];

    for (final service in summary.serviceSnapshots.take(5)) {
      final id = service.id.trim();
      if (id.isEmpty) continue;

      final route =
          '/internal-workspace/service-cases/${Uri.encodeComponent(id)}';

      if (service.documentSummary.missing > 0 ||
          service.documentSummary.underReview > 0) {
        final count = service.documentSummary.missing > 0
            ? service.documentSummary.missing
            : service.documentSummary.underReview;

        result.add(
          _AttentionItem(
            title: service.customerName.trim().isNotEmpty
                ? service.customerName.trim()
                : service.title,
            subtitle: service.title,
            reference: id,
            message: service.documentSummary.missing > 0
                ? '$count missing ${count == 1 ? 'document' : 'documents'}'
                : '$count ${count == 1 ? 'document' : 'documents'} awaiting review',
            statusLabel: 'Review',
            icon: Icons.description_outlined,
            accent: const Color(0xFFE11D48),
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
        result.add(
          _AttentionItem(
            title: service.customerName.trim().isNotEmpty
                ? service.customerName.trim()
                : service.title,
            subtitle: service.title,
            reference: id,
            message: 'Payment receipt awaiting review',
            statusLabel: 'Review',
            icon: Icons.account_balance_wallet_outlined,
            accent: const Color(0xFFF97316),
            route: route,
          ),
        );
        continue;
      }

      final status = service.status.trim().toLowerCase();
      if (status.contains('overdue') ||
          status.contains('pending') ||
          status.contains('waiting')) {
        result.add(
          _AttentionItem(
            title: service.customerName.trim().isNotEmpty
                ? service.customerName.trim()
                : service.title,
            subtitle: service.title,
            reference: id,
            message: service.status.trim().isEmpty
                ? 'Request needs attention'
                : service.status.trim(),
            statusLabel: 'Open',
            icon: Icons.assignment_turned_in_outlined,
            accent: const Color(0xFF16A34A),
            route: route,
          ),
        );
      }
    }

    return result.take(3).toList(growable: false);
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
        subtitle: 'Active',
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
    if (!_hasCapability(capabilities, action.requiredCapability)) {
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
        case 'payments':
          context.push('/internal-workspace/payments');
        case 'customers':
          context.push('/internal-workspace/customers');
        case 'leads':
          context.push('/leads');
        case 'tasks':
          context.push('/tasks');
        default:
          context.go('/internal-workspace');
      }
      return;
    }

    context.go('/internal-workspace');
  }

  bool _hasCapability(AuthCapabilities capabilities, String? capability) {
    return canUseHomeActionCapability(
      capability,
      capabilities,
      allowWithoutRequirement: false,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
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
    final firstName = displayName.trim().isEmpty
        ? 'Admin'
        : displayName.trim().split(RegExp(r'\s+')).first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning, $firstName 👋',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Welcome to OMC Operations Hub',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _ink,
                  fontSize: 26,
                  height: 1.14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Here’s what’s happening today',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _NotificationButton(count: notificationCount, onTap: onNotifications),
        const SizedBox(width: 12),
        InkWell(
          onTap: onAvatar,
          customBorder: const CircleBorder(),
          child: _Avatar(url: avatarUrl, name: displayName),
        ),
      ],
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A101828),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: _ink,
                size: 27,
              ),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            right: -4,
            top: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _omcRed,
                shape: count > 9 ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: count > 9 ? BorderRadius.circular(11) : null,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = url?.trim();
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD9DCE4)),
        color: Colors.white,
      ),
      child: ClipOval(
        child: cleanUrl != null && cleanUrl.isNotEmpty
            ? Image.network(
                cleanUrl,
                fit: BoxFit.cover,
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                errorBuilder: (_, _, _) => _InitialsAvatar(initials: initials),
              )
            : _InitialsAvatar(initials: initials),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDECEF),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? 'A' : initials,
        style: const TextStyle(
          color: _omcRed,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      ),
    );
  }
}

class _OperationsHero extends StatelessWidget {
  const _OperationsHero({required this.summary, required this.onOpen});

  final HomeDashboardSummary summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final operations = summary.operationsSummary;
    final documents = operations.documentsWaitingReview;
    final payments = operations.pendingPayments;
    final tasks = operations.pendingTasks;
    final attentionTotal = documents + payments + tasks;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4F5), Color(0xFFFFF8F0)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD9DE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0AE50924),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;

              final overview = Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFA5D73), _omcRed],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.track_changes_rounded,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                  const SizedBox(width: 17),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operations overview',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: _ink,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$attentionTotal',
                                style: const TextStyle(
                                  color: _omcRed,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(
                                text: ' items need attention today',
                              ),
                            ],
                          ),
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final button = FilledButton.icon(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: _omcRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text(
                  'Open Operations Hub',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    overview,
                    const SizedBox(height: 16),
                    SizedBox(height: 48, child: button),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: overview),
                  const SizedBox(width: 18),
                  Flexible(child: button),
                ],
              );
            },
          ),
          const SizedBox(height: 21),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  icon: Icons.description_outlined,
                  value: documents,
                  label: 'Document Reviews',
                  accent: const Color(0xFFE11D48),
                ),
              ),
              const _VerticalDivider(),
              Expanded(
                child: _HeroMetric(
                  icon: Icons.account_balance_wallet_outlined,
                  value: payments,
                  label: 'Payment Reviews',
                  accent: const Color(0xFFF97316),
                ),
              ),
              const _VerticalDivider(),
              Expanded(
                child: _HeroMetric(
                  icon: Icons.check_circle_outline_rounded,
                  value: tasks,
                  label: 'Pending Tasks',
                  accent: _omcRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: accent, size: 25),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFFF1DDE0),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0F1F4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08101828),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 17, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton(
                    onPressed: onAction,
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(
                        color: _omcRed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
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
    if (actions.isEmpty) {
      return const _EmptyState(
        icon: Icons.dashboard_customize_outlined,
        title: 'No internal actions available',
        message: 'Actions enabled for this role will appear here.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final count = constraints.maxWidth >= 760 ? 5 : 3;
        final width = (constraints.maxWidth - (spacing * (count - 1))) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions
              .map((action) {
                final visual = _actionVisual(action);
                final badge = _badgeForAction(action, summary);
                final allowed = _isAllowed(action, capabilities);

                return SizedBox(
                  width: width.clamp(124.0, 190.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTap(action),
                      borderRadius: BorderRadius.circular(17),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 150),
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 13),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 55,
                                  height: 55,
                                  decoration: BoxDecoration(
                                    color: visual.soft,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    visual.icon,
                                    color: visual.accent,
                                    size: 29,
                                  ),
                                ),
                                if (badge > 0)
                                  Positioned(
                                    right: -8,
                                    top: -8,
                                    child: _CountBadge(count: badge),
                                  ),
                                if (!allowed)
                                  const Positioned(
                                    right: -7,
                                    bottom: -7,
                                    child: _LockBadge(),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 11),
                            Text(
                              action.title,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 14,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              _actionSubtitle(action, summary, badge),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: visual.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }

  int _badgeForAction(MobileQuickAction action, HomeDashboardSummary summary) {
    final key =
        '${action.badgeType} ${action.id} ${action.title} ${action.targetValue}'
            .toLowerCase();
    final operations = summary.operationsSummary;

    if (key.contains('document')) return operations.documentsWaitingReview;
    if (key.contains('payment')) return operations.pendingPayments;
    if (key.contains('customer')) return operations.activeCustomers;
    if (key.contains('lead')) return operations.openLeads;
    if (key.contains('task')) return operations.pendingTasks;

    return 0;
  }

  String _actionSubtitle(
    MobileQuickAction action,
    HomeDashboardSummary summary,
    int badge,
  ) {
    final key = '${action.id} ${action.title}'.toLowerCase();

    if (key.contains('document')) return '$badge pending';
    if (key.contains('payment')) return '$badge pending';
    if (key.contains('customer')) return '$badge active';
    if (key.contains('lead')) return '$badge open';
    if (key.contains('task')) return '$badge due';

    return action.subtitle;
  }

  bool _isAllowed(MobileQuickAction action, AuthCapabilities capabilities) {
    return canUseHomeActionCapability(
      action.requiredCapability,
      capabilities,
      allowWithoutRequirement: false,
    );
  }
}

class _AttentionList extends StatelessWidget {
  const _AttentionList({required this.items, required this.onTap});

  final List<_AttentionItem> items;
  final ValueChanged<_AttentionItem> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _AttentionRow(item: items[index], onTap: () => onTap(items[index])),
          if (index != items.length - 1)
            const Divider(height: 1, indent: 72, color: _border),
        ],
      ],
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item, required this.onTap});

  final _AttentionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: item.accent.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        item.subtitle,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEFF1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item.reference,
                          style: const TextStyle(
                            color: _omcRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                item.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: item.message.toLowerCase().contains('overdue')
                      ? _omcRed
                      : _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: item.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined, color: item.accent, size: 17),
                  const SizedBox(width: 6),
                  Text(
                    item.statusLabel,
                    style: TextStyle(
                      color: item.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: _ink),
          ],
        ),
      ),
    );
  }
}

class _OperationsGrid extends StatelessWidget {
  const _OperationsGrid({required this.items, required this.onTap});

  final List<_MetricItem> items;
  final ValueChanged<_MetricItem> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = constraints.maxWidth >= 700 ? 4 : 2;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: InkWell(
                    onTap: () => onTap(item),
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.value}',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 11),
                          Row(
                            children: [
                              Icon(item.icon, size: 16, color: item.accent),
                              const SizedBox(width: 5),
                              Text(
                                'Live backend total',
                                style: TextStyle(
                                  color: item.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  const _RecentActivityList({required this.activities, required this.onTap});

  final List<HomeDashboardActivity> activities;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < activities.length; index++) ...[
          _ActivityRow(activity: activities[index], onTap: onTap),
          if (index != activities.length - 1)
            const Divider(height: 1, indent: 52, color: _border),
        ],
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, required this.onTap});

  final HomeDashboardActivity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _activityVisual(activity);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: visual.soft,
                shape: BoxShape.circle,
              ),
              child: Icon(visual.icon, color: visual.accent, size: 20),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (activity.subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      activity.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            if (activity.createdAtLabel?.trim().isNotEmpty ?? false) ...[
              const SizedBox(width: 12),
              Text(
                activity.createdAtLabel!.trim(),
                style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFF7F8FA),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _muted),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _omcRed,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFF475467),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.lock_rounded, color: Colors.white, size: 11),
    );
  }
}

class _AttentionItem {
  const _AttentionItem({
    required this.title,
    required this.subtitle,
    required this.reference,
    required this.message,
    required this.statusLabel,
    required this.icon,
    required this.accent,
    required this.route,
  });

  final String title;
  final String subtitle;
  final String reference;
  final String message;
  final String statusLabel;
  final IconData icon;
  final Color accent;
  final String route;
}

class _MetricItem {
  const _MetricItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    required this.route,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color accent;
  final String route;
}

class _Visual {
  const _Visual({required this.icon, required this.accent, required this.soft});

  final IconData icon;
  final Color accent;
  final Color soft;
}

_Visual _actionVisual(MobileQuickAction action) {
  final key =
      '${action.iconKey} ${action.title} ${action.id} ${action.targetValue}'
          .toLowerCase();

  if (key.contains('document')) {
    return const _Visual(
      icon: Icons.description_outlined,
      accent: Color(0xFFE11D48),
      soft: Color(0xFFFFEEF1),
    );
  }
  if (key.contains('payment')) {
    return const _Visual(
      icon: Icons.account_balance_wallet_outlined,
      accent: Color(0xFFF97316),
      soft: Color(0xFFFFF2E8),
    );
  }
  if (key.contains('customer')) {
    return const _Visual(
      icon: Icons.groups_2_outlined,
      accent: Color(0xFF4263EB),
      soft: Color(0xFFEEF2FF),
    );
  }
  if (key.contains('lead')) {
    return const _Visual(
      icon: Icons.person_add_alt_1_outlined,
      accent: Color(0xFF15803D),
      soft: Color(0xFFEDF9F0),
    );
  }
  if (key.contains('task')) {
    return const _Visual(
      icon: Icons.assignment_outlined,
      accent: Color(0xFF9333EA),
      soft: Color(0xFFF6EDFF),
    );
  }

  return const _Visual(
    icon: Icons.dashboard_outlined,
    accent: _omcRed,
    soft: Color(0xFFFFEEF1),
  );
}

_Visual _activityVisual(HomeDashboardActivity activity) {
  final key = [
    activity.title,
    activity.subtitle,
    activity.status ?? '',
    activity.colorFamily ?? '',
  ].join(' ').toLowerCase();

  if (key.contains('document') || key.contains('approved')) {
    return const _Visual(
      icon: Icons.check_circle_outline_rounded,
      accent: Color(0xFF15803D),
      soft: Color(0xFFECF8F0),
    );
  }
  if (key.contains('payment') || key.contains('receipt')) {
    return const _Visual(
      icon: Icons.account_balance_wallet_outlined,
      accent: Color(0xFFF97316),
      soft: Color(0xFFFFF2E8),
    );
  }
  if (key.contains('lead') || key.contains('customer')) {
    return const _Visual(
      icon: Icons.person_add_alt_1_outlined,
      accent: Color(0xFF4263EB),
      soft: Color(0xFFEEF2FF),
    );
  }
  if (key.contains('task')) {
    return const _Visual(
      icon: Icons.assignment_outlined,
      accent: Color(0xFF9333EA),
      soft: Color(0xFFF6EDFF),
    );
  }

  return const _Visual(
    icon: Icons.history_rounded,
    accent: _muted,
    soft: Color(0xFFF2F4F7),
  );
}
