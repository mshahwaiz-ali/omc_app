import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../../core/widgets/premium_list_card.dart';
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
          loading: () => const Center(child: CircularProgressIndicator()),
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
      return const PremiumEmptyState(
        icon: Icons.trending_up_rounded,
        title: 'No leads yet',
        message:
            'New sales opportunities and follow-ups will appear here once the backend returns lead data.',
      );
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
    return PremiumListCard(
      icon: Icons.trending_up_rounded,
      title: lead.title,
      subtitle: lead.customerName,
      trailing: _StatusPill(label: _leadStatusLabel(lead.status)),
      children: [
        if (lead.phone != null)
          PremiumInfoChip(icon: Icons.call_rounded, label: lead.phone!),
        if (lead.email != null)
          PremiumInfoChip(icon: Icons.mail_outline_rounded, label: lead.email!),
        if (lead.source != null)
          PremiumInfoChip(icon: Icons.campaign_rounded, label: lead.source!),
        if (lead.createdAtLabel != null)
          PremiumInfoChip(
            icon: Icons.schedule_rounded,
            label: lead.createdAtLabel!,
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
