import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/premium_card.dart';
import '../../support/application/support_launcher.dart';
import '../data/service_case.dart';
import '../data/service_case_repository.dart';

class ServiceCaseDetailScreen extends ConsumerWidget {
  const ServiceCaseDetailScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cases = ref.watch(serviceCasesProvider);
    final serviceCase = _findCase(cases, caseId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Details'),
        actions: [
          IconButton(
            tooltip: 'Support',
            onPressed: () => SupportLauncher.openWhatsApp(context),
            icon: const Icon(Icons.support_agent_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: serviceCase == null
            ? const EmptyState(
                title: 'Case not found',
                message: 'This service case may no longer be available.',
                icon: Icons.search_off_rounded,
              )
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _CaseHero(serviceCase: serviceCase),
                  const SizedBox(height: 16),
                  _ProgressCard(serviceCase: serviceCase),
                  const SizedBox(height: 16),
                  _CaseInfoCard(serviceCase: serviceCase),
                  const SizedBox(height: 16),
                  _RequiredDocumentsCard(serviceCase: serviceCase),
                  const SizedBox(height: 16),
                  _CaseActionsCard(serviceCase: serviceCase),
                  const SizedBox(height: 16),
                  _SupportCard(serviceCase: serviceCase),
                ],
              ),
      ),
    );
  }

  ServiceCase? _findCase(List<ServiceCase> cases, String id) {
    for (final serviceCase in cases) {
      if (serviceCase.id == id || serviceCase.reference == id) {
        return serviceCase;
      }
    }

    return null;
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
            const Icon(Icons.assignment_turned_in_outlined,
                color: Colors.white, size: 34),
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
          for (var index = 0; index < _timelineSteps(serviceCase).length; index++)
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
            'Document upload will connect with the backend once OMC API testing resumes.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          for (final document in documents)
            _DocumentRequirementRow(
              label: document,
              isSubmitted: serviceCase.submittedDocuments.contains(document),
              isMissing: serviceCase.missingDocuments.contains(document),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 19),
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
          Text(
            statusLabel,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseActionsCard extends StatelessWidget {
  const _CaseActionsCard({required this.serviceCase});

  final ServiceCase serviceCase;

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
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Document upload will be enabled after backend integration.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Upload documents'),
          ),
          const SizedBox(height: 10),
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
            'Contact OMC support for updates or document help.',
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
