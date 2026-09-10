import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/providers/effective_capabilities_provider.dart';
import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../payments/presentation/settlement_exceptions_screen.dart';
import '../application/internal_workspace_focus.dart';
import '../domain/internal_service_case.dart';
import '../domain/internal_workspace_summary.dart';
import 'internal_workspace_providers.dart';

const EdgeInsets _pagePadding = EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl);

class InternalWorkspaceScreen extends ConsumerWidget {
  const InternalWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(internalWorkspaceSummaryProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(internalWorkspaceSummaryProvider);
            ref.invalidate(internalServiceCasesProvider);
            await ref.read(internalWorkspaceSummaryProvider.future);
          },
          child: summaryAsync.when(
            data: (summary) => _WorkspaceContent(summary: summary),
            loading: () => const _WorkspaceLoading(),
            error: (error, _) => _WorkspaceUnavailable(
              message: _failureMessage(error),
              onRetry: () => ref.invalidate(internalWorkspaceSummaryProvider),
            ),
          ),
        ),
      ),
    );
  }
}

String _failureMessage(Object error) {
  return AppFailureClassifier.classify(
    error,
    fallbackTitle: 'Workspace unavailable',
    fallbackMessage:
        'Your internal workspace could not be loaded from the backend right now.',
  ).message;
}

class _WorkspaceContent extends ConsumerWidget {
  const _WorkspaceContent({required this.summary});

  final InternalWorkspaceSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(effectiveCapabilitiesProvider);
    final focus = InternalWorkspaceFocus.fromCapabilities(capabilities);
    final queueAsync = focus.canShowServiceCases
        ? ref.watch(internalServiceCasesProvider)
        : null;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: _pagePadding,
      children: [
        _WorkspaceHeader(
          focus: focus,
          onRefresh: () {
            ref.invalidate(internalWorkspaceSummaryProvider);
            if (focus.canShowServiceCases) {
              ref.invalidate(internalServiceCasesProvider);
            }
          },
        ),
        if (focus.canShowServiceCases) ...[
          const SizedBox(height: 28),
          _SectionHeader(
            title: 'Your next work',
            supporting: focus.priorityTitle,
            actionLabel: 'View all',
            onAction: () => context.go('/internal-workspace/service-cases'),
          ),
          const SizedBox(height: 12),
          queueAsync!.when(
            loading: () => const _PriorityLoading(),
            error: (error, _) => _QueueUnavailable(
              message: _failureMessage(error),
              onRetry: () => ref.invalidate(internalServiceCasesProvider),
            ),
            data: (queue) => _PriorityPreview(
              focus: focus,
              items: _rankPriorityCases(
                queue.cases,
                focus.kind,
              ).take(3).toList(growable: false),
            ),
          ),
        ],
        const SizedBox(height: 28),
        const _SectionHeader(
          title: 'Work queues',
          supporting: 'Open the queue that owns the next operational step.',
        ),
        const SizedBox(height: 12),
        queueAsync == null
            ? _WorkQueues(
                focus: focus,
                summary: summary,
                cases: const [],
                queueUnavailable: true,
              )
            : queueAsync.when(
                loading: () => _WorkQueues(
                  focus: focus,
                  summary: summary,
                  cases: const [],
                  queueUnavailable: true,
                ),
                error: (_, _) => _WorkQueues(
                  focus: focus,
                  summary: summary,
                  cases: const [],
                  queueUnavailable: true,
                ),
                data: (queue) => _WorkQueues(
                  focus: focus,
                  summary: summary,
                  cases: queue.cases,
                ),
              ),
        if (focus.canShowCustomers && focus.canShowServiceCases) ...[
          const SizedBox(height: 28),
          const _SectionHeader(
            title: 'Find customer work',
            supporting:
                'Search the existing scoped service-case queue by customer or case.',
          ),
          const SizedBox(height: 12),
          _CustomerSearchCard(
            onSearch: (value) {
              final query = value.trim();
              if (query.isEmpty) return;
              ref
                  .read(internalServiceCaseFiltersProvider.notifier)
                  .setFilters(InternalServiceCaseFilters(search: query));
              context.go('/internal-workspace/service-cases');
            },
          ),
        ],
        const SizedBox(height: 28),
        const _SectionHeader(
          title: 'Workspace overview',
          supporting: 'Secondary totals for your current capability scope.',
        ),
        const SizedBox(height: 12),
        queueAsync == null
            ? _OverviewCard(
                focus: focus,
                summary: summary,
                cases: const [],
                queueUnavailable: true,
              )
            : queueAsync.when(
                loading: () => _OverviewCard(
                  focus: focus,
                  summary: summary,
                  cases: const [],
                  queueUnavailable: true,
                ),
                error: (_, _) => _OverviewCard(
                  focus: focus,
                  summary: summary,
                  cases: const [],
                  queueUnavailable: true,
                ),
                data: (queue) => _OverviewCard(
                  focus: focus,
                  summary: summary,
                  cases: queue.cases,
                ),
              ),
        const SizedBox(height: 28),
        const _SectionHeader(
          title: 'Quick actions',
          supporting: 'Only actions allowed by your current capabilities.',
        ),
        const SizedBox(height: 12),
        _QuickActions(focus: focus),
        if (focus.showServicePerformance) ...[
          const SizedBox(height: 28),
          const _SectionHeader(
            title: 'Service performance',
            supporting: 'Secondary progress across your assigned services.',
          ),
          const SizedBox(height: 12),
          _ServicePerformanceCard(summary: summary),
        ],
      ],
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.focus, required this.onRefresh});

  final InternalWorkspaceFocus focus;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 340 || textScale > 1.35;
        final identity = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              focus.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(focus.subtitle, style: Theme.of(context).textTheme.bodyLarge),
          ],
        );
        final refresh = IconButton.outlined(
          tooltip: 'Refresh workspace',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerLeft, child: refresh),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: identity),
            const SizedBox(width: 12),
            refresh,
          ],
        );
      },
    );
  }
}

