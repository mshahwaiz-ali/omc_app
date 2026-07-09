import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../home/data/home_dashboard_repository.dart';
import '../../internal_workspace/domain/internal_service_case.dart';
import '../../internal_workspace/domain/internal_workspace_summary.dart';
import '../../internal_workspace/presentation/internal_workspace_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(homeDashboardSummaryProvider);
    final authState = ref.watch(authControllerProvider);
    final isInternal =
        authState.capabilities.canAccessInternalWorkspace ||
        authState.capabilities.isInternal ||
        authState.canAccessInternalWorkspace;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeDashboardSummaryProvider);
            if (isInternal) {
              ref.invalidate(internalWorkspaceSummaryProvider);
              ref.invalidate(internalServiceCasesProvider);
            }
            await ref.read(homeDashboardSummaryProvider.future);
          },
          child: summaryAsync.when(
            loading: () => const _DashboardLoadingView(),
            error: (_, _) => _buildBody(
              ref,
              isInternal,
              const HomeDashboardSummary.empty(
                fallbackMessage: 'Dashboard data could not be loaded.',
              ),
            ),
            data: (summary) => _buildBody(ref, isInternal, summary),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    WidgetRef ref,
    bool isInternal,
    HomeDashboardSummary summary,
  ) {
    if (!isInternal) return _CustomerDashboardBody(summary: summary);

    final workspaceSummary = ref
        .watch(internalWorkspaceSummaryProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: InternalWorkspaceSummary.empty,
        );
    final queue = ref.watch(internalServiceCasesProvider).maybeWhen(
          data: (value) => value,
          orElse: () => const InternalServiceCaseQueue(
            cases: [],
            summary: {},
            canReviewDocuments: false,
            canUpdateStatus: false,
          ),
        );

    return _InternalDashboardBody(
      customerSummary: summary,
      workspaceSummary: workspaceSummary,
      queue: queue,
    );
  }
}

class _CustomerDashboardBody extends StatelessWidget {
  const _CustomerDashboardBody({required this.summary});

