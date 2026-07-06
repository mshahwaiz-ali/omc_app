import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../domain/internal_workspace_summary.dart';
import 'internal_workspace_providers.dart';

class InternalWorkspaceScreen extends ConsumerWidget {
  const InternalWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(internalWorkspaceSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Internal Workspace')),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(internalWorkspaceSummaryProvider);
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
      padding: const EdgeInsets.all(20),
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

class _InternalWorkspaceContent extends StatelessWidget {
  const _InternalWorkspaceContent({required this.summary});

  final InternalWorkspaceSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalFocusItems =
        summary.openLeads + summary.pendingTasks + summary.pendingPayments;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        _WorkspaceHero(totalFocusItems: totalFocusItems),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.08,
          children: [
            _SummaryCard(
              title: 'Open Leads',
              value: summary.openLeads,
              icon: Icons.trending_up_rounded,
              helper: 'Need follow-up',
            ),
            _SummaryCard(
              title: 'Customers',
              value: summary.activeCustomers,
              icon: Icons.groups_2_rounded,
              helper: 'Active records',
            ),
            _SummaryCard(
              title: 'Pending Tasks',
              value: summary.pendingTasks,
              icon: Icons.task_alt_rounded,
              helper: 'Execution queue',
            ),
            _SummaryCard(
              title: 'Pending Payments',
              value: summary.pendingPayments,
              icon: Icons.account_balance_wallet_rounded,
              helper: 'Collection focus',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Quick Actions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              'Live backend',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ShortcutTile(
          title: 'Leads',
          subtitle: 'Review new opportunities and follow-ups',
          icon: Icons.person_add_alt_1_rounded,
          onTap: () => context.go('/leads'),
        ),
        _ShortcutTile(
          title: 'Customers',
          subtitle: 'Open customer records and activity',
          icon: Icons.business_center_rounded,
          onTap: () => context.go('/customers'),
        ),
        _ShortcutTile(
          title: 'Tasks',
          subtitle: 'Check pending work and assignments',
          icon: Icons.check_circle_outline_rounded,
          onTap: () => context.go('/tasks'),
        ),
        _ShortcutTile(
          title: 'Payments',
          subtitle: 'View pending and recent payment activity',
          icon: Icons.payments_rounded,
          onTap: () => context.go('/payments'),
        ),
      ],
    );
  }
}

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({required this.totalFocusItems});

  final int totalFocusItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 17,
                    color: theme.colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$totalFocusItems focus items',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Team Command Center',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track sales, customers, payments, and daily execution from one clean workspace.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.84),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.helper,
  });

  final String title;
  final int value;
  final IconData icon;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(
                    icon,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 21,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                value.toString(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                helper,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InternalWorkspaceLoading extends StatelessWidget {
  const _InternalWorkspaceLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Container(
          height: 172,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(
              width: 180,
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.08,
          children: const [
            _LoadingCard(),
            _LoadingCard(),
            _LoadingCard(),
            _LoadingCard(),
          ],
        ),
        const SizedBox(height: 24),
        const _LoadingTile(),
        const _LoadingTile(),
        const _LoadingTile(),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            width: 92,
            height: 14,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: 74,
        padding: const EdgeInsets.all(16),
        alignment: Alignment.centerLeft,
        child: Container(
          width: 180,
          height: 14,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
