import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../../core/widgets/premium_list_header.dart';
import '../../../core/widgets/premium_list_card.dart';
import '../data/leads_repository.dart';
import '../domain/lead_item.dart';

class LeadsScreen extends ConsumerWidget {
  const LeadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadsAsync = ref.watch(leadsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(leadsProvider);
          return ref.read(leadsProvider.future);
        },
        child: leadsAsync.when(
          data: (leads) => _LeadsContent(leads: leads),
          loading: () => const _LeadsLoadingView(),
          error: (error, _) => _BackendUnavailableState(
            icon: Icons.trending_up_rounded,
            title: 'Leads unavailable',
            message: _backendErrorMessage(error),
            onRetry: () => ref.invalidate(leadsProvider),
          ),
        ),
      ),
    );
  }
}

String _backendErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  return 'Could not load leads right now. Please try again.';
}

class _BackendUnavailableState extends StatelessWidget {
  const _BackendUnavailableState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        PremiumEmptyState(
          icon: icon,
          title: title,
          message: message,
          actionLabel: 'Retry',
          onAction: onRetry,
        ),
      ],
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
            'New sales opportunities and follow-ups will appear here when lead data is available.',
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      itemCount: leads.length + 1,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 18 : 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return PremiumListHeader(
            icon: Icons.trending_up_rounded,
            title: 'Leads',
            subtitle: 'Review opportunities, contacts and follow-up sources.',
            metaLabel: '${leads.length} total',
          );
        }

        return _LeadCard(lead: leads[index - 1]);
      },
    );
  }
}

class _LeadsLoadingView extends StatelessWidget {
  const _LeadsLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const PremiumListHeader(
            icon: Icons.trending_up_rounded,
            title: 'Leads',
            subtitle: 'Review opportunities, contacts and follow-up sources.',
            metaLabel: 'Loading',
          );
        }

        return const PremiumListCard(
          icon: Icons.trending_up_rounded,
          title: 'Loading lead',
          subtitle: 'Fetching opportunity details',
          children: [
            PremiumInfoChip(icon: Icons.campaign_rounded, label: 'Source'),
            PremiumInfoChip(icon: Icons.call_rounded, label: 'Phone'),
            PremiumInfoChip(icon: Icons.schedule_rounded, label: 'Created'),
          ],
        );
      },
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 18 : 12),
      itemCount: 4,
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
      trailing: PremiumInfoChip(label: _leadStatusLabel(lead.status)),
      onTap: () {
        context.push('/leads/${Uri.encodeComponent(lead.id)}');
      },
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