class _CustomerSearchCard extends StatefulWidget {
  const _CustomerSearchCard({required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  State<_CustomerSearchCard> createState() => _CustomerSearchCardState();
}

class _CustomerSearchCardState extends State<_CustomerSearchCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: widget.onSearch,
      decoration: InputDecoration(
        labelText: 'Search customer or service case',
        hintText: 'Customer name, ID or case reference',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          tooltip: 'Search cases',
          onPressed: () => widget.onSearch(_controller.text),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.focus,
    required this.summary,
    required this.cases,
    this.queueUnavailable = false,
  });

  final InternalWorkspaceFocus focus;
  final InternalWorkspaceSummary summary;
  final List<InternalServiceCase> cases;
  final bool queueUnavailable;

  @override
  Widget build(BuildContext context) {
    final metrics = _overviewMetrics(
      focus: focus,
      summary: summary,
      cases: cases,
      queueUnavailable: queueUnavailable,
    );

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  focus.overviewTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (focus.canShowServiceCases && queueUnavailable)
                const Tooltip(
                  message: 'Case queue is temporarily unavailable',
                  child: Icon(
                    Icons.cloud_off_outlined,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _AdaptiveMetricWrap(metrics: metrics),
        ],
      ),
    );
  }
}

class _AdaptiveMetricWrap extends StatelessWidget {
  const _AdaptiveMetricWrap({required this.metrics});

  final List<_OverviewMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final single = constraints.maxWidth < 300 || textScale >= 1.5;
        final itemWidth = single
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: itemWidth,
                  child: _OverviewMetricCard(metric: metric),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _OverviewMetricCard extends StatelessWidget {
  const _OverviewMetricCard({required this.metric});

  final _OverviewMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardSoft,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, size: 20, color: metric.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.value,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  metric.label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.supporting,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? supporting;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (supporting?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(supporting!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );

    if (actionLabel == null || onAction == null) return titleBlock;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 4),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        );
      },
    );
  }
}

class _PriorityPreview extends StatelessWidget {
  const _PriorityPreview({required this.focus, required this.items});

  final InternalWorkspaceFocus focus;
  final List<InternalServiceCase> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return PremiumCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppTheme.success,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No service cases need attention in your current scope.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PriorityCaseCard(
              item: item,
              reason: _priorityReason(item, focus.kind),
            ),
          ),
      ],
    );
  }
}

class _PriorityCaseCard extends StatelessWidget {
  const _PriorityCaseCard({required this.item, required this.reason});

  final InternalServiceCase item;
  final _PriorityReason reason;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _openCase(context, item),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: reason.color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(reason.icon, color: reason.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayCustomer,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  item.displayService,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 6),
                SelectableText(
                  item.id,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(reason.icon, color: reason.color, size: 18),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${reason.label}${_waitingLabel(item)}',
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(color: reason.color),
                      ),
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
    );
  }
}

