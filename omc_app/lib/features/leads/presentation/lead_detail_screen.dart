import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
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
      appBar: AppBar(title: const Text('Lead Details')),
      body: leadAsync.when(
        data: (lead) {
          if (lead == null) {
            return PremiumEmptyState(
              icon: Icons.trending_up_rounded,
              title: 'Lead detail unavailable',
              message:
                  'Lead $leadId is ready for the backend detail endpoint. Timeline, notes, and conversion actions will appear once data is available.',
            );
          }

          return _LeadDetailBody(lead: lead);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
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

  return 'Could not load detail from the backend right now. Please try again.';
}

class _LeadDetailBody extends StatelessWidget {
  const _LeadDetailBody({required this.lead});

  final LeadItem lead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = _leadStatusLabel(lead.status);

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
          ],
        ),
        const SizedBox(height: 16),
        const CrmActivityTimelineCard(
          title: 'Activity timeline',
          emptyMessage:
              'No timeline activity yet. Calls, notes, follow-ups, and conversion events will appear here once the backend provides CRM activity data.',
        ),
        const SizedBox(height: 16),
        const CrmDetailInfoCard(
          title: 'Next actions',
          rows: [
            CrmInfoRow(label: 'Notes', value: 'Backend-ready placeholder'),
            CrmInfoRow(label: 'Follow-up', value: 'Backend-ready placeholder'),
            CrmInfoRow(label: 'Conversion', value: 'Backend-ready placeholder'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Lead ID: ${lead.id}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
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
