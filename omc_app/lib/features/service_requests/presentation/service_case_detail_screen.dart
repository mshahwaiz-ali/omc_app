import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_card.dart';
import '../../documents/application/document_attachment_controller.dart';
import '../../support/application/support_launcher.dart';
import '../data/service_case.dart';
import '../data/service_case_repository.dart';
import '../data/service_request_repository.dart';

class ServiceCaseDetailScreen extends ConsumerStatefulWidget {
  const ServiceCaseDetailScreen({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<ServiceCaseDetailScreen> createState() =>
      _ServiceCaseDetailScreenState();
}

class _ServiceCaseDetailScreenState
    extends ConsumerState<ServiceCaseDetailScreen> {
  bool _isUploadingDocument = false;

  @override
  Widget build(BuildContext context) {
    final caseAsync = ref.watch(serviceCaseDetailProvider(widget.caseId));

    return Scaffold(
      body: Column(
        children: [
          AppBackHeader(
            title: 'Service Details',
            subtitle: 'Track request progress and documents',
            actionIcon: Icons.support_agent_rounded,
            actionTooltip: 'Support',
            onAction: () => SupportLauncher.openWhatsApp(context),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: caseAsync.when(
                loading: () => const _CaseDetailLoadingView(),
                error: (error, stackTrace) => _LoadErrorState(
                  title: 'Tracking detail unavailable',
                  message: _cleanErrorMessage(error),
                  onRetry: () =>
                      ref.invalidate(serviceCaseDetailProvider(widget.caseId)),
                  onSupport: () => SupportLauncher.openWhatsApp(context),
                ),
                data: (serviceCase) {
                  if (serviceCase == null) {
                    return _CaseNotFoundState(
                      onSupport: () => SupportLauncher.openWhatsApp(context),
                    );
                  }

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      _CaseHero(serviceCase: serviceCase),
                      const SizedBox(height: 16),
                      _QuickStatusGrid(serviceCase: serviceCase),
                      const SizedBox(height: 16),
                      _ProgressCard(serviceCase: serviceCase),
                      const SizedBox(height: 16),
                      _CaseInfoCard(serviceCase: serviceCase),
                      const SizedBox(height: 16),
                      _RequiredDocumentsCard(serviceCase: serviceCase),
                      const SizedBox(height: 16),
                      _CaseActionsCard(
                        serviceCase: serviceCase,
                        isUploading: _isUploadingDocument,
                        onUploadMissingDocument: () =>
                            _uploadMissingDocument(serviceCase),
                      ),
                      const SizedBox(height: 16),
                      _SupportCard(serviceCase: serviceCase),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadMissingDocument(ServiceCase serviceCase) async {
    if (_isUploadingDocument) return;

    final uploadDocname = _uploadDocnameFor(serviceCase);
    if (uploadDocname == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Upload cannot continue because this case is missing its service reference.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isUploadingDocument = true;
    });

    try {
      final picker = ref.read(documentAttachmentControllerProvider);
      final pickResult = await picker.pickDocuments();

      if (!mounted) return;

      if (pickResult.hasRejectedFiles) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(pickResult.rejectedMessages.join('\n'))),
        );
      }

      if (!pickResult.hasAcceptedFiles) {
        return;
      }

      final repository = ref.read(serviceRequestRepositoryProvider);
      final uploadedFiles = await repository.uploadRequestAttachments(
        requestId: uploadDocname,
        attachments: pickResult.accepted,
      );

      if (!mounted) return;

      ref.invalidate(serviceCaseDetailProvider(widget.caseId));
      ref.invalidate(serviceCasesProvider);

      final uploadedCount = uploadedFiles.length;
      final skippedCount = pickResult.accepted.length - uploadedCount;
      final message = skippedCount > 0
          ? 'Uploaded $uploadedCount document(s). $skippedCount file(s) were skipped because their local path was unavailable.'
          : 'Uploaded $uploadedCount document(s).';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Missing documents could not be uploaded right now. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingDocument = false;
        });
      }
    }
  }

  String? _uploadDocnameFor(ServiceCase serviceCase) {
    final reference = serviceCase.reference?.trim();
    if (reference != null && reference.isNotEmpty) {
      return reference;
    }

    final id = serviceCase.id.trim();
    if (id.isNotEmpty && id != '-') {
      return id;
    }

    return null;
  }
}

class _CaseDetailLoadingView extends StatelessWidget {
  const _CaseDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: const [
        _ServiceLoadingView(
          icon: Icons.fact_check_rounded,
          title: 'Loading case',
          message: 'Fetching request progress, documents and support actions.',
        ),
      ],
    );
  }
}