class _QueueUnavailable extends StatelessWidget {
  const _QueueUnavailable({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Case queue unavailable',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _PriorityLoading extends StatelessWidget {
  const _PriorityLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _LoadingPanel(height: 110),
        SizedBox(height: 10),
        _LoadingPanel(height: 110),
      ],
    );
  }
}

class _WorkQueues extends StatelessWidget {
  const _WorkQueues({
    required this.focus,
    required this.summary,
    required this.cases,
    this.queueUnavailable = false,
  });

  final InternalWorkspaceFocus focus;
  final InternalWorkspaceSummary summary;
  final List<InternalServiceCase> cases;
  final bool queueUnavailable;

  @override
  Widget build(BuildContext context) {
    final items = <_QueueItem>[
      if (focus.canShowServiceCases)
        _QueueItem(
          label: 'Service cases',
          value: queueUnavailable
              ? '—'
              : '${cases.where((item) => item.isActive).length}',
          icon: Icons.assignment_outlined,
          route: '/internal-workspace/service-cases',
        ),
      if (focus.canShowDocuments)
        _QueueItem(
          label: 'Documents',
          value: queueUnavailable ? '—' : '${_documentIssues(cases)}',
          icon: Icons.folder_copy_outlined,
          route: '/internal-workspace/documents',
        ),
      if (focus.canShowPayments)
        _QueueItem(
          label: 'Payments',
          value: '${summary.pendingPayments}',
          icon: Icons.receipt_long_outlined,
          route: '/internal-workspace/payments',
        ),
      if (focus.canShowCustomers)
        _QueueItem(
          label: 'Customers',
          value: '${summary.activeCustomers}',
          icon: Icons.groups_outlined,
          route: '/internal-workspace/customers',
        ),
      if (focus.canShowLeads)
        _QueueItem(
          label: 'Leads',
          value: '${summary.openLeads}',
          icon: Icons.person_search_outlined,
          route: '/leads',
        ),
      if (focus.canShowTasks)
        _QueueItem(
          label: 'Tasks',
          value: '${summary.pendingTasks}',
          icon: Icons.task_alt_outlined,
          route: '/tasks',
        ),
    ];

    if (items.isEmpty) {
      return PremiumCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No additional work queues are assigned to this account.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _WorkQueueRow(item: items[index]),
            if (index != items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _WorkQueueRow extends StatelessWidget {
  const _WorkQueueRow({required this.item});

  final _QueueItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.label}, ${item.value}. Open queue.',
      child: InkWell(
        onTap: () => context.go(item.route),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.cardSoft,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Icon(
                    item.icon,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.value == '—'
                            ? 'Queue count unavailable'
                            : '${item.value} in scope',
                        style: Theme.of(context).textTheme.bodyMedium,
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
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.focus});

  final InternalWorkspaceFocus focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(effectiveCapabilitiesProvider);
    final actions = <_QuickAction>[
      if (focus.canCreateServiceForCustomer)
        _QuickAction(
          label: 'New service case',
          icon: Icons.add_circle_outline_rounded,
          onTap: () => context.go('/services'),
        ),
      if (focus.canShowCustomers)
        _QuickAction(
          label: 'Customers',
          icon: Icons.groups_outlined,
          onTap: () => context.go('/internal-workspace/customers'),
        ),
      if (focus.canShowLeads)
        _QuickAction(
          label: 'Leads',
          icon: Icons.person_search_outlined,
          onTap: () => context.go('/leads'),
        ),
      if (focus.canShowTasks)
        _QuickAction(
          label: 'Tasks',
          icon: Icons.task_alt_outlined,
          onTap: () => context.go('/tasks'),
        ),
      if (capabilities.canUseSupportWorkspace)
        _QuickAction(
          label: 'Support',
          icon: Icons.support_agent_outlined,
          onTap: () => context.go('/support'),
        ),
      if (focus.canShowSettlementExceptions)
        _QuickAction(
          label: 'Settlement exceptions',
          icon: Icons.fact_check_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SettlementExceptionsScreen(),
            ),
          ),
        ),
      if (focus.canShowAdminControls)
        _QuickAction(
          label: 'Admin controls',
          icon: Icons.admin_panel_settings_outlined,
          onTap: () => context.go('/admin-control'),
        ),
      if (focus.canShowOperationalControls)
        _QuickAction(
          label: 'Operational controls',
          icon: Icons.tune_rounded,
          onTap: () => context.go('/admin-control/operations'),
        ),
    ];

    if (actions.isEmpty) {
      return PremiumCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No additional actions are available for this workspace.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            _QuickActionRow(action: actions[index]),
            if (index != actions.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: action.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.cardSoft,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Icon(
                    action.icon,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    action.label,
                    style: Theme.of(context).textTheme.titleMedium,
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
      ),
    );
  }
}

class _ServicePerformanceCard extends StatelessWidget {
  const _ServicePerformanceCard({required this.summary});

