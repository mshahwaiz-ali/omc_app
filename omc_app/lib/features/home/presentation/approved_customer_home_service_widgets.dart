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
              Semantics(
                header: true,
                child: Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 26,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
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
    final semanticLabel = badge > 0 ? '$tooltip, $badge unread' : tooltip;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: AppTouchTarget.minimum,
              height: AppTouchTarget.minimum,
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
          if (service.milestones.isNotEmpty) ...[
            const SizedBox(height: 18),
            Semantics(
              header: true,
              child: Text(
                'Service journey',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
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
        style: const TextStyle(
          color: AppTheme.textPrimary,
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
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
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
                  label,
                  maxLines: 2,
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
                  maxLines: 2,
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