class _ServiceLoadingView extends StatelessWidget {
  const _ServiceLoadingView({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PremiumCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  right: -30,
                  top: -34,
                  child: Icon(
                    icon,
                    size: 118,
                    color: AppTheme.primaryRed.withValues(alpha: 0.045),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                            color: AppTheme.primaryRed.withValues(alpha: 0.10),
                          ),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 20,
                                height: 1.16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              message,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _CaseLoadingCard(),
        const SizedBox(height: 14),
        const _CaseLoadingCard(),
        const SizedBox(height: 14),
        const _CaseLoadingCard(),
      ],
    );
  }
}

class _CaseLoadingCard extends StatelessWidget {
  const _CaseLoadingCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CaseLoadingBar(widthFactor: 0.72),
                SizedBox(height: 10),
                _CaseLoadingBar(widthFactor: 0.52),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseLoadingBar extends StatelessWidget {
  const _CaseLoadingBar({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 11,
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

String _cleanErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final rawMessage = error.toString().replaceFirst('ApiError:', '').trim();

  if (rawMessage.isEmpty) {
    return 'Service tracking detail is unavailable right now.';
  }

  return rawMessage;
}

class _CaseNotFoundState extends StatelessWidget {
  const _CaseNotFoundState({required this.onSupport});

  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PremiumCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  ),
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  color: AppTheme.primaryRed,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Case not found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This tracking reference may no longer be available, or the server has not returned its detail yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onSupport,
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('Ask support'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onSupport,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PremiumCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  ),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: AppTheme.primaryRed,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSupport,
                      icon: const Icon(Icons.support_agent_rounded),
                      label: const Text('Support'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaseHero extends StatelessWidget {
  const _CaseHero({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryRed, AppTheme.darkRed],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.assignment_turned_in_outlined,
              color: Colors.white,
              size: 34,
            ),
            const SizedBox(height: 14),
            Text(
              serviceCase.category,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              serviceCase.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                height: 1.12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeroPill(label: serviceCase.status),
                if (serviceCase.reference != null)
                  _HeroPill(label: serviceCase.reference!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatusGrid extends StatelessWidget {
  const _QuickStatusGrid({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final progress = serviceCase.progress.clamp(0, 1).toDouble();
    final progressPercent = (progress * 100).round();

    return Row(
      children: [
        Expanded(
          child: _QuickStatusTile(
            icon: Icons.stacked_line_chart_rounded,
            label: 'Progress',
            value: '$progressPercent%',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickStatusTile(
            icon: Icons.file_present_rounded,
            label: 'Missing docs',
            value: serviceCase.missingDocuments.length.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickStatusTile(
            icon: Icons.update_rounded,
            label: 'Updated',
            value: serviceCase.updatedAtLabel,
          ),
        ),
      ],
    );
  }
}

class _QuickStatusTile extends StatelessWidget {
  const _QuickStatusTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final progress = serviceCase.progress.clamp(0, 1).toDouble();
    final progressPercent = (progress * 100).round().toString();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Progress timeline',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$progressPercent%',
                style: const TextStyle(
                  color: AppTheme.primaryRed,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(height: 18),
          for (
            var index = 0;
            index < _timelineSteps(serviceCase).length;
            index++
          )
            _TimelineStep(
              title: _timelineSteps(serviceCase)[index].title,
              subtitle: _timelineSteps(serviceCase)[index].subtitle,
              isDone: _timelineSteps(serviceCase)[index].isDone,
              isLast: index == _timelineSteps(serviceCase).length - 1,
            ),
        ],
      ),
    );
  }

  List<ServiceCaseTimelineStep> _timelineSteps(ServiceCase serviceCase) {
    if (serviceCase.timeline.isNotEmpty) return serviceCase.timeline;

    final progress = serviceCase.progress.clamp(0, 1).toDouble();

    return [
      ServiceCaseTimelineStep(
        title: 'Request received',
        subtitle: serviceCase.createdAtLabel,
        isDone: progress >= 0.05,
      ),
      ServiceCaseTimelineStep(
        title: 'Documents review',
        subtitle: progress >= 0.35 ? 'In progress' : 'Pending',
        isDone: progress >= 0.35,
      ),
      ServiceCaseTimelineStep(
        title: 'OMC processing',
        subtitle: progress >= 0.65 ? 'In progress' : 'Pending',
        isDone: progress >= 0.65,
      ),
      ServiceCaseTimelineStep(
        title: 'Completed',
        subtitle: progress >= 1 ? serviceCase.updatedAtLabel : 'Pending',
        isDone: progress >= 1,
      ),
    ];
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isDone,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final bool isDone;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = isDone ? AppTheme.primaryRed : AppTheme.textSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isDone
                    ? AppTheme.primaryRed
                    : AppTheme.primaryRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDone ? Icons.check_rounded : Icons.circle_outlined,
                size: 16,
                color: isDone ? Colors.white : AppTheme.primaryRed,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: AppTheme.primaryRed.withValues(alpha: 0.12),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CaseInfoCard extends StatelessWidget {
  const _CaseInfoCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Case information',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _InfoRow(label: 'Status', value: serviceCase.status),
          _InfoRow(label: 'Created', value: serviceCase.createdAtLabel),
          _InfoRow(label: 'Updated', value: serviceCase.updatedAtLabel),
          if (serviceCase.nextStep != null)
            _InfoRow(label: 'Next step', value: serviceCase.nextStep!),
          if (serviceCase.remarks != null)
            _InfoRow(label: 'Remarks', value: serviceCase.remarks!),
        ],
      ),
    );
  }
}

class _RequiredDocumentsCard extends StatelessWidget {
  const _RequiredDocumentsCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final documents = _documentsForCase(serviceCase);

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Required documents',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track submitted, missing and required documents for this case.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          for (final document in documents)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DocumentRequirementRow(
                label: document,
                isSubmitted: serviceCase.submittedDocuments.contains(document),
                isMissing: serviceCase.missingDocuments.contains(document),
              ),
            ),
        ],
      ),
    );
  }

  List<String> _documentsForCase(ServiceCase serviceCase) {
    if (serviceCase.requiredDocuments.isNotEmpty) {
      return serviceCase.requiredDocuments;
    }

    return const [
      'CNIC front and back',
      'Relevant business or service documents',
      'Any supporting proof requested by OMC',
    ];
  }
}

