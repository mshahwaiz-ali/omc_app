import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/premium_card.dart';
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
      appBar: AppBar(
        title: const Text('My Services'),
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
        child: casesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => EmptyState(
            title: 'Unable to load services',
            message: error.toString(),
            icon: Icons.cloud_off_rounded,
          ),
          data: (cases) => cases.isEmpty
              ? const EmptyState(
                  title: 'No service requests yet',
                  message:
                      'Start a request from the service catalogue to track it here.',
                  icon: Icons.assignment_outlined,
                )
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    const _HeaderCard(),
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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

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
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.track_changes_rounded, color: Colors.white, size: 34),
            SizedBox(height: 14),
            Text(
              'Track your OMC work',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                height: 1.12,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'View active requests, document requirements and completion status.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCaseCard extends StatelessWidget {
  const _ServiceCaseCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final progressPercent =
        (serviceCase.progress.clamp(0, 1) * 100).round().toString();

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
              _InfoPill(label: serviceCase.category),
              _InfoPill(label: serviceCase.status),
              if (serviceCase.reference != null)
                _InfoPill(label: serviceCase.reference!),
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
                    backgroundColor:
                        AppTheme.primaryRed.withValues(alpha: 0.08),
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
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
    return _InfoPill(label: status);
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
