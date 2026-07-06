import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../../core/widgets/premium_list_header.dart';
import '../../support/application/support_launcher.dart';
import '../data/service_case.dart';
import '../data/service_case_repository.dart';

class MyServicesScreen extends ConsumerWidget {
  const MyServicesScreen({super.key});

  static ServiceCase? findCaseById(List<ServiceCase> cases, String caseId) {
    for (final serviceCase in cases) {
      if (serviceCase.id == caseId || serviceCase.reference == caseId) {
        return serviceCase;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesAsync = ref.watch(serviceCasesProvider);

    return Scaffold(
      body: SafeArea(
        top: true,
        child: casesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _LoadErrorState(
            title: 'Service tracking unavailable',
            message: _cleanErrorMessage(error),
            onRetry: () => ref.invalidate(serviceCasesProvider),
            onStartRequest: () => context.go('/services'),
          ),
          data: (cases) => cases.isEmpty
              ? _EmptyServicesState(
                  onStartRequest: () => context.go('/services'),
                )
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    _HeaderCard(cases: cases),
                    const SizedBox(height: 16),
                    for (final serviceCase in cases)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ServiceCaseCard(serviceCase: serviceCase),
                      ),
                  ],
                ),
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
    return 'Service tracking is unavailable right now. Submitted requests are still sent to OMC.';
  }

  return rawMessage;
}

class _EmptyServicesState extends StatelessWidget {
  const _EmptyServicesState({required this.onStartRequest});

  final VoidCallback onStartRequest;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PremiumCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.assignment_add,
                color: AppTheme.primaryRed,
                size: 44,
              ),
              const SizedBox(height: 14),
              const Text(
                'No service requests yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start a guided request from the catalogue. Active cases will appear here when tracking data is available.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onStartRequest,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Start a request'),
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
    required this.onStartRequest,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onStartRequest;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PremiumCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppTheme.primaryRed,
                size: 42,
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
                      onPressed: onStartRequest,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New request'),
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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.cases});

  final List<ServiceCase> cases;

  @override
  Widget build(BuildContext context) {
    final activeCount = cases
        .where((item) => !item.status.toLowerCase().contains('complete'))
        .length;
    final completedCount = cases
        .where((item) => item.status.toLowerCase().contains('complete'))
        .length;
    final missingDocsCount = cases
        .where((item) => item.missingDocuments.isNotEmpty)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumListHeader(
          icon: Icons.track_changes_rounded,
          title: 'Track',
          subtitle:
              'View active requests, document requirements and completion status.',
          metaLabel: '${cases.length} total',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _HeaderStat(
                value: activeCount.toString(),
                label: 'Active',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HeaderStat(
                value: missingDocsCount.toString(),
                label: 'Need docs',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HeaderStat(
                value: completedCount.toString(),
                label: 'Done',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCaseCard extends StatelessWidget {
  const _ServiceCaseCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final progressPercent = (serviceCase.progress.clamp(0, 1) * 100)
        .round()
        .toString();

    return PremiumCard(
      onTap: () => context.go('/my-services/${serviceCase.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusIcon(status: serviceCase.status),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  serviceCase.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PremiumInfoChip(
                icon: Icons.category_outlined,
                label: serviceCase.category,
              ),
              ServiceCaseStatusBadge(status: serviceCase.status),
              if (serviceCase.reference != null)
                PremiumInfoChip(
                  icon: Icons.confirmation_number_outlined,
                  label: serviceCase.reference!,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: serviceCase.progress.clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: AppTheme.primaryRed.withValues(
                      alpha: 0.08,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$progressPercent%',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (serviceCase.nextStep != null &&
              serviceCase.nextStep!.trim().isNotEmpty)
            _DetailRow(
              icon: Icons.flag_outlined,
              label: 'Next step',
              value: serviceCase.nextStep!,
            ),
          if (serviceCase.missingDocuments.isNotEmpty)
            _DetailRow(
              icon: Icons.warning_amber_rounded,
              label: 'Missing docs',
              value: '${serviceCase.missingDocuments.length} required',
            ),
          _DetailRow(
            icon: Icons.update_rounded,
            label: 'Updated',
            value: serviceCase.updatedAtLabel,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/my-services/${serviceCase.id}'),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View details'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Ask support',
                onPressed: () => SupportLauncher.openWhatsApp(context),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final icon = normalized.contains('complete')
        ? Icons.check_circle_rounded
        : normalized.contains('document')
        ? Icons.description_outlined
        : Icons.pending_actions_rounded;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: AppTheme.primaryRed, size: 23),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: value,
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
          ),
        ],
      ),
    );
  }
}

class ServiceCaseStatusBadge extends StatelessWidget {
  const ServiceCaseStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final style = serviceCaseStatusStyle(status);

    return PremiumInfoChip(
      icon: style.icon,
      label: style.label,
      color: AppTheme.primaryRed,
    );
  }
}

ServiceCaseStatusStyle serviceCaseStatusStyle(String status) {
  return ServiceCaseStatusStyle(
    icon: status.toLowerCase().contains('complete')
        ? Icons.check_circle_rounded
        : status.toLowerCase().contains('document')
        ? Icons.description_outlined
        : Icons.pending_actions_rounded,
    label: status,
  );
}
