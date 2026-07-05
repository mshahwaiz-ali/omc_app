import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/premium_card.dart';
import '../../support/application/support_launcher.dart';
import 'my_services_screen.dart';

class ServiceCaseDetailScreen extends StatelessWidget {
  const ServiceCaseDetailScreen({super.key, required this.caseId});

  final String caseId;

  static const List<ServiceCaseTimelineEntry> _timelineEntries = [
    ServiceCaseTimelineEntry(
      title: 'Request created',
      description: 'Your case has been recorded in local testing mode.',
      timestampLabel: 'Today',
      isCompleted: true,
    ),
    ServiceCaseTimelineEntry(
      title: 'Documents review',
      description: 'OMC team will verify uploaded files and requirements.',
      timestampLabel: 'Next',
      isCompleted: false,
    ),
    ServiceCaseTimelineEntry(
      title: 'Processing',
      description: 'Case will move to tax/compliance processing.',
      timestampLabel: 'Pending',
      isCompleted: false,
    ),
    ServiceCaseTimelineEntry(
      title: 'Completed',
      description: 'Final documents and confirmation will appear here.',
      timestampLabel: 'Pending',
      isCompleted: false,
    ),
  ];

  static const List<ServiceCaseDocumentRequirement> _documentRequirements = [
    ServiceCaseDocumentRequirement(
      title: 'CNIC Front',
      statusLabel: 'Required',
      icon: Icons.badge_outlined,
    ),
    ServiceCaseDocumentRequirement(
      title: 'CNIC Back',
      statusLabel: 'Required',
      icon: Icons.badge_outlined,
    ),
    ServiceCaseDocumentRequirement(
      title: 'Income Details',
      statusLabel: 'Pending',
      icon: Icons.receipt_long_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final serviceCase = MyServicesScreen.findCaseById(caseId);

    if (serviceCase == null) {
      return Scaffold(
        body: SafeArea(
          child: EmptyState(
            title: 'Case not found',
            message: 'This service case is not available in local test data.',
            icon: Icons.search_off_rounded,
            actionLabel: 'Go back',
            onAction: () => Navigator.of(context).maybePop(),
          ),
        ),
      );
    }

    final statusStyle = serviceCaseStatusStyle(serviceCase.status);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _CaseDetailHeader(
                  serviceCase: serviceCase,
                  statusStyle: statusStyle,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _CaseSummaryCard(serviceCase: serviceCase),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(title: 'Timeline'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              sliver: SliverList.separated(
                itemCount: _timelineEntries.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _TimelineEntryCard(entry: _timelineEntries[index]);
                },
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(title: 'Required Documents'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              sliver: SliverList.separated(
                itemCount: _documentRequirements.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _DocumentRequirementTile(
                    documentRequirement: _documentRequirements[index],
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              sliver: SliverToBoxAdapter(
                child: _CaseSupportCard(serviceCase: serviceCase),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceCaseTimelineEntry {
  const ServiceCaseTimelineEntry({
    required this.title,
    required this.description,
    required this.timestampLabel,
    required this.isCompleted,
  });

  final String title;
  final String description;
  final String timestampLabel;
  final bool isCompleted;
}

class ServiceCaseDocumentRequirement {
  const ServiceCaseDocumentRequirement({
    required this.title,
    required this.statusLabel,
    required this.icon,
  });

  final String title;
  final String statusLabel;
  final IconData icon;
}

class _CaseDetailHeader extends StatelessWidget {
  const _CaseDetailHeader({
    required this.serviceCase,
    required this.statusStyle,
    required this.onBack,
  });

  final ServiceCaseSummary serviceCase;
  final ServiceCaseStatusStyle statusStyle;
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Case Details',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                serviceCase.caseId,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
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
    );
  }
}

class _CaseSummaryCard extends StatelessWidget {
  const _CaseSummaryCard({required this.serviceCase});

  final ServiceCaseSummary serviceCase;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            serviceCase.serviceTitle,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Submitted', value: serviceCase.submittedDate),
          _SummaryRow(label: 'Amount', value: serviceCase.amountLabel),
          _SummaryRow(label: 'Assigned', value: serviceCase.assignedTo),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              serviceCase.nextAction,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _TimelineEntryCard extends StatelessWidget {
  const _TimelineEntryCard({required this.entry});

  final ServiceCaseTimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = entry.isCompleted ? Colors.green : AppTheme.textSecondary;

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            entry.isCompleted
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.description,
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
          const SizedBox(width: 10),
          Text(
            entry.timestampLabel,
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

class _DocumentRequirementTile extends StatelessWidget {
  const _DocumentRequirementTile({required this.documentRequirement});

  final ServiceCaseDocumentRequirement documentRequirement;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(documentRequirement.icon, color: AppTheme.primaryRed),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              documentRequirement.title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            documentRequirement.statusLabel,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseSupportCard extends StatelessWidget {
  const _CaseSupportCard({required this.serviceCase});

  final ServiceCaseSummary serviceCase;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Need help?',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Contact OMC support for document requirements, payment updates or case progress.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: 'Contact Support',
            icon: Icons.support_agent_rounded,
            onPressed: () => SupportLauncher.openWhatsApp(context),
          ),
        ],
      ),
    );
  }
}