  final InternalWorkspaceSummary summary;

  @override
  Widget build(BuildContext context) {
    final assigned = summary.myAssignedServices;
    final completed = summary.myCompletedServices;
    final completionRate = assigned <= 0
        ? 0
        : ((completed / assigned) * 100).round().clamp(0, 100);

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My service performance',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PerformanceMetric(
                label: 'Active',
                value: summary.myActiveServices,
              ),
              _PerformanceMetric(label: 'Completed', value: completed),
              _PerformanceMetric(
                label: 'This month',
                value: summary.myCompletedThisMonth,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$completionRate% completion rate across $assigned assigned services',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PerformanceMetric extends StatelessWidget {
  const _PerformanceMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardSoft,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _WorkspaceUnavailable extends StatelessWidget {
  const _WorkspaceUnavailable({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _pagePadding,
      children: [
        PremiumEmptyState(
          icon: Icons.dashboard_customize_outlined,
          title: 'Workspace unavailable',
          message: message,
          actionLabel: 'Retry',
          onAction: onRetry,
        ),
      ],
    );
  }
}

class _WorkspaceLoading extends StatelessWidget {
  const _WorkspaceLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _pagePadding,
      children: const [
        _LoadingPanel(height: 92),
        SizedBox(height: 24),
        _LoadingPanel(height: 120),
        SizedBox(height: 12),
        _LoadingPanel(height: 120),
        SizedBox(height: 24),
        _LoadingPanel(height: 220),
      ],
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.processingSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    );
  }
}

typedef _OverviewMetric = ({
  String value,
  String label,
  IconData icon,
  Color color,
});
typedef _PriorityReason = ({String label, IconData icon, Color color});

class _QueueItem {
  const _QueueItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.route,
  });

  final String label;
  final String value;
  final IconData icon;
  final String route;
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

