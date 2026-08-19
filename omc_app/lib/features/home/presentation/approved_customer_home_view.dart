import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/effective_capabilities_provider.dart';
import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/premium_card.dart';
import '../../profile/data/profile_repository.dart';
import '../data/home_dashboard_repository.dart';

class ApprovedCustomerHomeView extends ConsumerWidget {
  const ApprovedCustomerHomeView({
    super.key,
    this.onOpenServices,
    this.onOpenCalculator,
    this.onOpenSupport,
    this.onOpenNotifications,
  });

  final VoidCallback? onOpenServices;
  final VoidCallback? onOpenCalculator;
  final VoidCallback? onOpenSupport;
  final VoidCallback? onOpenNotifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(homeDashboardSummaryProvider);
    final capabilities = ref.watch(effectiveCapabilitiesProvider);
    final profileAsync = ref.watch(profileSummaryProvider);
    final profileName = profileAsync.maybeWhen(
      data: (profile) => profile.displayName.trim(),
      orElse: () => '',
    );

    Future<void> refresh() async {
      ref.invalidate(homeDashboardSummaryProvider);
      ref.invalidate(profileSummaryProvider);
      await ref.read(homeDashboardSummaryProvider.future);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: dashboardAsync.when(
          loading: () => const _CustomerHomeLoading(),
          error: (error, _) => RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 150),
              children: [
                _HomeHeader(
                  name: profileName,
                  unreadNotifications: 0,
                  onNotifications: capabilities.canViewCustomerNotifications
                      ? () => _openNotifications(context)
                      : null,
                  onProfile: () => context.push('/profile'),
                ),
                const SizedBox(height: 18),
                _HomeError(
                  message: AppFailureClassifier.classify(
                    error,
                    fallbackTitle: 'Home unavailable',
                    fallbackMessage:
                        'Your latest OMC service status could not be loaded.',
                  ).message,
                  onRetry: () => ref.invalidate(homeDashboardSummaryProvider),
                ),
              ],
            ),
          ),
          data: (summary) => RefreshIndicator(
            onRefresh: refresh,
            child: _CustomerHomeContent(
              summary: summary,
              customerName: profileName,
              onNotifications: capabilities.canViewCustomerNotifications
                  ? () => _openNotifications(context)
                  : null,
              onProfile: () => context.push('/profile'),
              onOpenServices: onOpenServices ?? () => context.go('/services'),
              onOpenCalculator:
                  onOpenCalculator ?? () => context.push('/tax-calculator'),
              onOpenSupport: capabilities.canCreateSupportTicket
                  ? onOpenSupport ?? () => context.push('/support')
                  : null,
              onOpenDocuments: capabilities.canViewDocuments
                  ? () => context.push('/documents')
                  : null,
              onOpenPayments: capabilities.canViewPayments
                  ? () => context.push('/payments')
                  : null,
              onTrackServices: capabilities.canTrackRequests
                  ? () => context.go('/my-services')
                  : null,
              canStartService: capabilities.canCreateServiceRequest,
            ),
          ),
        ),
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    if (onOpenNotifications != null) {
      onOpenNotifications!();
      return;
    }
    context.push('/notifications');
  }
}

class _CustomerHomeContent extends StatelessWidget {
  const _CustomerHomeContent({
    required this.summary,
    required this.customerName,
    required this.onNotifications,
    required this.onProfile,
    required this.onOpenServices,
    required this.onOpenCalculator,
    required this.onOpenSupport,
    required this.onOpenDocuments,
    required this.onOpenPayments,
    required this.onTrackServices,
    required this.canStartService,
  });

  final HomeDashboardSummary summary;
  final String customerName;
  final VoidCallback? onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onOpenServices;
  final VoidCallback onOpenCalculator;
  final VoidCallback? onOpenSupport;
  final VoidCallback? onOpenDocuments;
  final VoidCallback? onOpenPayments;
  final VoidCallback? onTrackServices;
  final bool canStartService;