class _DocumentRequirementRow extends StatelessWidget {
  const _DocumentRequirementRow({
    required this.label,
    required this.isSubmitted,
    required this.isMissing,
  });

  final String label;
  final bool isSubmitted;
  final bool isMissing;

  @override
  Widget build(BuildContext context) {
    final statusLabel = isSubmitted
        ? 'Submitted'
        : isMissing
        ? 'Missing'
        : 'Required';

    final icon = isSubmitted
        ? Icons.check_circle_rounded
        : isMissing
        ? Icons.error_outline_rounded
        : Icons.description_outlined;

    final statusColor = isSubmitted
        ? const Color(0xFF18864B)
        : isMissing
        ? const Color(0xFFB25E00)
        : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: statusColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseActionsCard extends StatelessWidget {
  const _CaseActionsCard({
    required this.serviceCase,
    required this.isUploading,
    required this.onUploadMissingDocument,
  });

  final ServiceCase serviceCase;
  final bool isUploading;
  final VoidCallback onUploadMissingDocument;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Actions',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (serviceCase.missingDocuments.isNotEmpty) ...[
            _ActionNotice(
              icon: Icons.cloud_upload_outlined,
              title: 'Missing documents required',
              message:
                  'Upload the requested documents directly to this case. Files will be attached to your service request reference.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isUploading ? null : onUploadMissingDocument,
              icon: isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(isUploading ? 'Uploading...' : 'Upload documents'),
            ),
            const SizedBox(height: 10),
          ] else ...[
            _ActionNotice(
              icon: Icons.check_circle_outline_rounded,
              title: 'No missing documents',
              message:
                  'All currently required documents for this case appear submitted.',
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: () => SupportLauncher.openWhatsApp(context),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Ask OMC support'),
          ),
        ],
      ),
    );
  }
}

class _ActionNotice extends StatelessWidget {
  const _ActionNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 22),
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
                const SizedBox(height: 4),
                Text(
                  message,
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
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Need help?',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Contact OMC support for tracking updates, missing documents or urgent follow-up.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => SupportLauncher.openWhatsApp(context),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Ask support'),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
