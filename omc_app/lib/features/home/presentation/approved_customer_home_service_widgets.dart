part of 'approved_customer_home_view.dart';

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.4;
        final identity = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My OMC',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Semantics(
              header: true,
              child: Text(
                displayName,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  height: 1.12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Your services, actions and next steps',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onNotifications != null) ...[
              _HeaderButton(
                tooltip: 'Notifications',
                icon: Icons.notifications_none_rounded,
                badge: unreadNotifications,
                onTap: onNotifications!,
              ),
              const SizedBox(width: 8),
            ],
            _HeaderButton(
              tooltip: 'Profile',
              icon: Icons.person_outline_rounded,
              onTap: onProfile,
            ),
          ],
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              identity,
              const SizedBox(height: 12),
              actions,
            ],
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
    final semanticLabel = badge > 0 ? '$tooltip, $badge unread' : tooltip;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: AppTouchTarget.minimum,
              height: AppTouchTarget.minimum,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(child: Icon(icon, color: AppTheme.textPrimary)),
                  if (badge > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppTheme.danger,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
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
    final progressPercent =
        (service.progress * 100).round().clamp(0, 100).toInt();

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stack =
                  constraints.maxWidth < 350 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.4;
              final identity = Column(
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    service.title.isEmpty ? 'OMC service request' : service.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 21,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${service.stageLabel} · ${service.statusLabel}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
              final badge = OmcStatusBadge(
                label: service.isTerminal ? 'Closed' : '$progressPercent%',
                color: service.actionRequired
                    ? AppTheme.warning
                    : AppTheme.info,
              );

              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [identity, const SizedBox(height: 10), badge],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 12),
                  badge,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Semantics(
            label: service.isTerminal
                ? 'Service closed'
                : 'Service $progressPercent percent complete',
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: service.progress.clamp(0, 1).toDouble(),
                backgroundColor: AppTheme.primarySoft,
                color: service.actionRequired
                    ? AppTheme.warning
                    : AppTheme.primary,
              ),
            ),
          ),
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
          if (service.milestones.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ServiceJourneyExpansion(milestones: service.milestones),
          ],
        ],
      ),
    );
  }
}

class _ServiceJourneyExpansion extends StatelessWidget {
  const _ServiceJourneyExpansion({required this.milestones});

  final List<HomeDashboardLifecycleMilestone> milestones;

  @override
  Widget build(BuildContext context) {
    final completed = milestones.where((item) => item.isComplete).length;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.route_outlined, color: AppTheme.textSecondary),
        title: const Text(
          'Service journey',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '$completed of ${milestones.length} stages complete',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.35,
          ),
        ),
        children: [
          for (var index = 0; index < milestones.length; index++)
            _MilestoneRow(
              milestone: milestones[index],
              isLast: index == milestones.length - 1,
            ),
        ],
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
          width: 28,
          child: Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: visual.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(visual.icon, size: 14, color: visual.foreground),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: milestone.detail.isEmpty ? 28 : 46,
                  color: AppTheme.border,
                ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (milestone.detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    milestone.detail,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
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
    final tone = action.required ? AppTheme.danger : AppTheme.info;
    return Semantics(
      label: action.required ? 'Required next action' : 'Current update',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tone.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              action.required
                  ? Icons.priority_high_rounded
                  : Icons.info_outline_rounded,
              size: 22,
              color: tone,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.required ? 'Next action' : 'Current update',
                    style: TextStyle(
                      color: tone,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (action.subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      action.subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactServiceCard extends StatelessWidget {
  const _CompactServiceCard({required this.service});

  final HomeDashboardServiceSnapshot service;

  @override
  Widget build(BuildContext context) {
    final label = service.title.isEmpty ? 'OMC service request' : service.title;
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _openService(context, service),
      semanticLabel: '$label, ${service.stageLabel}',
      semanticHint: 'Open service request',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: service.actionRequired
                  ? AppTheme.dangerSoft
                  : AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              service.actionRequired
                  ? Icons.priority_high_rounded
                  : Icons.work_outline_rounded,
              color: service.actionRequired ? AppTheme.danger : AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  service.stageLabel,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OmcIconBadge(
                icon: Icons.check_circle_outline_rounded,
                color: OmcPremium.track,
                size: 50,
                iconSize: 24,
                radius: 14,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No active service requests',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 19,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      completedCases > 0
                          ? 'You have $completedCases completed service request${completedCases == 1 ? '' : 's'}. Start another whenever you need it.'
                          : 'Start an OMC service when you are ready. Your next steps will appear here.',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onStartService != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onStartService,
              icon: const Icon(Icons.grid_view_rounded),
              label: const Text('Explore services'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveServiceCountCard extends StatelessWidget {
  const _ActiveServiceCountCard({
    required this.activeCases,
    required this.onTrackServices,
  });

  final int activeCases;
  final VoidCallback? onTrackServices;

  @override
  Widget build(BuildContext context) {
    final label =
        '$activeCases active service request${activeCases == 1 ? '' : 's'}';

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OmcIconBadge(
                icon: Icons.pending_actions_rounded,
                color: OmcPremium.track,
                size: 50,
                iconSize: 24,
                radius: 14,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 19,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Open My requests to view the tracking information currently available for your active work.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onTrackServices != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onTrackServices,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('View my requests'),
            ),
          ],
        ],
      ),
    );
  }
}