List<_OverviewMetric> _overviewMetrics({
  required InternalWorkspaceFocus focus,
  required InternalWorkspaceSummary summary,
  required List<InternalServiceCase> cases,
  required bool queueUnavailable,
}) {
  final unavailable = queueUnavailable ? '—' : null;
  final activeCases = cases.where((item) => item.isActive).length;
  final attentionCases = cases.where(_caseNeedsAttention).length;
  final financeAttention = cases.where(_needsFinanceAttention).length;
  final waitingCustomer = cases.where((item) => item.isWaitingCustomer).length;
  final urgentCases = cases.where(_isHighPriority).length;
  final documentIssues = _documentIssues(cases);
  final uploadedDocuments = cases.fold<int>(
    0,
    (total, item) => total + item.uploadedDocuments,
  );

  _OverviewMetric metric(
    String value,
    String label,
    IconData icon,
    Color color,
  ) => (value: value, label: label, icon: icon, color: color);

  return switch (focus.kind) {
    InternalWorkspaceFocusKind.leadership => [
      metric(
        unavailable ?? '$activeCases',
        'Active cases',
        Icons.assignment_outlined,
        AppTheme.info,
      ),
      metric(
        unavailable ?? '$attentionCases',
        'Need attention',
        Icons.priority_high_rounded,
        AppTheme.danger,
      ),
      metric(
        '${summary.pendingPayments}',
        'Payments pending',
        Icons.receipt_long_outlined,
        AppTheme.warning,
      ),
      metric(
        '${summary.pendingTasks}',
        'Tasks due',
        Icons.task_alt_outlined,
        AppTheme.primary,
      ),
    ],
    InternalWorkspaceFocusKind.finance => [
      metric(
        '${summary.pendingPayments}',
        'Payments pending',
        Icons.receipt_long_outlined,
        AppTheme.warning,
      ),
      metric(
        unavailable ?? '$financeAttention',
        'Finance attention',
        Icons.fact_check_outlined,
        AppTheme.danger,
      ),
      metric(
        unavailable ?? '$activeCases',
        'Cases in scope',
        Icons.assignment_outlined,
        AppTheme.info,
      ),
      metric(
        '${summary.pendingTasks}',
        'Tasks due',
        Icons.task_alt_outlined,
        AppTheme.primary,
      ),
    ],
    InternalWorkspaceFocusKind.documentReview => [
      metric(
        unavailable ?? '$documentIssues',
        'Document issues',
        Icons.error_outline_rounded,
        AppTheme.danger,
      ),
      metric(
        unavailable ?? '$uploadedDocuments',
        'Uploaded docs',
        Icons.upload_file_outlined,
        AppTheme.info,
      ),
      metric(
        unavailable ?? '$activeCases',
        'Cases in scope',
        Icons.assignment_outlined,
        AppTheme.success,
      ),
      metric(
        '${summary.pendingTasks}',
        'Tasks due',
        Icons.task_alt_outlined,
        AppTheme.primary,
      ),
    ],
    InternalWorkspaceFocusKind.support => [
      metric(
        unavailable ?? '$activeCases',
        'Customer cases',
        Icons.support_agent_outlined,
        AppTheme.info,
      ),
      metric(
        unavailable ?? '$waitingCustomer',
        'Waiting customer',
        Icons.schedule_outlined,
        AppTheme.warning,
      ),
      metric(
        unavailable ?? '$urgentCases',
        'High priority',
        Icons.priority_high_rounded,
        AppTheme.danger,
      ),
      metric(
        '${summary.pendingTasks}',
        'Tasks due',
        Icons.task_alt_outlined,
        AppTheme.primary,
      ),
    ],
    InternalWorkspaceFocusKind.clientWork => [
      metric(
        '${summary.myActiveServices}',
        'My active services',
        Icons.work_outline_rounded,
        AppTheme.info,
      ),
      metric(
        unavailable ?? '$attentionCases',
        'Need attention',
        Icons.priority_high_rounded,
        AppTheme.danger,
      ),
      metric(
        unavailable ?? '$documentIssues',
        'Document issues',
        Icons.description_outlined,
        AppTheme.warning,
      ),
      metric(
        '${summary.pendingTasks}',
        'Tasks due',
        Icons.task_alt_outlined,
        AppTheme.primary,
      ),
    ],
    InternalWorkspaceFocusKind.operations => [
      metric(
        unavailable ?? '$activeCases',
        'Active cases',
        Icons.assignment_outlined,
        AppTheme.info,
      ),
      metric(
        unavailable ?? '$attentionCases',
        'Need attention',
        Icons.priority_high_rounded,
        AppTheme.danger,
      ),
      metric(
        '${summary.pendingPayments}',
        'Payments pending',
        Icons.receipt_long_outlined,
        AppTheme.warning,
      ),
      metric(
        '${summary.pendingTasks}',
        'Tasks due',
        Icons.task_alt_outlined,
        AppTheme.primary,
      ),
    ],
  };
}

List<InternalServiceCase> _rankPriorityCases(
  List<InternalServiceCase> cases,
  InternalWorkspaceFocusKind kind,
) {
  final ranked = cases.where((item) => item.isActive).toList();
  ranked.sort((a, b) {
    final score = _priorityScore(b, kind).compareTo(_priorityScore(a, kind));
    if (score != 0) return score;
    final aDate = _caseDate(a);
    final bDate = _caseDate(b);
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return aDate.compareTo(bDate);
  });
  return ranked;
}

int _priorityScore(InternalServiceCase item, InternalWorkspaceFocusKind kind) {
  var score = 0;
  if (_isHighPriority(item)) score += 80;
  if (item.priority.toLowerCase().contains('urgent')) score += 20;
  if (item.rejectedDocuments > 0) score += 65;
  if (item.pendingDocuments > 0) score += 45;
  if (item.isInReview) score += 35;
  if (item.isWaitingCustomer) score += 25;

  switch (kind) {
    case InternalWorkspaceFocusKind.finance:
      if (item.isFinancialHold) score += 100;
      if (item.isWaitingPayment) score += 80;
      if (item.normalizedLifecycleState == 'activation failed') score += 70;
    case InternalWorkspaceFocusKind.documentReview:
      if (item.rejectedDocuments > 0) score += 100;
      if (item.uploadedDocuments > 0) score += 70;
      if (item.pendingDocuments > 0) score += 55;
    case InternalWorkspaceFocusKind.support:
      if (item.isWaitingCustomer) score += 90;
      if (_isHighPriority(item)) score += 55;
    case InternalWorkspaceFocusKind.clientWork:
      if (item.pendingDocuments > 0 || item.rejectedDocuments > 0) score += 35;
    case InternalWorkspaceFocusKind.leadership:
    case InternalWorkspaceFocusKind.operations:
      break;
  }

  final date = _caseDate(item);
  if (date != null) {
    score += DateTime.now().difference(date).inDays.clamp(0, 30);
  }
  return score;
}

