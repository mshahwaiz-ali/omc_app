import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../crm/presentation/widgets/crm_detail_widgets.dart';
import '../data/leads_repository.dart';
import '../domain/lead_item.dart';

class LeadDetailScreen extends ConsumerWidget {
  const LeadDetailScreen({required this.leadId, super.key});

  final String leadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadAsync = ref.watch(leadDetailProvider(leadId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const AppBackHeader(title: 'Lead record'),
      body: leadAsync.when(
        data: (lead) {
          if (lead == null) {
            return const PremiumEmptyState(
              icon: Icons.trending_up_rounded,
              title: 'Lead detail unavailable',
              message:
                  'This lead record is not available in your current scope.',
            );
          }
          return _LeadDetailBody(lead: lead);
        },
        loading: () => const CrmDetailLoadingView(
          icon: Icons.trending_up_rounded,
          title: 'Loading lead',
          message: 'Fetching the current lead record.',
        ),
        error: (error, _) => PremiumEmptyState(
          icon: Icons.trending_up_rounded,
          title: 'Lead detail unavailable',
          message: _leadErrorMessage(error),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(leadDetailProvider(leadId)),
        ),
      ),
    );
  }
}

String _leadErrorMessage(Object error) {
  return AppFailureClassifier.classify(
    error,
    fallbackTitle: 'Data unavailable',
    fallbackMessage: 'Could not load lead details right now. Please try again.',
  ).message;
}

class _LeadDetailBody extends StatelessWidget {
  const _LeadDetailBody({required this.lead});

  final LeadItem lead;

  @override
  Widget build(BuildContext context) {
    final contactRows = <CrmInfoRow>[
      CrmInfoRow(label: 'Email', value: _valueOrNotAdded(lead.email)),
      CrmInfoRow(label: 'Phone', value: _valueOrNotAdded(lead.phone)),
      CrmInfoRow(
        label: 'Service interest',
        value: _valueOrNotAdded(lead.serviceInterest),
      ),
      CrmInfoRow(label: 'Source', value: _valueOrNotAdded(lead.source)),
    ];
    final recordRows = <CrmInfoRow>[
      CrmInfoRow(label: 'Lead ID', value: lead.id),
      CrmInfoRow(
        label: 'Assigned to',
        value: _valueOrNotAdded(lead.assignedTo),
      ),
      CrmInfoRow(
        label: 'Customer profile',
        value: _valueOrNotAdded(lead.customerProfile),
      ),
      CrmInfoRow(
        label: 'Converted customer',
        value: _valueOrNotAdded(lead.convertedCustomerProfile),
      ),
      CrmInfoRow(
        label: 'Created',
        value: _valueOrNotAdded(lead.createdAtLabel),
      ),
      CrmInfoRow(
        label: 'Updated',
        value: _valueOrNotAdded(lead.updatedAtLabel),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = AppLayout.pageInsetFor(constraints.maxWidth);
        final horizontal =
            constraints.maxWidth > AppLayout.generalMaxWidth + inset * 2
            ? (constraints.maxWidth - AppLayout.generalMaxWidth) / 2
            : inset;
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 40),
          children: [
            CrmDetailHeaderCard(
              icon: Icons.trending_up_rounded,
              title: lead.title,
              subtitle: lead.customerName,
              statusLabel: _leadStatusLabel(lead.status),
            ),
            const SizedBox(height: AppSpacing.lg),
            CrmDetailInfoCard(
              title: 'Contact & service interest',
              rows: contactRows,
            ),
            const SizedBox(height: AppSpacing.lg),
            CrmDetailInfoCard(
              title: 'Assignment & conversion record',
              rows: recordRows,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _ActivityAvailability(),
          ],
        );
      },
    );
  }
}

class _ActivityAvailability extends StatelessWidget {
  const _ActivityAvailability();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.history_rounded,
            size: 22,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Detailed lead activity is not available in this mobile detail view. No follow-up or conversion action is available here.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
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

String _valueOrNotAdded(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty || text == '-' ? 'Not added' : text;
}

String _leadStatusLabel(LeadStatus status) {
  switch (status) {
    case LeadStatus.newLead:
      return 'New';
    case LeadStatus.contacted:
      return 'Contacted';
    case LeadStatus.qualified:
      return 'Qualified';
    case LeadStatus.converted:
      return 'Converted';
    case LeadStatus.lost:
      return 'Lost';
    case LeadStatus.unknown:
      return 'Unknown';
  }
}
