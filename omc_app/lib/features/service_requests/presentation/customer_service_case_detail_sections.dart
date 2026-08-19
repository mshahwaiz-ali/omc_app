part of 'customer_service_case_detail_screen.dart';

class _ServiceHero extends StatelessWidget {
  const _ServiceHero({required this.detail});

  final CustomerServiceCaseDetail detail;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppTheme.primary,
                  size: 27,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.title.isEmpty ? 'OMC service request' : detail.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _StatusPill(label: detail.statusLabel),
                  ],
                ),
              ),
            ],
          ),
          if (detail.createdOnBehalf) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F7F4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_circle_outlined,
                    size: 19,
                    color: Color(0xFF168D49),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      detail.submittedByName.isEmpty
                          ? 'Created by OMC on your behalf'
                          : 'Created by ${detail.submittedByName} from OMC on your behalf',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _Meta(label: 'Request ID', value: detail.id),
              _Meta(label: 'Requested', value: detail.createdAtLabel),
              _Meta(label: 'Last update', value: detail.updatedAtLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: ${label.isEmpty ? 'Open' : label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primarySoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label.isEmpty ? 'Open' : label,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 105, maxWidth: 190),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LifecycleCard extends StatelessWidget {
  const _LifecycleCard({required this.detail});

  final CustomerServiceCaseDetail detail;

  @override
  Widget build(BuildContext context) {
    final progress = detail.progressPercent.clamp(0, 100).toInt();
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Service journey',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Text(
                detail.isTerminal ? 'Closed' : '$progress%',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            detail.currentStage.isEmpty ? 'Current status' : detail.currentStage,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: detail.isTerminal
                ? 'Service journey closed'
                : 'Service journey $progress percent complete',
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 7,
                backgroundColor: AppTheme.primarySoft,
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (detail.milestones.isEmpty)
            const Text(
              'Lifecycle details are not available yet.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            for (var index = 0; index < detail.milestones.length; index++)
              _MilestoneRow(
                milestone: detail.milestones[index],
                isLast: index == detail.milestones.length - 1,
              ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.milestone, required this.isLast});

  final CustomerServiceCaseMilestone milestone;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final visual = _milestoneVisual(milestone);
    final semanticState = milestone.isSkipped
        ? 'skipped'
        : milestone.isComplete
        ? 'complete'
        : milestone.isAttention
        ? 'needs attention'
        : milestone.isCurrent
        ? 'current'
        : 'pending';

    return Semantics(
      label: '${milestone.label}, $semanticState${milestone.detail.isEmpty ? '' : ', ${milestone.detail}'}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 21,
                  height: 21,
                  decoration: BoxDecoration(
                    color: visual.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(visual.icon, size: 13, color: visual.foreground),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: milestone.detail.isEmpty ? 22 : 37,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          milestone.label,
                          style: TextStyle(
                            color: visual.foreground,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (milestone.isSkipped)
                        const Text(
                          'Skipped',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
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
      ),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({
    required this.detail,
    required this.canViewDocuments,
    required this.canViewPayments,
  });

  final CustomerServiceCaseDetail detail;
  final bool canViewDocuments;
  final bool canViewPayments;

  @override
  Widget build(BuildContext context) {
    final action = detail.nextAction;
    if (action == null) return const SizedBox.shrink();

    final canOpen = _canOpenAction(
      action,
      canViewDocuments: canViewDocuments,
      canViewPayments: canViewPayments,
    );
    final sameCaseRoute = action.route.trim().startsWith('/my-services/');

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: action.required
                      ? AppTheme.dangerSoft
                      : AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  action.required
                      ? Icons.priority_high_rounded
                      : Icons.info_outline_rounded,
                  color: action.required ? AppTheme.danger : AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.required ? 'Next action' : 'Current update',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      action.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (action.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        action.subtitle,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (canOpen && !sameCaseRoute) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => _openAction(context, detail, action),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                action.buttonLabel.isEmpty ? 'Open' : action.buttonLabel,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
