part of 'customer_service_case_detail_screen.dart';

class _ServiceHero extends StatelessWidget {
  const _ServiceHero({required this.detail});

  final CustomerServiceCaseDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 330 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.5;
              final identity = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.description_outlined,
                      color: AppTheme.textSecondary,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      detail.title.isEmpty
                          ? 'OMC service request'
                          : detail.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              );
              final status = _StatusPill(label: detail.statusLabel);

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [identity, const SizedBox(height: 12), status],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 12),
                  status,
                ],
              );
            },
          ),
          if (detail.createdOnBehalf) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.account_circle_outlined,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      detail.submittedByName.isEmpty
                          ? 'Created by OMC on your behalf'
                          : 'Created by ${detail.submittedByName} from OMC on your behalf',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 22,
            runSpacing: 14,
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
    final resolved = label.isEmpty ? 'Open' : label;
    final theme = Theme.of(context);
    return Semantics(
      label: 'Status: $resolved',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          resolved,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.25,
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
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 110, maxWidth: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.35,
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
    final waitingForRequiredDocuments =
        detail.documentsNeedingUpload > 0 &&
        detail.paymentId.isEmpty &&
        !detail.isTerminal &&
        !detail.isCompleted;
    final progress = waitingForRequiredDocuments
        ? detail.progressPercent.clamp(0, 25).toInt()
        : detail.progressPercent.clamp(0, 100).toInt();
    final currentStage = waitingForRequiredDocuments
        ? 'Documents'
        : detail.currentStage.isEmpty
        ? 'Current status'
        : detail.currentStage;
    final theme = Theme.of(context);

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Service journey',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                detail.isTerminal ? 'Closed' : '$progress%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            currentStage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
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
                backgroundColor: AppTheme.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (detail.milestones.isEmpty)
            Text(
              'Lifecycle details are not available yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
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
    final theme = Theme.of(context);

    return Semantics(
      label:
          '${milestone.label}, $semanticState${milestone.detail.isEmpty ? '' : ', ${milestone.detail}'}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: visual.background,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(visual.icon, size: 14, color: visual.foreground),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: milestone.detail.isEmpty ? 28 : 48,
                    color: AppTheme.border,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        milestone.label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (milestone.isSkipped)
                        Text(
                          'Skipped',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  if (milestone.detail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      milestone.detail,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.4,
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
    final waitingForRequiredDocuments =
        detail.documentsNeedingUpload > 0 &&
        detail.paymentId.isEmpty &&
        !detail.isTerminal &&
        !detail.isCompleted;
    final waitingForPaymentOpening =
        detail.requestState.trim().toLowerCase() == 'pending payment' &&
        detail.paymentId.isEmpty &&
        detail.documentsNeedingUpload == 0 &&
        !detail.isTerminal &&
        !detail.isCompleted;

    final action = waitingForRequiredDocuments
        ? const CustomerServiceCaseAction(
            type: 'upload_document',
            title: 'Documents need your attention',
            subtitle:
                'Upload the required documents first. Payment becomes available after the required uploads are complete.',
            route: '/documents',
            buttonLabel: 'Open documents',
            required: true,
          )
        : waitingForPaymentOpening
        ? const CustomerServiceCaseAction(
            type: 'await_payment_opening',
            title: 'Payment details are being prepared',
            subtitle:
                'Your required documents are complete. OMC is preparing the payment step for this request.',
            route: '',
            buttonLabel: '',
            required: false,
          )
        : detail.nextAction;

    if (action == null) return const SizedBox.shrink();

    final canOpen =
        action.route.trim().isNotEmpty &&
        _canOpenAction(
          action,
          canViewDocuments: canViewDocuments,
          canViewPayments: canViewPayments,
        );
    final sameCaseRoute = action.route.trim().startsWith('/my-services/');
    final handledInline =
        detail.documentsNeedingUpload > 0 &&
        action.route.trim().startsWith('/documents');
    final theme = Theme.of(context);

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            action.required ? 'Next action' : 'Current update',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: action.required
                      ? theme.colorScheme.errorContainer.withValues(alpha: 0.45)
                      : AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(
                  action.required
                      ? Icons.priority_high_rounded
                      : Icons.info_outline_rounded,
                  color: action.required
                      ? theme.colorScheme.error
                      : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    if (action.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        action.subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (canOpen && !sameCaseRoute && !handledInline) ...[
            const SizedBox(height: 16),
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
