import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../domain/internal_service_case.dart';
import '../domain/internal_workspace_summary.dart';
import 'internal_workspace_providers.dart';

const EdgeInsets _kShellPagePadding = EdgeInsets.fromLTRB(20, 18, 20, 164);

class InternalWorkspaceScreen extends ConsumerWidget {
  const InternalWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(internalWorkspaceSummaryProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(internalWorkspaceSummaryProvider);
          ref.invalidate(internalServiceCasesProvider);
          return ref.read(internalWorkspaceSummaryProvider.future);
        },
        child: summaryAsync.when(
          data: (summary) => _InternalWorkspaceContent(summary: summary),
          loading: () => const _InternalWorkspaceLoading(),
          error: (error, _) => _InternalWorkspaceUnavailable(
            message: _backendErrorMessage(error),
            onRetry: () => ref.invalidate(internalWorkspaceSummaryProvider),
          ),
        ),
      ),
    );
  }
}

String _backendErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  return 'Could not load internal workspace summary from the backend right now.';
}

class _InternalWorkspaceUnavailable extends StatelessWidget {
  const _InternalWorkspaceUnavailable({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _kShellPagePadding,
      children: [
        PremiumEmptyState(
          icon: Icons.dashboard_customize_rounded,
          title: 'Workspace unavailable',
          message: message,
          actionLabel: 'Retry',
          onAction: onRetry,
        ),
      ],
    );
  }
}

class _InternalWorkspaceContent extends ConsumerWidget {
  const _InternalWorkspaceContent({required this.summary});

  final InternalWorkspaceSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final queueAsync = ref.watch(internalServiceCasesProvider);
    final totalFocusItems =
        summary.openLeads + summary.pendingTasks + summary.pendingPayments;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _kShellPagePadding,
      children: [
        const _WorkspaceHeader(),
        const SizedBox(height: 14),
        _CustomerSearchCard(
          onSearch: (value) {
            final query = value.trim();
            if (query.isEmpty) return;
            ref.read(internalServiceCaseFiltersProvider.notifier).setFilters(
                  InternalServiceCaseFilters(search: query),
                );
            context.go('/internal-workspace/service-cases');
          },
        ),
        const SizedBox(height: 14),
        _FocusStrip(
          totalFocusItems: totalFocusItems,
          leads: summary.openLeads,
          tasks: summary.pendingTasks,
          payments: summary.pendingPayments,
        ),
        const SizedBox(height: 20),
        _SectionTitle(
          title: 'Needs Attention',
          actionLabel: 'Service queue',
          onAction: () => context.go('/internal-workspace/service-cases'),
        ),
        const SizedBox(height: 10),
        queueAsync.when(
          loading: () => const _PriorityQueueLoading(),
          error: (error, _) => _PriorityQueueFallback(message: _backendErrorMessage(error)),
          data: (queue) => _PriorityQueuePreview(
            items: queue.cases.take(3).toList(growable: false),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Work Areas',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.96,
          children: [
            _WorkAreaCard(
              title: 'Service Requests',
              subtitle: 'All customer service cases',
              icon: Icons.assignment_turned_in_rounded,
              value: '${summary.activeCustomers}',
              label: 'active customers',
              onTap: () => context.go('/internal-workspace/service-cases'),
            ),
            _WorkAreaCard(
              title: 'Customers',
              subtitle: 'Customer 360 center',
              icon: Icons.groups_2_rounded,
              value: '${summary.activeCustomers}',
              label: 'records',
              onTap: () => context.go('/internal-workspace/customers'),
            ),
            _WorkAreaCard(
              title: 'Documents',
              subtitle: 'Review uploaded files',
              icon: Icons.folder_copy_rounded,
              value: 'Review',
              label: 'queue',
              onTap: () => context.go('/internal-workspace/documents'),
            ),
            _WorkAreaCard(
              title: 'Payments',
              subtitle: 'Receipt and dues control',
              icon: Icons.payments_rounded,
              value: '${summary.pendingPayments}',
              label: 'pending',
              onTap: () => context.go('/internal-workspace/payments'),
            ),
            _WorkAreaCard(
              title: 'Leads',
              subtitle: 'Inquiry follow-up',
              icon: Icons.trending_up_rounded,
              value: '${summary.openLeads}',
              label: 'open',
              onTap: () => context.go('/leads'),
            ),
            _WorkAreaCard(
              title: 'Tasks',
              subtitle: 'Team execution queue',
              icon: Icons.task_alt_rounded,
              value: '${summary.pendingTasks}',
              label: 'pending',
              onTap: () => context.go('/tasks'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _ActivityPlaceholder(onOpenCases: () => context.go('/internal-workspace/service-cases')),
      ],
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.hub_rounded, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OMC Operations Hub',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage customers, services, documents and payments.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
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
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: widget.onSearch,
        decoration: InputDecoration(
          hintText: 'Search customer, phone, CNIC, NTN or service ID',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            tooltip: 'Search',
            onPressed: () => widget.onSearch(_controller.text),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ),
      ),
    );
  }
}

class _FocusStrip extends StatelessWidget {
  const _FocusStrip({
    required this.totalFocusItems,
    required this.leads,
    required this.tasks,
    required this.payments,
  });

  final int totalFocusItems;
  final int leads;
  final int tasks;
  final int payments;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricChip(
            value: '$totalFocusItems',
            label: 'Needs focus',
            icon: Icons.priority_high_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricChip(value: '$payments', label: 'Pending pay', icon: Icons.receipt_long_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricChip(value: '$leads', label: 'Open leads', icon: Icons.person_add_alt_1_rounded),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _PriorityQueuePreview extends StatelessWidget {
  const _PriorityQueuePreview({required this.items});

  final List<InternalServiceCase> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _PriorityQueueFallback(
        message: 'No service cases need attention in the current queue.',
      );
    }

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PriorityQueueTile(serviceCase: item),
          ),
      ],
    );
  }
}

