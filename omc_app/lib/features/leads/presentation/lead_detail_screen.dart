import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/premium_empty_state.dart';
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
        error: (_, _) => PremiumEmptyState(
          icon: Icons.trending_up_rounded,
          title: 'Lead detail unavailable',
          message:
              'Lead $leadId could not be loaded right now. Please try again later.',
        ),
      ),
    );
  }
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
        _DetailHeaderCard(
          icon: Icons.trending_up_rounded,
          title: lead.title,
          subtitle: lead.customerName,
          statusLabel: statusLabel,
        ),
        const SizedBox(height: 16),
        _DetailInfoCard(
          title: 'Contact',
          rows: [
            _InfoRow(label: 'Email', value: lead.email ?? '-'),
            _InfoRow(label: 'Phone', value: lead.phone ?? '-'),
            _InfoRow(label: 'Source', value: lead.source ?? '-'),
            _InfoRow(label: 'Created', value: lead.createdAtLabel ?? '-'),
          ],
        ),
        const SizedBox(height: 16),
        _DetailInfoCard(
          title: 'Next actions',
          rows: const [
            _InfoRow(label: 'Timeline', value: 'Backend-ready placeholder'),
            _InfoRow(label: 'Notes', value: 'Backend-ready placeholder'),
            _InfoRow(label: 'Conversion', value: 'Backend-ready placeholder'),
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

class _DetailHeaderCard extends StatelessWidget {
  const _DetailHeaderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              child: Icon(icon),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Chip(label: Text(statusLabel)),
          ],
        ),
      ),
    );
  }
}

class _DetailInfoCard extends StatelessWidget {
  const _DetailInfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 14),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: row,
              ),
            ),
          ],
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
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}