  @override
  Widget build(BuildContext context) {
    final current = summary.serviceSnapshots.isEmpty
        ? null
        : summary.serviceSnapshots.first;
    final otherServices = summary.serviceSnapshots.length <= 1
        ? const <HomeDashboardServiceSnapshot>[]
        : summary.serviceSnapshots.skip(1).take(2).toList(growable: false);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 150),
      children: [
        _HomeHeader(
          name: customerName,
          unreadNotifications: summary.unreadNotifications,
          onNotifications: onNotifications,
          onProfile: onProfile,
        ),
        const SizedBox(height: 20),
        if (current != null)
          _CurrentServiceCard(service: current)
        else
          _NoActiveServiceCard(
            completedCases: summary.completedCases,
            onStartService: canStartService ? onOpenServices : null,
          ),
        const SizedBox(height: 16),
        _AtAGlance(summary: summary),
        if (otherServices.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Other active services',
            actionLabel: onTrackServices == null ? null : 'View all',
            onAction: onTrackServices,
          ),
          const SizedBox(height: 10),
          for (final service in otherServices) ...[
            _CompactServiceCard(service: service),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 24),
        const _SectionHeader(title: 'Quick actions'),
        const SizedBox(height: 12),
        _QuickActions(
          onTrackServices: onTrackServices,
          onOpenDocuments: onOpenDocuments,
          onOpenPayments: onOpenPayments,
          onOpenSupport: onOpenSupport,
          onOpenServices: canStartService ? onOpenServices : null,
        ),
        const SizedBox(height: 24),
        const _SectionHeader(title: 'Explore OMC'),
        const SizedBox(height: 12),
        _ExploreCard(
          onOpenServices: onOpenServices,
          onOpenCalculator: onOpenCalculator,
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.name,
    required this.unreadNotifications,
    required this.onNotifications,
    required this.onProfile,
  });

