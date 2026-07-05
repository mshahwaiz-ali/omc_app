import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';

enum ServiceCaseStatus { inProgress, pendingDocuments, completed }

class MyServicesScreen extends StatelessWidget {
  const MyServicesScreen({super.key});

  static const List<ServiceCaseSummary> serviceCases = [
    ServiceCaseSummary(
      caseId: 'OMC-LOCAL-001',
      serviceTitle: 'Income Tax Return Filing',
      status: ServiceCaseStatus.inProgress,
      submittedDate: 'Local draft',
      amountLabel: 'PKR 0',
      assignedTo: 'OMC Tax Team',
      nextAction: 'Review requirements and upload documents.',
    ),
    ServiceCaseSummary(
      caseId: 'OMC-LOCAL-002',
      serviceTitle: 'NTN Registration',
      status: ServiceCaseStatus.pendingDocuments,
      submittedDate: 'Local draft',
      amountLabel: 'PKR 0',
      assignedTo: 'OMC Registration Desk',
      nextAction: 'CNIC front/back and contact details required.',
    ),
  ];

  static ServiceCaseSummary? findCaseById(String caseId) {
    for (final serviceCase in serviceCases) {
      if (serviceCase.caseId == caseId) return serviceCase;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _MyServicesHeader(
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 0),
              sliver: SliverToBoxAdapter(child: _ServiceStatusOverview()),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Recent Cases',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverList.separated(
                itemCount: serviceCases.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final serviceCase = serviceCases[index];

                  return ServiceCaseCard(
                    serviceCase: serviceCase,
                    onOpenDetails: () => context.push(
                      '/my-services/${Uri.encodeComponent(serviceCase.caseId)}',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceCaseSummary {
  const ServiceCaseSummary({
    required this.caseId,
    required this.serviceTitle,
    required this.status,
    required this.submittedDate,
    required this.amountLabel,
    required this.assignedTo,
    required this.nextAction,
  });

  final String caseId;
  final String serviceTitle;
  final ServiceCaseStatus status;
  final String submittedDate;
  final String amountLabel;
  final String assignedTo;
  final String nextAction;
}

class _MyServicesHeader extends StatelessWidget {
  const _MyServicesHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filled(
          tooltip: 'Back',
          onPressed: onBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primaryRed,
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Services',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Track requests, documents and case progress.',
                style: TextStyle(
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
    );
  }
}

class _ServiceStatusOverview extends StatelessWidget {
  const _ServiceStatusOverview();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _StatusMetricCard(
            label: 'Active',
            value: '1',
            icon: Icons.timelapse_rounded,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatusMetricCard(
            label: 'Pending Docs',
            value: '1',
            icon: Icons.upload_file_rounded,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatusMetricCard(
            label: 'Completed',
            value: '0',
            icon: Icons.verified_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatusMetricCard extends StatelessWidget {
  const _StatusMetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceCaseCard extends StatelessWidget {
  const ServiceCaseCard({
    super.key,
    required this.serviceCase,
    required this.onOpenDetails,
  });

  final ServiceCaseSummary serviceCase;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final statusStyle = serviceCaseStatusStyle(serviceCase.status);

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_outlined,
                  color: AppTheme.primaryRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceCase.serviceTitle,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      serviceCase.caseId,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              ServiceCaseStatusBadge(
                label: statusStyle.label,
                color: statusStyle.color,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CaseInfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Submitted',
            value: serviceCase.submittedDate,
          ),
          _CaseInfoRow(
            icon: Icons.payments_outlined,
            label: 'Amount',
            value: serviceCase.amountLabel,
          ),
          _CaseInfoRow(
            icon: Icons.support_agent_outlined,
            label: 'Assigned',
            value: serviceCase.assignedTo,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              serviceCase.nextAction,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: 'View Case Details',
            icon: Icons.arrow_forward_rounded,
            onPressed: onOpenDetails,
          ),
        ],
      ),
    );
  }
}

class _CaseInfoRow extends StatelessWidget {
  const _CaseInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceCaseStatusBadge extends StatelessWidget {
  const ServiceCaseStatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class ServiceCaseStatusStyle {
  const ServiceCaseStatusStyle(this.label, this.color);

  final String label;
  final Color color;
}

ServiceCaseStatusStyle serviceCaseStatusStyle(ServiceCaseStatus status) {
  switch (status) {
    case ServiceCaseStatus.inProgress:
      return const ServiceCaseStatusStyle('In Progress', Colors.blue);
    case ServiceCaseStatus.pendingDocuments:
      return const ServiceCaseStatusStyle('Pending Docs', Colors.orange);
    case ServiceCaseStatus.completed:
      return const ServiceCaseStatusStyle('Completed', Colors.green);
  }
}