class _PriorityQueueTile extends StatelessWidget {
  const _PriorityQueueTile({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsAction = serviceCase.uploadedDocuments > 0
        ? '${serviceCase.uploadedDocuments} documents need review'
        : serviceCase.pendingDocuments > 0
            ? '${serviceCase.pendingDocuments} documents pending'
            : serviceCase.status;

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.go('/internal-workspace/service-cases/${Uri.encodeComponent(serviceCase.id)}'),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.bolt_rounded, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${serviceCase.displayCustomer} · ${serviceCase.displayService}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  '${serviceCase.id} · $needsAction',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.go('/internal-workspace/service-cases/${Uri.encodeComponent(serviceCase.id)}'),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

class _PriorityQueueLoading extends StatelessWidget {
  const _PriorityQueueLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _LoadingPanel(height: 74),
        SizedBox(height: 10),
        _LoadingPanel(height: 74),
      ],
    );
  }
}

class _PriorityQueueFallback extends StatelessWidget {
  const _PriorityQueueFallback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkAreaCard extends StatelessWidget {
  const _WorkAreaCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 21),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$value $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityPlaceholder extends StatelessWidget {
  const _ActivityPlaceholder({required this.onOpenCases});

  final VoidCallback onOpenCases;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Activity timeline is ready in the UI structure. It will become live when backend activity events are exposed.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenCases,
            icon: const Icon(Icons.assignment_rounded),
            label: const Text('Open service cases'),
          ),
        ],
      ),
    );
  }
}

class _InternalWorkspaceLoading extends StatelessWidget {
  const _InternalWorkspaceLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _kShellPagePadding,
      children: const [
        _LoadingPanel(height: 92),
        SizedBox(height: 14),
        _LoadingPanel(height: 78),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _LoadingPanel(height: 92)),
            SizedBox(width: 10),
            Expanded(child: _LoadingPanel(height: 92)),
            SizedBox(width: 10),
            Expanded(child: _LoadingPanel(height: 92)),
          ],
        ),
        SizedBox(height: 18),
        _LoadingPanel(height: 74),
        SizedBox(height: 10),
        _LoadingPanel(height: 74),
      ],
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}
