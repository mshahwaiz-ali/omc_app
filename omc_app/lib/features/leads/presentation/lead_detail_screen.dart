import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/app_back_header.dart';
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
      appBar: const AppBackHeader(title: 'Lead Details'),
      body: leadAsync.when(
        data: (lead) {
          if (lead == null) {
            return PremiumEmptyState(
              icon: Icons.trending_up_rounded,
              title: 'Lead detail unavailable',
              message:
                  'Timeline, notes and conversion actions will appear here when lead details are available.',
            );
          }

          return _LeadDetailBody(lead: lead);
        },
        loading: () => const CrmDetailLoadingView(
          icon: Icons.trending_up_rounded,
          title: 'Loading lead',
          message: 'Fetching contact, timeline and conversion context.',
        ),
        error: (error, _) => PremiumEmptyState(
          icon: Icons.trending_up_rounded,
          title: 'Lead detail unavailable',
          message: _backendErrorMessage(error),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(leadDetailProvider(leadId)),
        ),
      ),
    );
  }
}

String _backendErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  return 'Could not load lead details right now. Please try again.';
}

class _LeadDetailBody extends StatelessWidget {
  const _LeadDetailBody({required this.lead});

  final LeadItem lead;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _leadStatusLabel(lead.status);
    final backendRows = <CrmInfoRow>[
      CrmInfoRow(label: 'Lead ID', value: lead.id),
    ];

    if (lead.serviceInterest != null) {
      backendRows.add(
        CrmInfoRow(label: 'Service interest', value: lead.serviceInterest!),
      );
    }
    if (lead.assignedTo != null) {
      backendRows.add(CrmInfoRow(label: 'Assigned to', value: lead.assignedTo!));
    }
    if (lead.customerProfile != null) {
      backendRows.add(
        CrmInfoRow(label: 'Customer profile', value: lead.customerProfile!),
      );
    }
    if (lead.convertedCustomerProfile != null) {
      backendRows.add(
        CrmInfoRow(
          label: 'Converted customer',
          value: lead.convertedCustomerProfile!,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CrmDetailHeaderCard(
          icon: Icons.trending_up_rounded,
          title: lead.title,
          subtitle: lead.customerName,
          statusLabel: statusLabel,
        ),
        const SizedBox(height: 16),
        CrmDetailInfoCard(
          title: 'Contact',
          rows: [
            CrmInfoRow(label: 'Email', value: lead.email ?? '-'),
            CrmInfoRow(label: 'Phone', value: lead.phone ?? '-'),
            CrmInfoRow(label: 'Source', value: lead.source ?? '-'),
            CrmInfoRow(label: 'Created', value: lead.createdAtLabel ?? '-'),
            CrmInfoRow(label: 'Updated', value: lead.updatedAtLabel ?? '-'),
          ],
        ),
        const SizedBox(height: 16),
        CrmDetailInfoCard(title: 'Backend lead', rows: backendRows),
        const SizedBox(height: 16),
        const CrmActivityTimelineCard(
          title: 'Activity timeline',
          emptyMessage:
              'No timeline activity yet. Calls, notes, follow-ups and conversion events will appear here when activity is available.',
        ),
        const SizedBox(height: 16),
        CrmDetailInfoCard(
          title: 'Next actions',
          rows: [
            CrmInfoRow(
              label: 'Follow-up',
              value: lead.assignedTo == null
                  ? 'No owner assigned yet'
                  : 'Assigned to ${lead.assignedTo}',
            ),
            CrmInfoRow(
              label: 'Conversion',
              value: lead.convertedCustomerProfile ?? 'Not converted yet',
            ),
          ],
        ),
        const SizedBox(height: 8),
        CrmDetailMetaFooter(label: 'Lead ID', value: lead.id),
      ],
    );
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
}