  final String name;
  final int unreadNotifications;
  final VoidCallback? onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isEmpty ? 'Your OMC' : name.trim();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My OMC',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Your services, actions and next steps',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (onNotifications != null) ...[
          _HeaderButton(
            tooltip: 'Notifications',
            icon: Icons.notifications_none_rounded,
            badge: unreadNotifications,
            onTap: onNotifications!,
          ),
          const SizedBox(width: 9),
        ],
        _HeaderButton(
          tooltip: 'Profile',
          icon: Icons.person_outline_rounded,
          onTap: onProfile,
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppTheme.border),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(child: Icon(icon, color: AppTheme.textPrimary)),
                if (badge > 0)
                  Positioned(
                    right: 5,
                    top: 5,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppTheme.danger,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentServiceCard extends StatelessWidget {
  const _CurrentServiceCard({required this.service});

  final HomeDashboardServiceSnapshot service;

  @override
  Widget build(BuildContext context) {
    final action = service.nextAction;
    final progressPercent = (service.progress * 100).round().clamp(0, 100);

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.actionRequired
                          ? 'Needs your attention'
                          : 'Current service',
                      style: TextStyle(
                        color: service.actionRequired
                            ? AppTheme.danger
                            : AppTheme.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      service.title.isEmpty ? 'OMC service request' : service.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 21,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${service.stageLabel} · ${service.statusLabel}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ProgressBadge(
                percent: progressPercent,
                attention: service.actionRequired,
                terminal: service.isTerminal,
              ),
            ],
          ),
          const SizedBox(height: 17),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: service.progress.clamp(0, 1),
              backgroundColor: AppTheme.primarySoft,
              color: service.actionRequired ? AppTheme.warning : AppTheme.primary,
            ),
          ),
          if (service.milestones.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'Service journey',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < service.milestones.length; index++)
              _MilestoneRow(
                milestone: service.milestones[index],
                isLast: index == service.milestones.length - 1,
              ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            _NextStepPanel(action: action),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _openAction(context, service, action),
              icon: Icon(
                action.required
                    ? Icons.arrow_forward_rounded
                    : Icons.visibility_outlined,
              ),
              label: Text(
                action.buttonLabel.trim().isEmpty
                    ? 'Open service'
                    : action.buttonLabel,
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _openService(context, service),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('View service'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({
    required this.percent,
    required this.attention,
    required this.terminal,
  });

  final int percent;
  final bool attention;
  final bool terminal;

  @override
  Widget build(BuildContext context) {
    final label = terminal ? 'Closed' : '$percent%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: attention ? AppTheme.dangerSoft : AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: attention ? AppTheme.danger : AppTheme.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.milestone, required this.isLast});

  final HomeDashboardLifecycleMilestone milestone;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final visual = _milestoneVisual(milestone);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 26,
          child: Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: visual.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(visual.icon, size: 13, color: visual.foreground),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: milestone.detail.isEmpty ? 22 : 36,
                  color: AppTheme.border,
                ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.label,
                  style: TextStyle(
                    color: visual.foreground,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (milestone.detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    milestone.detail,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NextStepPanel extends StatelessWidget {
  const _NextStepPanel({required this.action});

  final HomeDashboardNextAction action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: action.required ? AppTheme.dangerSoft : AppTheme.cardSoft,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: action.required
              ? AppTheme.danger.withValues(alpha: 0.22)
              : AppTheme.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            action.required
                ? Icons.priority_high_rounded
                : Icons.info_outline_rounded,
            size: 20,
            color: action.required ? AppTheme.danger : AppTheme.info,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (action.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    action.subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AtAGlance extends StatelessWidget {
  const _AtAGlance({required this.summary});

  final HomeDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniMetric(
            value: summary.activeCases,
            label: 'Active',
            icon: Icons.work_outline_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniMetric(
            value: summary.pendingDocuments,
            label: 'Docs needed',
            icon: Icons.description_outlined,
            attention: summary.pendingDocuments > 0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniMetric(
            value: summary.paymentsDue,
            label: 'Payments',
            icon: Icons.account_balance_wallet_outlined,
            attention: summary.paymentsDue > 0,
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.value,
    required this.label,
    required this.icon,
    this.attention = false,
  });

  final int value;
  final String label;
  final IconData icon;
  final bool attention;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 11, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: attention
              ? AppTheme.warning.withValues(alpha: 0.30)
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: attention ? AppTheme.warning : AppTheme.textSecondary,
          ),
          const SizedBox(height: 9),
          Text(
            '$value',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 19,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactServiceCard extends StatelessWidget {
  const _CompactServiceCard({required this.service});

  final HomeDashboardServiceSnapshot service;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _openService(context, service),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: service.actionRequired
                  ? AppTheme.dangerSoft
                  : AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              service.actionRequired
                  ? Icons.priority_high_rounded
                  : Icons.work_outline_rounded,
              color: service.actionRequired
                  ? AppTheme.danger
                  : AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  service.stageLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}

class _NoActiveServiceCard extends StatelessWidget {
  const _NoActiveServiceCard({
    required this.completedCases,
    required this.onStartService,
  });

  final int completedCases;
  final VoidCallback? onStartService;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.check_circle_outline_rounded),
          ),
          const SizedBox(height: 15),
          const Text(
            'No active service requests',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            completedCases > 0
                ? 'You have $completedCases completed service request${completedCases == 1 ? '' : 's'}. Start another service whenever you need it.'
                : 'Start an OMC service when you are ready. Your next steps will appear here.',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onStartService != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onStartService,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Explore services'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({this.title = '', this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onTrackServices,
    required this.onOpenDocuments,
    required this.onOpenPayments,
    required this.onOpenSupport,
    required this.onOpenServices,
  });

  final VoidCallback? onTrackServices;
  final VoidCallback? onOpenDocuments;
  final VoidCallback? onOpenPayments;
  final VoidCallback? onOpenSupport;
  final VoidCallback? onOpenServices;

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      if (onTrackServices != null)
        _QuickAction('My services', Icons.track_changes_rounded, onTrackServices!),
      if (onOpenDocuments != null)
        _QuickAction('Documents', Icons.description_outlined, onOpenDocuments!),
      if (onOpenPayments != null)
        _QuickAction('Payments', Icons.account_balance_wallet_outlined, onOpenPayments!),
      if (onOpenSupport != null)
        _QuickAction('Get help', Icons.support_agent_outlined, onOpenSupport!),
      if (onOpenServices != null)
        _QuickAction('New service', Icons.add_circle_outline_rounded, onOpenServices!),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: action.onTap,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(action.icon, color: AppTheme.primary, size: 23),
                  const SizedBox(height: 8),
                  Text(
                    action.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({
    required this.onOpenServices,
    required this.onOpenCalculator,
  });

  final VoidCallback onOpenServices;
  final VoidCallback onOpenCalculator;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          _ExploreRow(
            icon: Icons.grid_view_rounded,
            title: 'Browse OMC services',
            subtitle: 'Start a new service from the full catalogue.',
            onTap: onOpenServices,
          ),
          const Divider(height: 22),
          _ExploreRow(
            icon: Icons.calculate_outlined,
            title: 'Tax calculator',
            subtitle: 'Estimate tax before starting a filing service.',
            onTap: onOpenCalculator,
          ),
        ],
      ),
    );
  }
}

class _ExploreRow extends StatelessWidget {
  const _ExploreRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primary),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
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

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 34, color: AppTheme.warning),
          const SizedBox(height: 12),
          const Text(
            'Latest status unavailable',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _CustomerHomeLoading extends StatelessWidget {
  const _CustomerHomeLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 150),
      children: const [
        _LoadingPanel(height: 70),
        SizedBox(height: 18),
        _LoadingPanel(height: 360),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _LoadingPanel(height: 92)),
            SizedBox(width: 8),
            Expanded(child: _LoadingPanel(height: 92)),
            SizedBox(width: 8),
            Expanded(child: _LoadingPanel(height: 92)),
          ],
        ),
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
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

({IconData icon, Color foreground, Color background}) _milestoneVisual(
  HomeDashboardLifecycleMilestone milestone,
) {
  if (milestone.isComplete) {
    return (
      icon: Icons.check_rounded,
      foreground: AppTheme.success,
      background: AppTheme.success.withValues(alpha: 0.12),
    );
  }
  if (milestone.isSkipped) {
    return (
      icon: Icons.remove_rounded,
      foreground: AppTheme.textSecondary,
      background: AppTheme.primarySoft,
    );
  }
  if (milestone.isAttention) {
    return (
      icon: Icons.priority_high_rounded,
      foreground: AppTheme.danger,
      background: AppTheme.dangerSoft,
    );
  }
  if (milestone.isCurrent) {
    return (
      icon: Icons.circle,
      foreground: AppTheme.info,
      background: AppTheme.info.withValues(alpha: 0.12),
    );
  }
  return (
    icon: Icons.circle_outlined,
    foreground: AppTheme.textSecondary,
    background: AppTheme.primarySoft,
  );
}

void _openAction(
  BuildContext context,
  HomeDashboardServiceSnapshot service,
  HomeDashboardNextAction action,
) {
  final route = action.route.trim();
  if (route.isEmpty) {
    _openService(context, service);
    return;
  }
  context.push(route.startsWith('/') ? route : '/$route');
}

void _openService(BuildContext context, HomeDashboardServiceSnapshot service) {
  if (service.id.trim().isEmpty) {
    context.go('/my-services');
    return;
  }
  context.push('/my-services/${Uri.encodeComponent(service.id)}');
}
