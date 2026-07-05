import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/leads_repository.dart';
import '../domain/lead_item.dart';

class LeadsScreen extends ConsumerWidget {
  const LeadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadsAsync = ref.watch(leadsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Leads')),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(leadsProvider);
          return ref.read(leadsProvider.future);
        },
        child: leadsAsync.when(
          data: (leads) => _LeadsContent(leads: leads),
          loading: () => const _LeadsLoading(),
          error: (_, _) => const _LeadsContent(leads: []),
        ),
      ),
    );
  }
}

class _LeadsContent extends StatelessWidget {
  const _LeadsContent({required this.leads});

  final List<LeadItem> leads;

  @override
  Widget build(BuildContext context) {
    if (leads.isEmpty) {
      return const _EmptyLeadsState();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: leads.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _LeadCard(lead: leads[index]);
      },
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.lead});

  final LeadItem lead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = _leadStatusLabel(lead.status);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.trending_up_rounded),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lead.customerName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(label: statusLabel),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (lead.phone != null)
                  _InfoChip(icon: Icons.call_rounded, label: lead.phone!),
                if (lead.email != null)
                  _InfoChip(
                    icon: Icons.mail_outline_rounded,
                    label: lead.email!,
                  ),
                if (lead.source != null)
                  _InfoChip(icon: Icons.campaign_rounded, label: lead.source!),
                if (lead.createdAtLabel != null)
                  _InfoChip(
                    icon: Icons.schedule_rounded,
                    label: lead.createdAtLabel!,
                  ),
              ],
            ),
          ],
        ),
      ),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Chip(
      avatar: Icon(icon, size: 16, color: theme.colorScheme.primary),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmptyLeadsState extends StatelessWidget {
  const _EmptyLeadsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 72),
        Icon(
          Icons.trending_up_rounded,
          size: 72,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          'No leads yet',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'New sales opportunities and follow-ups will appear here once the backend returns lead data.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LeadsLoading extends StatelessWidget {
  const _LeadsLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