_PriorityReason _priorityReason(
  InternalServiceCase item,
  InternalWorkspaceFocusKind kind,
) {
  if (kind == InternalWorkspaceFocusKind.finance) {
    if (item.isFinancialHold) {
      return (
        label: 'Financial hold',
        icon: Icons.account_balance_wallet_outlined,
        color: AppTheme.danger,
      );
    }
    if (item.isWaitingPayment) {
      return (
        label: 'Waiting for payment',
        icon: Icons.receipt_long_outlined,
        color: AppTheme.warning,
      );
    }
    if (item.normalizedLifecycleState == 'activation failed') {
      return (
        label: 'Activation failed',
        icon: Icons.sync_problem_outlined,
        color: AppTheme.danger,
      );
    }
  }

  if (kind == InternalWorkspaceFocusKind.documentReview) {
    if (item.rejectedDocuments > 0) {
      return (
        label:
            '${item.rejectedDocuments} rejected document${item.rejectedDocuments == 1 ? '' : 's'}',
        icon: Icons.error_outline_rounded,
        color: AppTheme.danger,
      );
    }
    if (item.uploadedDocuments > 0) {
      return (
        label: '${item.uploadedDocuments} uploaded for review',
        icon: Icons.upload_file_outlined,
        color: AppTheme.info,
      );
    }
  }

  if (kind == InternalWorkspaceFocusKind.support && item.isWaitingCustomer) {
    return (
      label: 'Waiting for customer',
      icon: Icons.schedule_outlined,
      color: AppTheme.warning,
    );
  }

  if (item.rejectedDocuments > 0) {
    return (
      label:
          '${item.rejectedDocuments} rejected document${item.rejectedDocuments == 1 ? '' : 's'}',
      icon: Icons.error_outline_rounded,
      color: AppTheme.danger,
    );
  }
  if (item.pendingDocuments > 0) {
    return (
      label: 'Missing documents',
      icon: Icons.description_outlined,
      color: AppTheme.warning,
    );
  }
  if (_isHighPriority(item)) {
    return (
      label: item.priority.toLowerCase().contains('urgent')
          ? 'Urgent priority'
          : 'High priority',
      icon: Icons.priority_high_rounded,
      color: AppTheme.danger,
    );
  }
  if (item.isInReview) {
    return (
      label: item.statusLabel,
      icon: Icons.rate_review_outlined,
      color: AppTheme.info,
    );
  }
  return (
    label: item.statusLabel,
    icon: Icons.inbox_outlined,
    color: AppTheme.success,
  );
}

bool _caseNeedsAttention(InternalServiceCase item) {
  return _isHighPriority(item) ||
      item.pendingDocuments > 0 ||
      item.rejectedDocuments > 0 ||
      item.isFinancialHold ||
      item.isInReview ||
      item.isWaitingCustomer;
}

bool _needsFinanceAttention(InternalServiceCase item) {
  return item.isFinancialHold ||
      item.isWaitingPayment ||
      item.normalizedLifecycleState == 'activation failed' ||
      item.isInReview;
}

bool _isHighPriority(InternalServiceCase item) {
  final priority = item.priority.toLowerCase();
  return priority.contains('urgent') || priority.contains('high');
}

int _documentIssues(List<InternalServiceCase> cases) {
  return cases.fold<int>(
    0,
    (total, item) => total + item.pendingDocuments + item.rejectedDocuments,
  );
}

void _openCase(BuildContext context, InternalServiceCase item) {
  context.go(
    '/internal-workspace/service-cases/${Uri.encodeComponent(item.id)}',
  );
}

String _waitingLabel(InternalServiceCase item) {
  final date = _caseDate(item);
  if (date == null) return '';
  final days = DateTime.now().difference(date).inDays;
  if (days <= 0) return ' · updated today';
  if (days == 1) return ' · 1 day waiting';
  return ' · $days days waiting';
}

DateTime? _caseDate(InternalServiceCase item) {
  return DateTime.tryParse(item.updatedAt)?.toLocal() ??
      DateTime.tryParse(item.createdAt)?.toLocal();
}
