import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../home/data/home_dashboard_repository.dart';
import '../../support/application/support_launcher.dart';
import '../data/customer_service_case_repository.dart';
import '../data/service_case_repository.dart';

class CustomerServiceCaseDetailScreen extends ConsumerStatefulWidget {
  const CustomerServiceCaseDetailScreen({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<CustomerServiceCaseDetailScreen> createState() =>
      _CustomerServiceCaseDetailScreenState();
}

class _CustomerServiceCaseDetailScreenState
    extends ConsumerState<CustomerServiceCaseDetailScreen> {
  bool _isCancelling = false;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(customerServiceCaseDetailProvider(widget.caseId));
    final capabilities = ref.watch(authControllerProvider).capabilities;

    Future<void> refresh() async {
      ref.invalidate(customerServiceCaseDetailProvider(widget.caseId));
      await ref.read(customerServiceCaseDetailProvider(widget.caseId).future);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          AppBackHeader(
            title: 'Service Request',
            subtitle: 'Current stage, requirements and next step',
            actionIcon: Icons.support_agent_rounded,
            actionTooltip: 'Contact support',
            onAction: () => SupportLauncher.openWhatsApp(context),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: detailAsync.when(
                loading: () => const _LoadingView(),
                error: (error, _) {
                  final failure = AppFailureClassifier.classify(
                    error,
                    fallbackTitle: 'Service request unavailable',
                    fallbackMessage:
                        'This service request could not be loaded right now.',
                  );
                  return _ErrorView(
                    title: failure.title,
                    message: failure.message,
                    onRetry: failure.canRetry
                        ? () => ref.invalidate(
                            customerServiceCaseDetailProvider(widget.caseId),
                          )
                        : null,
                  );
                },
                data: (detail) {
                  if (detail == null) {
                    return _ErrorView(
                      title: 'Service request not found',
                      message:
                          'This service request is unavailable or is no longer accessible to your account.',
                      onRetry: () => ref.invalidate(
                        customerServiceCaseDetailProvider(widget.caseId),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
                      children: [
                        _ServiceHero(detail: detail),
                        const SizedBox(height: 14),
                        _LifecycleCard(detail: detail),
                        const SizedBox(height: 14),
                        _NextStepCard(
                          detail: detail,
                          canViewDocuments: capabilities.canViewDocuments,
                          canViewPayments: capabilities.canViewPayments,
                        ),
                        const SizedBox(height: 14),
                        _DocumentsCard(
                          detail: detail,
                          canViewDocuments: capabilities.canViewDocuments,
                        ),
                        const SizedBox(height: 14),
                        _PaymentCard(
                          detail: detail,
                          canViewPayments: capabilities.canViewPayments,
                        ),
                        if (detail.activities.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _RecentActivityCard(activities: detail.activities),
                        ],
                        if (detail.canCancel && capabilities.canTrackRequests) ...[
                          const SizedBox(height: 14),
                          _CancelRequestCard(
                            busy: _isCancelling,
                            onCancel: () => _confirmCancel(detail),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(CustomerServiceCaseDetail detail) async {
    if (_isCancelling) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel service request?'),
        content: const Text(
          'This will cancel this request. Existing submitted evidence is not deleted, and you can start a new request later if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      await ref
          .read(customerServiceCaseRepositoryProvider)
          .cancelRequest(detail.id.isEmpty ? widget.caseId : detail.id);
      if (!mounted) return;
      ref.invalidate(customerServiceCaseDetailProvider(widget.caseId));
      ref.invalidate(serviceCasesProvider);
      ref.invalidate(homeDashboardSummaryProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service request cancelled.')),
      );
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackMessage: 'Service request could not be cancelled right now.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }
}

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
    return Container(
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
                child: Text(
                  'Service journey',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
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
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 7,
              backgroundColor: AppTheme.primarySoft,
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
    return Row(
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

class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({required this.detail, required this.canViewDocuments});

  final CustomerServiceCaseDetail detail;
  final bool canViewDocuments;

  @override
  Widget build(BuildContext context) {
    final documents = detail.requiredDocuments;
    final needsUpload = detail.documentsNeedingUpload > 0;

    return PremiumCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Required documents',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          if (documents.isEmpty)
            const Text(
              'No documents are currently required for this service request.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            Text(
              needsUpload
                  ? '${detail.documentsNeedingUpload} required document${detail.documentsNeedingUpload == 1 ? '' : 's'} still need attention.'
                  : 'Your required document checklist is up to date.',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 13),
            for (final document in documents) ...[
              _DocumentRow(document: document),
              const SizedBox(height: 8),
            ],
            if (canViewDocuments && needsUpload) ...[
              const SizedBox(height: 5),
              OutlinedButton.icon(
                onPressed: () => context.go('/documents'),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Open documents'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document});

  final CustomerServiceCaseDocument document;

  @override
  Widget build(BuildContext context) {
    final (label, icon, foreground, background) = switch (
      document.normalizedStatus
    ) {
      'approved' || 'verified' => (
        'Approved',
        Icons.check_circle_outline_rounded,
        const Color(0xFF16864B),
        const Color(0xFFEAF7EF),
      ),
      'rejected' => (
        'Needs correction',
        Icons.error_outline_rounded,
        AppTheme.danger,
        AppTheme.dangerSoft,
      ),
      'uploaded' || 'submitted' || 'under review' => (
        'Under review',
        Icons.hourglass_top_rounded,
        const Color(0xFFA85C00),
        const Color(0xFFFFF4E4),
      ),
      _ => (
        'Required',
        Icons.description_outlined,
        AppTheme.textSecondary,
        AppTheme.background,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: foreground.withValues(alpha: 0.13)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: foreground),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (document.remarks.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    document.remarks,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.detail, required this.canViewPayments});

  final CustomerServiceCaseDetail detail;
  final bool canViewPayments;

  @override
  Widget build(BuildContext context) {
    late final String title;
    late final String message;
    late final IconData icon;
    late final bool showAction;

    if (detail.paymentNotRequired) {
      title = 'No payment required';
      message =
          'This service request has no payment due. You do not need to upload a receipt.';
      icon = Icons.check_circle_outline_rounded;
      showAction = false;
    } else if (detail.paymentNeedsCorrection) {
      title = 'Payment evidence needs correction';
      message =
          'Open payments and submit corrected evidence for this service request.';
      icon = Icons.error_outline_rounded;
      showAction = canViewPayments;
    } else if (detail.paymentUnderReview) {
      title = 'Payment under review';
      message =
          'OMC is reviewing your submitted payment evidence. Do not submit a second payment or receipt unless OMC asks for a correction.';
      icon = Icons.hourglass_top_rounded;
      showAction = canViewPayments;
    } else if (detail.paymentId.isNotEmpty || detail.payableAmount > 0) {
      title = detail.paymentStatus.isEmpty
          ? 'Payment status'
          : detail.paymentStatus;
      message = detail.payableAmount > 0
          ? '${detail.currency.isEmpty ? 'PKR' : detail.currency} ${detail.payableAmount.toStringAsFixed(2)} is recorded for this request.'
          : 'Open payments for the latest payment status.';
      icon = Icons.account_balance_wallet_outlined;
      showAction = canViewPayments;
    } else {
      title = 'Payment not opened yet';
      message =
          'No customer payment action is available right now. OMC will show payment details here if this request reaches a payment stage.';
      icon = Icons.account_balance_wallet_outlined;
      showAction = false;
    }

    return PremiumCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showAction) ...[
            const SizedBox(height: 13),
            OutlinedButton.icon(
              onPressed: () => _openPayments(context, detail),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open payments'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.activities});

  final List<CustomerServiceCaseActivity> activities;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent activity',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          for (var index = 0; index < activities.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == activities.length - 1 ? 0 : 13,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.update_rounded,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activities[index].title,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (activities[index].subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            activities[index].subtitle,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (activities[index].dateLabel.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            activities[index].dateLabel,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
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

class _CancelRequestCard extends StatelessWidget {
  const _CancelRequestCard({required this.busy, required this.onCancel});

  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Request controls',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Cancellation is available only while the backend still considers this request safe to cancel.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : onCancel,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.close_rounded),
            label: Text(busy ? 'Cancelling...' : 'Cancel request'),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
      children: const [
        _LoadingCard(height: 170),
        SizedBox(height: 14),
        _LoadingCard(height: 330),
        SizedBox(height: 14),
        _LoadingCard(height: 140),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});

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

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: PremiumCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 36,
                color: AppTheme.warning,
              ),
              const SizedBox(height: 11),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
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
              if (onRetry != null) ...[
                const SizedBox(height: 13),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

({IconData icon, Color foreground, Color background}) _milestoneVisual(
  CustomerServiceCaseMilestone milestone,
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

bool _canOpenAction(
  CustomerServiceCaseAction action, {
  required bool canViewDocuments,
  required bool canViewPayments,
}) {
  final route = action.route.trim();
  if (route.isEmpty) return false;
  if (route.startsWith('/documents')) return canViewDocuments;
  if (route.startsWith('/payments')) return canViewPayments;
  return true;
}

void _openAction(
  BuildContext context,
  CustomerServiceCaseDetail detail,
  CustomerServiceCaseAction action,
) {
  final route = action.route.trim();
  if (route.startsWith('/payments')) {
    _openPayments(context, detail);
    return;
  }
  if (route.startsWith('/documents')) {
    context.go('/documents');
    return;
  }
  if (route.isNotEmpty && !route.startsWith('/my-services/')) {
    context.push(route.startsWith('/') ? route : '/$route');
  }
}

void _openPayments(BuildContext context, CustomerServiceCaseDetail detail) {
  final paymentId = detail.paymentId.trim();
  if (paymentId.isNotEmpty) {
    context.push('/payments/${Uri.encodeComponent(paymentId)}');
    return;
  }
  context.go('/payments');
}