  final HomeDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final nextAction = _CustomerNextAction.fromSummary(summary);
    final attentionRows = _customerAttentionRows(summary);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      children: [
        _CompactHeader(
          title: _greeting(),
          subtitle: 'Your OMC workspace',
          icon: Icons.dashboard_customize_outlined,
          chips: [
            '${summary.activeCases} active services',
            '${_customerActionCount(summary)} action needed',
          ],
        ),
        const SizedBox(height: 18),
        _NextActionCard(
          eyebrow: nextAction.eyebrow,
          title: nextAction.title,
          subtitle: nextAction.subtitle,
          buttonLabel: nextAction.buttonLabel,
          icon: nextAction.icon,
          onPressed: () => context.go(nextAction.route),
        ),
        const SizedBox(height: 18),
        _DashboardSection(
          title: 'My services snapshot',
          subtitle: 'Latest service movement from your OMC account.',
          child: Column(
            children: [
              _ServiceSnapshotTile(
                title: summary.activeCases > 0
                    ? 'Active service workspace'
                    : 'No active services yet',
                status: summary.activeCases > 0 ? 'In progress' : 'Ready',
                meta: summary.activeCases > 0
                    ? '${summary.activeCases} open · ${summary.completedCases} completed'
                    : 'Start a service when you are ready.',
                progressLabel: summary.pendingDocuments > 0
                    ? 'Documents need attention'
                    : 'Workspace is clear',
                progressValue: summary.activeCases > 0
                    ? (summary.pendingDocuments > 0 ? 0.55 : 0.82)
                    : 0,
                trailingLabel: summary.activeCases > 0 ? 'Open' : 'Browse',
                onTap: () => context.go(
                  summary.activeCases > 0 ? '/my-services' : '/services',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _MiniSummaryCard(
                title: 'Documents',
                value: summary.pendingDocuments.toString(),
                subtitle: summary.pendingDocuments == 0
                    ? 'No missing documents'
                    : 'missing / pending',
                icon: Icons.folder_copy_outlined,
                onTap: () => context.go('/documents'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniSummaryCard(
                title: 'Payments',
                value: summary.paymentsDue.toString(),
                subtitle: summary.paymentsDue == 0
                    ? 'No payment due'
                    : 'pending / due',
                icon: Icons.account_balance_wallet_outlined,
                onTap: () => context.go('/payments'),
              ),
            ),
          ],
        ),
        if (attentionRows.isNotEmpty) ...[
          const SizedBox(height: 18),
          _AttentionCard(title: 'Needs your attention', rows: attentionRows),
        ],
        const SizedBox(height: 18),
        _RecentActivitySection(
          activities: summary.recentActivity,
          emptyTitle: 'No recent activity yet.',
          emptySubtitle:
              'Your updates will appear here once services start moving.',
        ),
        const SizedBox(height: 18),
        _QuickActionsCard(
          title: 'Quick actions',
          actions: [
            _ShortcutAction(
              label: 'Start service',
              icon: Icons.add_business_outlined,
              route: '/services',
            ),
            _ShortcutAction(
              label: 'Upload document',
              icon: Icons.upload_file_outlined,
              route: '/documents',
            ),
            _ShortcutAction(
              label: 'View payments',
              icon: Icons.receipt_long_outlined,
              route: '/payments',
            ),
            _ShortcutAction(
              label: 'Support',
              icon: Icons.support_agent_outlined,
              route: '/support',
            ),
            _ShortcutAction(
              label: 'Tax calculator',
              icon: Icons.calculate_outlined,
              route: '/tax-calculator',
            ),
          ],
        ),
        if (summary.fallbackMessage != null) ...[
          const SizedBox(height: 18),
          _FallbackCard(message: summary.fallbackMessage!),
        ],
      ],
    );
  }
}

class _InternalDashboardBody extends StatelessWidget {
  const _InternalDashboardBody({
    required this.customerSummary,
    required this.workspaceSummary,
    required this.queue,
  });

  final HomeDashboardSummary customerSummary;
  final InternalWorkspaceSummary workspaceSummary;
  final InternalServiceCaseQueue queue;

  @override
  Widget build(BuildContext context) {
    final visibleCases = queue.cases.take(3).toList(growable: false);
    final documentsWaiting = queue.cases.fold<int>(
      0,
      (total, item) => total + item.pendingDocuments + item.uploadedDocuments,
    );
    final actionRows = _internalAttentionRows(
      workspaceSummary,
      customerSummary,
      queue,
      documentsWaiting,
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      children: [
        _CompactHeader(
          title: 'Operations Dashboard',
          subtitle: 'Today’s work across customers, services and payments.',
          icon: Icons.admin_panel_settings_outlined,
          chips: [
            '${workspaceSummary.activeCustomers} active customers',
            '${queue.cases.length} service cases',
          ],
        ),
        const SizedBox(height: 18),
        _NextActionCard(
          eyebrow: 'Next team action',
          title: documentsWaiting > 0
              ? '$documentsWaiting service documents need review'
              : workspaceSummary.pendingPayments > 0
                  ? '${workspaceSummary.pendingPayments} payments need review'
                  : queue.cases.isNotEmpty
                      ? '${queue.cases.length} service cases need follow-up'
                      : 'Operations queue is clear',
          subtitle: documentsWaiting > 0
              ? 'Open the review queue and clear uploaded or pending documents.'
              : workspaceSummary.pendingPayments > 0
                  ? 'Payment receipts are waiting for internal verification.'
                  : queue.cases.isNotEmpty
                      ? 'Review latest service movement and customer status.'
                      : 'No urgent internal action is visible right now.',
          buttonLabel: documentsWaiting > 0
              ? 'Open review queue'
              : workspaceSummary.pendingPayments > 0
                  ? 'Review payments'
                  : 'Open workspace',
          icon: Icons.bolt_outlined,
          onPressed: () => context.go(
            documentsWaiting > 0
                ? '/internal-workspace/documents'
                : workspaceSummary.pendingPayments > 0
                    ? '/internal-workspace/payments'
                    : '/internal-workspace',
          ),
        ),
        const SizedBox(height: 18),
        _MetricStrip(
          metrics: [
            _MetricData(
              title: 'Doc review',
              value: documentsWaiting.toString(),
              icon: Icons.fact_check_outlined,
            ),
            _MetricData(
              title: 'Payments',
              value: workspaceSummary.pendingPayments.toString(),
              icon: Icons.payments_outlined,
            ),
            _MetricData(
              title: 'Services',
              value: customerSummary.activeCases.toString(),
              icon: Icons.pending_actions_outlined,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DashboardSection(
          title: 'Today action queue',
          subtitle: 'Highest-priority customer work for the team.',
          child: visibleCases.isEmpty
              ? const _EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'No service cases in queue',
                  subtitle: 'New customer work will appear here.',
                )
              : Column(
                  children: [
                    for (final serviceCase in visibleCases) ...[
                      _InternalQueueTile(serviceCase: serviceCase),
                      if (serviceCase != visibleCases.last)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 18),
        _AttentionCard(title: 'Needs team attention', rows: actionRows),
        const SizedBox(height: 18),
        _QuickActionsCard(
          title: 'Internal work areas',
          actions: [
            _ShortcutAction(
              label: 'Service queue',
              icon: Icons.list_alt_outlined,
              route: '/internal-workspace/service-cases',
            ),
            _ShortcutAction(
              label: 'Document review',
              icon: Icons.folder_special_outlined,
              route: '/internal-workspace/documents',
            ),
            _ShortcutAction(
              label: 'Payment review',
              icon: Icons.receipt_long_outlined,
              route: '/internal-workspace/payments',
            ),
            _ShortcutAction(
              label: 'Customers',
              icon: Icons.people_alt_outlined,
              route: '/internal-workspace/customers',
            ),
            _ShortcutAction(
              label: 'Leads',
              icon: Icons.leaderboard_outlined,
              route: '/leads',
            ),
            _ShortcutAction(
              label: 'Tasks',
              icon: Icons.task_alt_outlined,
              route: '/tasks',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DashboardSection(
          title: 'Customer workspace summary',
          subtitle: 'Customer-side health visible to internal team only.',
          child: Column(
            children: [
              _StatusBreakdownRow(
                data: _StatusRowData(
                  label: 'Open customer services',
                  value: customerSummary.activeCases,
                  icon: Icons.pending_actions_rounded,
                ),
                maxValue: _safeMax([
                  customerSummary.activeCases,
                  customerSummary.pendingDocuments,
                  customerSummary.paymentsDue,
                  customerSummary.unreadNotifications,
                ]),
              ),
              const SizedBox(height: 12),
              _StatusBreakdownRow(
                data: _StatusRowData(
                  label: 'Customer documents pending',
                  value: customerSummary.pendingDocuments,
                  icon: Icons.folder_copy_outlined,
                ),
                maxValue: _safeMax([
                  customerSummary.activeCases,
                  customerSummary.pendingDocuments,
                  customerSummary.paymentsDue,
                  customerSummary.unreadNotifications,
                ]),
              ),
              const SizedBox(height: 12),
              _StatusBreakdownRow(
                data: _StatusRowData(
                  label: 'Customer payments due',
                  value: customerSummary.paymentsDue,
                  icon: Icons.account_balance_wallet_outlined,
                ),
                maxValue: _safeMax([
                  customerSummary.activeCases,
                  customerSummary.pendingDocuments,
                  customerSummary.paymentsDue,
                  customerSummary.unreadNotifications,
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _RecentActivitySection(
          activities: customerSummary.recentActivity,
          emptyTitle: 'No internal activity timeline yet.',
          emptySubtitle:
              'Document uploads, payments and support updates will appear here once exposed by backend.',
        ),
        if (customerSummary.fallbackMessage != null) ...[
          const SizedBox(height: 18),
          _FallbackCard(message: customerSummary.fallbackMessage!),
        ],
      ],
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.chips,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.075),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppTheme.primaryRed, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final chip in chips) _SoftPill(label: chip),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.icon,
    required this.onPressed,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.085),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppTheme.primaryRed, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                eyebrow,
                style: const TextStyle(
                  color: AppTheme.primaryRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final metric in metrics) ...[
          Expanded(child: _MetricCard(data: metric)),
          if (metric != metrics.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: AppTheme.primaryRed, size: 21),
          const SizedBox(height: 13),
          Text(
            data.value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;
}

class _MiniSummaryCard extends StatelessWidget {
  const _MiniSummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          height: 118,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.primaryRed, size: 23),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceSnapshotTile extends StatelessWidget {
  const _ServiceSnapshotTile({
    required this.title,
    required this.status,
    required this.meta,
    required this.progressLabel,
    required this.progressValue,
    required this.trailingLabel,
    required this.onTap,
  });

  final String title;
  final String status;
  final String meta;
  final String progressLabel;
  final double progressValue;
  final String trailingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardSoft.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _SoftPill(label: status),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              meta,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 7,
                backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.06),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryRed,
                ),
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: Text(
                    progressLabel,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  trailingLabel,
                  style: const TextStyle(
                    color: AppTheme.primaryRed,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InternalQueueTile extends StatelessWidget {
  const _InternalQueueTile({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final documentLabel = serviceCase.documentSummaryLabel != '-'
        ? serviceCase.documentSummaryLabel
        : '${serviceCase.pendingDocuments + serviceCase.uploadedDocuments} documents need review';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.go('/internal-workspace/service-cases/${serviceCase.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardSoft.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.075),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.work_outline_rounded,
                color: AppTheme.primaryRed,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceCase.displayCustomer,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    serviceCase.displayService,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    documentLabel,
                    style: const TextStyle(
                      color: AppTheme.primaryRed,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.title, required this.rows});

  final String title;
  final List<_AttentionRow> rows;

  @override
  Widget build(BuildContext context) {
    return _DashboardSection(
      title: title,
      child: Column(
        children: [
          for (final row in rows) ...[
            _AttentionTile(row: row),
            if (row != rows.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile({required this.row});

  final _AttentionRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(row.icon, color: AppTheme.primaryRed, size: 20),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            row.label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _AttentionRow {
  const _AttentionRow({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({required this.title, required this.actions});

  final String title;
  final List<_ShortcutAction> actions;

  @override
  Widget build(BuildContext context) {
    return _DashboardSection(
      title: title,
      child: Wrap(
        spacing: 9,
        runSpacing: 9,
        children: [
          for (final action in actions)
            ActionChip(
              avatar: Icon(action.icon, color: AppTheme.primaryRed, size: 17),
              label: Text(action.label),
              labelStyle: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              side: const BorderSide(color: AppTheme.border),
              backgroundColor: AppTheme.cardSoft.withValues(alpha: 0.55),
              onPressed: () => context.go(action.route),
            ),
        ],
      ),
    );
  }
}

class _ShortcutAction {
  const _ShortcutAction({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({
    required this.activities,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final List<HomeDashboardActivity> activities;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    final visibleActivities = activities.take(4).toList(growable: false);

    return _DashboardSection(
      title: 'Recent activity',
      subtitle: 'Latest updates from services, documents and payments.',
      child: visibleActivities.isEmpty
          ? _EmptyState(
              icon: Icons.timeline_outlined,
              title: emptyTitle,
              subtitle: emptySubtitle,
            )
          : Column(
              children: [
                for (final activity in visibleActivities) ...[
                  _ActivityRow(activity: activity),
                  if (activity != visibleActivities.last)
                    const SizedBox(height: 15),
                ],
              ],
            ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final HomeDashboardActivity activity;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryRed.withValues(alpha: 0.075),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.timeline_rounded,
            color: AppTheme.primaryRed,
            size: 20,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  height: 1.18,
                ),
              ),
              if (activity.subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  activity.subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (activity.createdAtLabel != null) ...[
                const SizedBox(height: 5),
                Text(
                  activity.createdAtLabel!,
                  style: const TextStyle(
                    color: AppTheme.primaryRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBreakdownRow extends StatelessWidget {
  const _StatusBreakdownRow({required this.data, required this.maxValue});

  final _StatusRowData data;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final progress = maxValue == 0 ? 0.0 : data.value / maxValue;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryRed.withValues(alpha: 0.075),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(data.icon, color: AppTheme.primaryRed, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.label,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    data.value.toString(),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.065),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryRed,
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

class _StatusRowData {
  const _StatusRowData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
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
          const SizedBox(height: 17),
          child,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryRed, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SoftPill extends StatelessWidget {
  const _SoftPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
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

class _FallbackCard extends StatelessWidget {
  const _FallbackCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(19),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.075),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppTheme.primaryRed,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoadingView extends StatelessWidget {
  const _DashboardLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      children: const [
        PremiumCard(
          padding: EdgeInsets.all(23),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LoadingBox(width: 58, height: 58, radius: 22),
              SizedBox(height: 18),
              _LoadingBar(widthFactor: 0.58, height: 18),
              SizedBox(height: 10),
              _LoadingBar(widthFactor: 0.84),
              SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _LoadingPill(width: 92),
                  _LoadingPill(width: 116),
                  _LoadingPill(width: 108),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 18),
        PremiumCard(
          padding: EdgeInsets.all(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LoadingBar(widthFactor: 0.34, height: 12),
              SizedBox(height: 14),
              _LoadingBar(widthFactor: 0.78, height: 18),
              SizedBox(height: 10),
              _LoadingBar(widthFactor: 0.92),
              SizedBox(height: 18),
              _LoadingBar(widthFactor: 1, height: 44),
            ],
          ),
        ),
        SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _LoadingMetricCard()),
            SizedBox(width: 12),
            Expanded(child: _LoadingMetricCard()),
          ],
        ),
      ],
    );
  }
}

class _LoadingMetricCard extends StatelessWidget {
  const _LoadingMetricCard();

  @override
  Widget build(BuildContext context) {
    return const PremiumCard(
      padding: EdgeInsets.all(16),
      child: SizedBox(
        height: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LoadingBox(width: 42, height: 42, radius: 16),
            Spacer(),
            _LoadingBar(widthFactor: 0.38, height: 18),
            SizedBox(height: 8),
            _LoadingBar(widthFactor: 0.72),
          ],
        ),
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
        color: AppTheme.primaryRed.withValues(alpha: 0.045),
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
        color: AppTheme.primaryRed.withValues(alpha: 0.045),
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
          color: AppTheme.primaryRed.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _CustomerNextAction {
  const _CustomerNextAction({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.icon,
    required this.route,
  });

  factory _CustomerNextAction.fromSummary(HomeDashboardSummary summary) {
    if (summary.pendingDocuments > 0) {
      return _CustomerNextAction(
        eyebrow: 'Action required',
        title:
            'Upload ${summary.pendingDocuments} pending document${summary.pendingDocuments == 1 ? '' : 's'}',
        subtitle:
            'Continue your active OMC service by completing the required document checklist.',
        buttonLabel: 'Upload now',
        icon: Icons.upload_file_outlined,
        route: '/documents',
      );
    }

    if (summary.paymentsDue > 0) {
      return _CustomerNextAction(
        eyebrow: 'Payment pending',
        title:
            '${summary.paymentsDue} payment${summary.paymentsDue == 1 ? '' : 's'} need attention',
        subtitle:
            'Review dues or uploaded receipts so your service can keep moving.',
        buttonLabel: 'View payment',
        icon: Icons.account_balance_wallet_outlined,
        route: '/payments',
      );
    }

    if (summary.activeCases > 0) {
      return const _CustomerNextAction(
        eyebrow: 'Track progress',
        title: 'Your active services are in progress',
        subtitle:
            'Open your service workspace to review status, documents and updates.',
        buttonLabel: 'Track services',
        icon: Icons.pending_actions_outlined,
        route: '/my-services',
      );
    }

    return const _CustomerNextAction(
      eyebrow: 'All caught up',
      title: 'No action needed right now',
      subtitle:
          'Your OMC workspace is clear. You can browse services or use the tax calculator.',
      buttonLabel: 'Browse services',
      icon: Icons.verified_outlined,
      route: '/services',
    );
  }

  final String eyebrow;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData icon;
  final String route;
}

List<_AttentionRow> _customerAttentionRows(HomeDashboardSummary summary) {
  final rows = <_AttentionRow>[];

  if (summary.pendingDocuments > 0) {
    rows.add(
      _AttentionRow(
        label:
            '${summary.pendingDocuments} document${summary.pendingDocuments == 1 ? '' : 's'} missing or waiting',
        icon: Icons.folder_copy_outlined,
      ),
    );
  }
  if (summary.paymentsDue > 0) {
    rows.add(
      _AttentionRow(
        label:
            '${summary.paymentsDue} payment${summary.paymentsDue == 1 ? '' : 's'} pending',
        icon: Icons.account_balance_wallet_outlined,
      ),
    );
  }
  if (summary.unreadNotifications > 0) {
    rows.add(
      _AttentionRow(
        label:
            '${summary.unreadNotifications} unread notification${summary.unreadNotifications == 1 ? '' : 's'}',
        icon: Icons.notifications_none_rounded,
      ),
    );
  }
  if (rows.isEmpty) {
    rows.add(
      const _AttentionRow(
        label: 'Nothing urgent right now. Your workspace is clear.',
        icon: Icons.check_circle_outline,
      ),
    );
  }

  return rows;
}

List<_AttentionRow> _internalAttentionRows(
  InternalWorkspaceSummary workspaceSummary,
  HomeDashboardSummary customerSummary,
  InternalServiceCaseQueue queue,
  int documentsWaiting,
) {
  final rows = <_AttentionRow>[];

  if (documentsWaiting > 0) {
    rows.add(
      _AttentionRow(
        label: '$documentsWaiting documents waiting for review',
        icon: Icons.fact_check_outlined,
      ),
    );
  }
  if (workspaceSummary.pendingPayments > 0) {
    rows.add(
      _AttentionRow(
        label: '${workspaceSummary.pendingPayments} payments waiting approval',
        icon: Icons.payments_outlined,
      ),
    );
  }
  if (queue.cases.isNotEmpty) {
    rows.add(
      _AttentionRow(
        label: '${queue.cases.length} active service cases need team visibility',
        icon: Icons.pending_actions_outlined,
      ),
    );
  }
  if (workspaceSummary.openLeads > 0) {
    rows.add(
      _AttentionRow(
        label: '${workspaceSummary.openLeads} open leads need follow-up',
        icon: Icons.leaderboard_outlined,
      ),
    );
  }
  if (customerSummary.unreadNotifications > 0) {
    rows.add(
      _AttentionRow(
        label:
            '${customerSummary.unreadNotifications} customer notifications visible',
        icon: Icons.notifications_none_rounded,
      ),
    );
  }
  if (rows.isEmpty) {
    rows.add(
      const _AttentionRow(
        label: 'No urgent internal queue item right now.',
        icon: Icons.check_circle_outline,
      ),
    );
  }

  return rows;
}

int _customerActionCount(HomeDashboardSummary summary) {
  return summary.pendingDocuments + summary.paymentsDue + summary.unreadNotifications;
}

int _safeMax(List<int> values) {
  final maxValue = values.fold<int>(0, (previous, value) {
    return value > previous ? value : previous;
  });
  return maxValue == 0 ? 1 : maxValue;
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}
