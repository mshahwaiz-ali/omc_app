import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../home/application/home_action_access.dart';
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
    final capabilities = authState.capabilities;
    final isInternal =
        capabilities.canAccessInternalWorkspace ||
        capabilities.isInternal ||
        authState.canAccessInternalWorkspace;

    Future<void> refresh() async {
      ref.invalidate(homeDashboardSummaryProvider);
      if (isInternal) {
        ref.invalidate(internalWorkspaceSummaryProvider);
        ref.invalidate(internalServiceCasesProvider);
      }
      try {
        await ref.read(homeDashboardSummaryProvider.future);
      } catch (_) {
        // The dashboard error state remains authoritative after refresh failure.
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator.adaptive(
          onRefresh: refresh,
          child: summaryAsync.when(
            loading: () => const _DashboardLoadingView(),
            error: (_, _) =>
                _DashboardUnavailable(isInternal: isInternal, onRetry: refresh),
            data: (summary) {
              if (!isInternal) {
                return _CustomerDashboardBody(
                  summary: summary,
                  capabilities: capabilities,
                );
              }

              return _InternalDashboardBody(
                customerSummary: summary,
                workspaceAsync: ref.watch(internalWorkspaceSummaryProvider),
                queueAsync: ref.watch(internalServiceCasesProvider),
                capabilities: capabilities,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CustomerDashboardBody extends StatelessWidget {
  const _CustomerDashboardBody({
    required this.summary,
    required this.capabilities,
  });

  final HomeDashboardSummary summary;
  final AuthCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final nextAction = _DashboardAction.customer(summary);
    final services = summary.serviceSnapshots.take(3).toList(growable: false);

    return OmcPageListView(
      topPadding: 18,
      bottomPadding: 32,
      children: [
        const _DashboardHeader(
          eyebrow: 'Dashboard',
          title: 'Your OMC overview',
          subtitle: 'Next action first, supporting account status second.',
          icon: Icons.dashboard_outlined,
        ),
        if (summary.fallbackMessage?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 12),
          _InlineUnavailable(message: summary.fallbackMessage!.trim()),
        ],
        const SizedBox(height: 18),
        _NextActionCard(action: nextAction),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Service requests',
          subtitle: services.isEmpty
              ? 'No active service snapshot is currently available.'
              : 'Latest backend service status from your account.',
          actionLabel: capabilities.canTrackRequests ? 'View all' : null,
          onAction: capabilities.canTrackRequests
              ? () => context.go('/my-services')
              : null,
        ),
        const SizedBox(height: 10),
        if (services.isEmpty)
          _EmptyPanel(
            icon: Icons.work_outline_rounded,
            title: 'No service request to show',
            message: capabilities.canCreateServiceRequest
                ? 'Browse the catalogue when you are ready to start a service.'
                : 'No active service snapshot is currently available.',
            actionLabel: capabilities.canCreateServiceRequest
                ? 'Browse services'
                : null,
            onAction: capabilities.canCreateServiceRequest
                ? () => context.go('/services')
                : null,
          )
        else
          PremiumCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var index = 0; index < services.length; index++) ...[
                  _CustomerServiceRow(
                    service: services[index],
                    canOpen: capabilities.canTrackRequests,
                  ),
                  if (index != services.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        const SizedBox(height: 24),
        const _SectionHeader(
          title: 'Account summary',
          subtitle: 'Authoritative backend counts without invented progress.',
        ),
        const SizedBox(height: 10),
        _CustomerSummaryCard(summary: summary, capabilities: capabilities),
        const SizedBox(height: 24),
        const _SectionHeader(
          title: 'Recent activity',
          subtitle: 'Latest activity exposed by the dashboard backend.',
        ),
        const SizedBox(height: 10),
        _ActivityCard(
          activities: summary.recentActivity,
          onOpen: capabilities.canTrackRequests
              ? () => context.go('/my-services')
              : null,
        ),
        const SizedBox(height: 24),
        const _SectionHeader(
          title: 'Useful links',
          subtitle: 'The same working destinations retained from Dashboard.',
        ),
        const SizedBox(height: 10),
        _CustomerLinks(capabilities: capabilities),
      ],
    );
  }
}

class _InternalDashboardBody extends StatelessWidget {
  const _InternalDashboardBody({
    required this.customerSummary,
    required this.workspaceAsync,
    required this.queueAsync,
    required this.capabilities,
  });

  final HomeDashboardSummary customerSummary;
  final AsyncValue<InternalWorkspaceSummary> workspaceAsync;
  final AsyncValue<InternalServiceCaseQueue> queueAsync;
  final AuthCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final workspace = workspaceAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final queue = queueAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final action = _DashboardAction.internal(
      workspace: workspace,
      queue: queue,
    );

    return OmcPageListView(
      topPadding: 18,
      bottomPadding: 32,
      children: [
        const _DashboardHeader(
          eyebrow: 'Operations dashboard',
          title: 'Team overview',
          subtitle: 'Priority queue work before supporting totals.',
          icon: Icons.admin_panel_settings_outlined,
        ),
        if (customerSummary.fallbackMessage?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 12),
          _InlineUnavailable(message: customerSummary.fallbackMessage!.trim()),
        ],
        const SizedBox(height: 18),
        _NextActionCard(action: action),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Service queue',
          subtitle: queueAsync.hasError
              ? 'The service queue could not be refreshed.'
              : 'Highest-priority customer work from the internal queue.',
          actionLabel: 'View all',
          onAction: () => context.go('/internal-workspace/service-cases'),
        ),
        const SizedBox(height: 10),
        if (queueAsync.hasError)
          const _InlineUnavailable(
            message:
                'Service queue unavailable. Existing dashboard totals are not being substituted for queue data.',
          )
        else if (queue == null)
          const AppSkeleton(height: 126, radius: 16)
        else if (queue.cases.isEmpty)
          const _EmptyPanel(
            icon: Icons.check_circle_outline_rounded,
            title: 'No service cases in queue',
            message: 'New customer work will appear here when available.',
          )
        else
          PremiumCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < queue.cases.take(3).length;
                  index++
                ) ...[
                  _InternalCaseRow(serviceCase: queue.cases[index]),
                  if (index != queue.cases.take(3).length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
        const SizedBox(height: 24),
        const _SectionHeader(
          title: 'Operations summary',
          subtitle:
              'Workspace totals remain visibly unavailable while their provider is loading or failed.',
        ),
        const SizedBox(height: 10),
        if (workspaceAsync.hasError)
          const _InlineUnavailable(
            message:
                'Operations summary unavailable. No zero-value fallback is being shown as live data.',
          )
        else if (workspace == null)
          const AppSkeleton(height: 194, radius: 16)
        else
          _InternalSummaryCard(summary: workspace, capabilities: capabilities),
        const SizedBox(height: 24),
        const _SectionHeader(
          title: 'Recent activity',
          subtitle: 'Latest internal-facing dashboard activity.',
        ),
        const SizedBox(height: 10),
        _ActivityCard(
          activities: customerSummary.recentActivity,
          onOpen: () => context.go('/internal-workspace'),
        ),
        const SizedBox(height: 24),
        const _SectionHeader(
          title: 'Internal work areas',
          subtitle: 'Existing Dashboard destinations, capability filtered.',
        ),
        const SizedBox(height: 10),
        _InternalLinks(capabilities: capabilities),
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OmcIconBadge(
          icon: icon,
          color: AppTheme.textSecondary,
          size: 48,
          iconSize: 24,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 26,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({required this.action});

  final _DashboardAction action;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OmcIconBadge(
                icon: action.icon,
                color: action.color,
                size: 44,
                iconSize: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.eyebrow,
                      style: TextStyle(
                        color: action.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      action.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 21,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (action.subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        action.subtitle,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.go(action.route),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(action.buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _CustomerServiceRow extends StatelessWidget {
  const _CustomerServiceRow({required this.service, required this.canOpen});

  final HomeDashboardServiceSnapshot service;
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    final title = service.title.trim().isEmpty
        ? 'OMC service request'
        : service.title.trim();
    final route = service.id.trim().isEmpty
        ? '/my-services'
        : '/my-services/${Uri.encodeComponent(service.id.trim())}';

    return InkWell(
      onTap: canOpen ? () => context.push(route) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OmcIconBadge(
              icon: service.actionRequired
                  ? Icons.priority_high_rounded
                  : Icons.work_outline_rounded,
              color: service.actionRequired ? AppTheme.warning : AppTheme.info,
              size: 42,
              iconSize: 21,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${service.stageLabel} · ${service.statusLabel}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  if (!service.isTerminal && !service.isCompleted) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      label:
                          '${(service.progress * 100).round().clamp(0, 100)} percent complete',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: service.progress.clamp(0, 1).toDouble(),
                          backgroundColor: AppTheme.processingSoft,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (canOpen) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InternalCaseRow extends StatelessWidget {
  const _InternalCaseRow({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final route =
        '/internal-workspace/service-cases/${Uri.encodeComponent(serviceCase.id)}';
    final stage = serviceCase.currentStage?.trim();
    final subtitleParts = <String>[
      serviceCase.displayService,
      if (stage != null && stage.isNotEmpty) stage,
      serviceCase.statusLabel,
    ];

    return InkWell(
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OmcIconBadge(
              icon: serviceCase.isFinancialHold
                  ? Icons.account_balance_wallet_outlined
                  : serviceCase.normalizedLifecycleState == 'activation failed'
                  ? Icons.sync_problem_rounded
                  : Icons.assignment_outlined,
              color:
                  serviceCase.isFinancialHold ||
                      serviceCase.normalizedLifecycleState ==
                          'activation failed'
                  ? AppTheme.danger
                  : AppTheme.info,
              size: 42,
              iconSize: 21,
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
                      fontSize: 16,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleParts.join(' · '),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  if (serviceCase.documentSummaryLabel.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      serviceCase.documentSummaryLabel.trim(),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
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

class _CustomerSummaryCard extends StatelessWidget {
  const _CustomerSummaryCard({
    required this.summary,
    required this.capabilities,
  });

  final HomeDashboardSummary summary;
  final AuthCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final rows = <_SummaryRowData>[
      _SummaryRowData(
        label: 'Active requests',
        value: summary.activeCases,
        icon: Icons.assignment_outlined,
        route: '/my-services',
        available: capabilities.canTrackRequests,
      ),
      _SummaryRowData(
        label: 'Documents needed',
        value: summary.pendingDocuments,
        icon: Icons.folder_copy_outlined,
        route: '/documents',
        available: capabilities.canViewDocuments,
      ),
      _SummaryRowData(
        label: 'Payments due',
        value: summary.paymentsDue,
        icon: Icons.payments_outlined,
        route: '/payments',
        available: capabilities.canViewPayments,
      ),
      _SummaryRowData(
        label: 'Completed requests',
        value: summary.completedCases,
        icon: Icons.check_circle_outline_rounded,
        route: '/my-services',
        available: capabilities.canTrackRequests,
      ),
    ];

    return _SummaryRows(rows: rows);
  }
}

class _InternalSummaryCard extends StatelessWidget {
  const _InternalSummaryCard({
    required this.summary,
    required this.capabilities,
  });

  final InternalWorkspaceSummary summary;
  final AuthCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final rows = <_SummaryRowData>[
      _SummaryRowData(
        label: 'Active customers',
        value: summary.activeCustomers,
        icon: Icons.people_outline_rounded,
        route: '/internal-workspace/customers',
        available: canUseHomeActionCapability(
          'can_manage_customers',
          capabilities,
          allowWithoutRequirement: false,
        ),
      ),
      _SummaryRowData(
        label: 'My assigned services',
        value: summary.myAssignedServices,
        icon: Icons.assignment_ind_outlined,
        route: '/internal-workspace/service-cases',
        available: capabilities.canAccessInternalWorkspace,
      ),
      _SummaryRowData(
        label: 'Pending payments',
        value: summary.pendingPayments,
        icon: Icons.payments_outlined,
        route: '/internal-workspace/payments',
        available: capabilities.canReviewPayments,
      ),
      _SummaryRowData(
        label: 'Pending tasks',
        value: summary.pendingTasks,
        icon: Icons.task_alt_outlined,
        route: '/tasks',
        available: canUseHomeActionCapability(
          'can_manage_tasks',
          capabilities,
          allowWithoutRequirement: false,
        ),
      ),
    ];

    return _SummaryRows(rows: rows);
  }
}

class _SummaryRows extends StatelessWidget {
  const _SummaryRows({required this.rows});

  final List<_SummaryRowData> rows;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _SummaryRow(data: rows[index]),
            if (index != rows.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.data});

  final _SummaryRowData data;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(data.icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              data.label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            data.available ? '${data.value}' : 'Unavailable',
            style: TextStyle(
              color: data.available
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary,
              fontSize: data.available ? 17 : 13,
              fontWeight: data.available ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          if (data.available) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ],
      ),
    );

    if (!data.available) return child;
    return InkWell(onTap: () => context.go(data.route), child: child);
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activities, required this.onOpen});

  final List<HomeDashboardActivity> activities;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final visible = activities.take(6).toList(growable: false);
    if (visible.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.history_rounded,
        title: 'No recent activity',
        message: 'Backend activity will appear here when available.',
      );
    }

    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var index = 0; index < visible.length; index++) ...[
            _ActivityRow(activity: visible[index], onTap: onOpen),
            if (index != visible.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, required this.onTap});

  final HomeDashboardActivity activity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = activity.status?.trim() ?? '';
    final time = activity.createdAtLabel?.trim() ?? '';

    final child = Padding(
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
                      ? 'OMC activity'
                      : activity.title.trim(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (activity.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    activity.subtitle.trim(),
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
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppTheme.textSecondary),
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
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return child;
    return InkWell(onTap: onTap, child: child);
  }
}

class _CustomerLinks extends StatelessWidget {
  const _CustomerLinks({required this.capabilities});

  final AuthCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final links = <_LinkData>[
      if (capabilities.canCreateServiceRequest)
        const _LinkData(
          'Start service',
          Icons.add_business_outlined,
          '/services',
        ),
      if (capabilities.canViewDocuments)
        const _LinkData('Documents', Icons.upload_file_outlined, '/documents'),
      if (capabilities.canViewPayments)
        const _LinkData('Payments', Icons.receipt_long_outlined, '/payments'),
      if (capabilities.canCreateSupportTicket)
        const _LinkData('Support', Icons.support_agent_outlined, '/support'),
      if (capabilities.canUseTaxCalculator)
        const _LinkData(
          'Tax calculator',
          Icons.calculate_outlined,
          '/tax-calculator',
        ),
    ];
    return _LinkCard(
      links: links,
      emptyMessage: 'No extra dashboard links are enabled.',
    );
  }
}

class _InternalLinks extends StatelessWidget {
  const _InternalLinks({required this.capabilities});

  final AuthCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final links = <_LinkData>[
      if (capabilities.canAccessInternalWorkspace)
        const _LinkData(
          'Service queue',
          Icons.list_alt_outlined,
          '/internal-workspace/service-cases',
        ),
      if (capabilities.canReviewDocuments)
        const _LinkData(
          'Document review',
          Icons.folder_special_outlined,
          '/internal-workspace/documents',
        ),
      if (capabilities.canReviewPayments)
        const _LinkData(
          'Payment review',
          Icons.receipt_long_outlined,
          '/internal-workspace/payments',
        ),
      if (canUseHomeActionCapability(
        'can_manage_customers',
        capabilities,
        allowWithoutRequirement: false,
      ))
        const _LinkData(
          'Customers',
          Icons.people_alt_outlined,
          '/internal-workspace/customers',
        ),
      if (canUseHomeActionCapability(
        'can_manage_leads',
        capabilities,
        allowWithoutRequirement: false,
      ))
        const _LinkData('Leads', Icons.leaderboard_outlined, '/leads'),
      if (canUseHomeActionCapability(
        'can_manage_tasks',
        capabilities,
        allowWithoutRequirement: false,
      ))
        const _LinkData('Tasks', Icons.task_alt_outlined, '/tasks'),
    ];
    return _LinkCard(
      links: links,
      emptyMessage: 'No additional work area is enabled for this role.',
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.links, required this.emptyMessage});

  final List<_LinkData> links;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return PremiumCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          emptyMessage,
          style: const TextStyle(
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
          for (var index = 0; index < links.length; index++) ...[
            InkWell(
              onTap: () => context.go(links[index].route),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      links[index].icon,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        links[index].label,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
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
            ),
            if (index != links.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
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

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OmcIconBadge(
                icon: icon,
                color: AppTheme.textSecondary,
                size: 42,
                iconSize: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      message,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _InlineUnavailable extends StatelessWidget {
  const _InlineUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Row(
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
      ),
    );
  }
}

class _DashboardUnavailable extends StatelessWidget {
  const _DashboardUnavailable({
    required this.isInternal,
    required this.onRetry,
  });

  final bool isInternal;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return OmcPageListView(
      topPadding: 18,
      bottomPadding: 32,
      children: [
        _DashboardHeader(
          eyebrow: isInternal ? 'Operations dashboard' : 'Dashboard',
          title: 'Dashboard unavailable',
          subtitle:
              'Live business counts are hidden until the backend summary can be loaded.',
          icon: Icons.cloud_off_outlined,
        ),
        const SizedBox(height: 18),
        PremiumCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Latest dashboard data could not be loaded.',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'No all-zero fallback is being presented as if it were current account data.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry dashboard'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardLoadingView extends StatelessWidget {
  const _DashboardLoadingView();

  @override
  Widget build(BuildContext context) {
    return OmcPageListView(
      topPadding: 18,
      bottomPadding: 32,
      children: const [
        AppSkeleton(height: 82, radius: 16),
        SizedBox(height: 18),
        AppSkeleton(height: 190, radius: 16),
        SizedBox(height: 18),
        AppSkeleton(height: 220, radius: 16),
        SizedBox(height: 18),
        AppSkeleton(height: 190, radius: 16),
      ],
    );
  }
}

class _DashboardAction {
  const _DashboardAction({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.route,
    required this.icon,
    required this.color,
  });

  factory _DashboardAction.customer(HomeDashboardSummary summary) {
    final backend = summary.nextAction;
    if (backend != null && backend.route.trim().isNotEmpty) {
      return _DashboardAction(
        eyebrow: backend.required ? 'Action required' : 'Next action',
        title: backend.title.trim().isEmpty
            ? 'Open your service'
            : backend.title.trim(),
        subtitle: backend.subtitle.trim(),
        buttonLabel: backend.buttonLabel.trim().isEmpty
            ? 'Open'
            : backend.buttonLabel.trim(),
        route: _route(backend.route),
        icon: backend.required
            ? Icons.priority_high_rounded
            : Icons.arrow_circle_right_outlined,
        color: backend.required ? AppTheme.warning : AppTheme.info,
      );
    }

    if (summary.pendingDocuments > 0) {
      return const _DashboardAction(
        eyebrow: 'Action required',
        title: 'Documents need attention',
        subtitle: 'Open Documents to review the current backend requirements.',
        buttonLabel: 'Open documents',
        route: '/documents',
        icon: Icons.folder_copy_outlined,
        color: AppTheme.warning,
      );
    }
    if (summary.paymentsDue > 0) {
      return const _DashboardAction(
        eyebrow: 'Action required',
        title: 'Payment action is due',
        subtitle: 'Open Payments to continue the current payment step.',
        buttonLabel: 'Open payments',
        route: '/payments',
        icon: Icons.payments_outlined,
        color: AppTheme.warning,
      );
    }
    if (summary.activeCases > 0) {
      return const _DashboardAction(
        eyebrow: 'Next action',
        title: 'Review your active service requests',
        subtitle:
            'Open My requests for the latest service status and next steps.',
        buttonLabel: 'View requests',
        route: '/my-services',
        icon: Icons.assignment_outlined,
        color: AppTheme.info,
      );
    }
    return const _DashboardAction(
      eyebrow: 'Next action',
      title: 'Explore OMC services',
      subtitle: 'Browse the service catalogue when you are ready to begin.',
      buttonLabel: 'Browse services',
      route: '/services',
      icon: Icons.add_business_outlined,
      color: AppTheme.info,
    );
  }

  factory _DashboardAction.internal({
    required InternalWorkspaceSummary? workspace,
    required InternalServiceCaseQueue? queue,
  }) {
    if (queue != null) {
      for (final serviceCase in queue.cases) {
        if (serviceCase.isFinancialHold ||
            serviceCase.normalizedLifecycleState == 'activation failed') {
          final title = serviceCase.isFinancialHold
              ? 'Financial hold needs review'
              : 'Activation failure needs recovery';
          return _DashboardAction(
            eyebrow: 'Priority work',
            title: title,
            subtitle:
                '${serviceCase.displayCustomer} · ${serviceCase.displayService}',
            buttonLabel: 'Open service case',
            route:
                '/internal-workspace/service-cases/${Uri.encodeComponent(serviceCase.id)}',
            icon: serviceCase.isFinancialHold
                ? Icons.account_balance_wallet_outlined
                : Icons.sync_problem_rounded,
            color: AppTheme.danger,
          );
        }
      }
    }

    if (workspace != null && workspace.pendingPayments > 0) {
      return _DashboardAction(
        eyebrow: 'Next team action',
        title:
            '${workspace.pendingPayments} payment${workspace.pendingPayments == 1 ? '' : 's'} pending review',
        subtitle: 'Open the payment review queue for backend verification.',
        buttonLabel: 'Review payments',
        route: '/internal-workspace/payments',
        icon: Icons.payments_outlined,
        color: AppTheme.warning,
      );
    }

    if (queue != null && queue.cases.isNotEmpty) {
      return _DashboardAction(
        eyebrow: 'Next team action',
        title:
            '${queue.cases.length} service case${queue.cases.length == 1 ? '' : 's'} in queue',
        subtitle: 'Review current customer service movement in the workspace.',
        buttonLabel: 'Open service queue',
        route: '/internal-workspace/service-cases',
        icon: Icons.list_alt_outlined,
        color: AppTheme.info,
      );
    }

    if (workspace != null && workspace.pendingTasks > 0) {
      return _DashboardAction(
        eyebrow: 'Next team action',
        title:
            '${workspace.pendingTasks} task${workspace.pendingTasks == 1 ? '' : 's'} pending',
        subtitle: 'Open Tasks to review the current assigned work.',
        buttonLabel: 'Open tasks',
        route: '/tasks',
        icon: Icons.task_alt_outlined,
        color: AppTheme.info,
      );
    }

    return const _DashboardAction(
      eyebrow: 'Operations',
      title: 'Open the internal workspace',
      subtitle:
          'Use the workspace for the latest capability-scoped operational queues.',
      buttonLabel: 'Open workspace',
      route: '/internal-workspace',
      icon: Icons.dashboard_outlined,
      color: AppTheme.info,
    );
  }

  final String eyebrow;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final String route;
  final IconData icon;
  final Color color;

  static String _route(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '/dashboard';
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }
}

class _SummaryRowData {
  const _SummaryRowData({
    required this.label,
    required this.value,
    required this.icon,
    required this.route,
    required this.available,
  });

  final String label;
  final int value;
  final IconData icon;
  final String route;
  final bool available;
}

class _LinkData {
  const _LinkData(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}
