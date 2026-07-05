import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          error: (_, _) => _InternalWorkspaceContent(
            summary: InternalWorkspaceSummary.empty(),
          ),
        ),
      ),
    );
  }
}

class _InternalWorkspaceContent extends StatelessWidget {
  const _InternalWorkspaceContent({required this.summary});

  final InternalWorkspaceSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primaryContainer,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Team Command Center',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Track sales, customers, payments, and daily execution from one clean workspace.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.12,
          children: [
            _SummaryCard(
              title: 'Open Leads',
              value: summary.openLeads,
              icon: Icons.trending_up_rounded,
            ),
            _SummaryCard(
              title: 'Customers',
              value: summary.activeCustomers,
              icon: Icons.groups_2_rounded,
            ),
            _SummaryCard(
              title: 'Pending Tasks',
              value: summary.pendingTasks,
              icon: Icons.task_alt_rounded,
            ),
            _SummaryCard(
              title: 'Pending Payments',
              value: summary.pendingPayments,
              icon: Icons.account_balance_wallet_rounded,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Quick Actions',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const Spacer(),
            Text(
              value.toString(),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _InternalWorkspaceLoading extends StatelessWidget {
  const _InternalWorkspaceLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
