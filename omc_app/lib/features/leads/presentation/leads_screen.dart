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

class LeadsScreen extends ConsumerStatefulWidget {
  const LeadsScreen({super.key});

  @override
  ConsumerState<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends ConsumerState<LeadsScreen> {
  String _query = '';
  LeadStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(leadsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(leadsProvider);
          return ref.read(leadsProvider.future);
        },
        child: leadsAsync.when(
          data: (leads) => _LeadsContent(
            leads: leads,
            query: _query,
            statusFilter: _statusFilter,
            onQueryChanged: (value) => setState(() => _query = value),
            onStatusChanged: (value) => setState(() => _statusFilter = value),
            onAddLead: _showCreateLeadSheet,
          ),
          loading: () => _LeadsLoadingView(onAddLead: _showCreateLeadSheet),
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

  Future<void> _showCreateLeadSheet() async {
    final titleController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final sourceController = TextEditingController(text: 'Mobile App');
    final serviceController = TextEditingController();
    final notesController = TextEditingController();
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              if (saving) return;
              final title = titleController.text.trim();
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lead title is required.')),
                );
                return;
              }

              setSheetState(() => saving = true);
              try {
                await ref.read(leadsRepositoryProvider).createLead(
                      title: title,
                      customerName: nameController.text,
                      phone: phoneController.text,
                      email: emailController.text,
                      source: sourceController.text,
                      serviceInterest: serviceController.text,
                      notes: notesController.text,
                    );
                ref.invalidate(leadsProvider);
                if (!mounted) return;
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Lead created.')),
                );
              } catch (error) {
                final message = _backendErrorMessage(error);
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              } finally {
                if (mounted) setSheetState(() => saving = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add Lead',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: titleController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Lead title'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Contact name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: serviceController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Service interest'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: sourceController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Source'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: saving ? null : submit,
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_rounded),
                        label: Text(saving ? 'Saving...' : 'Create lead'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    sourceController.dispose();
    serviceController.dispose();
    notesController.dispose();
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
  const _LeadsContent({
    required this.leads,
    required this.query,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onAddLead,
  });

  final List<LeadItem> leads;
  final String query;
  final LeadStatus? statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<LeadStatus?> onStatusChanged;
  final VoidCallback onAddLead;

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLeads();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
      children: [
        _HeaderWithAction(
          icon: Icons.trending_up_rounded,
          title: 'Leads',
          subtitle: 'Review opportunities, contacts and follow-up sources.',
          metaLabel: leads.isEmpty ? 'Empty' : '${filtered.length}/${leads.length}',
          actionLabel: 'Add lead',
          onAction: onAddLead,
        ),
        const SizedBox(height: 14),
        _LeadFilters(
          query: query,
          statusFilter: statusFilter,
          onQueryChanged: onQueryChanged,
          onStatusChanged: onStatusChanged,
        ),
        const SizedBox(height: 14),
        if (leads.isEmpty)
          PremiumEmptyState(
            icon: Icons.trending_up_rounded,
            title: 'No leads yet',
            message: 'Add the first opportunity or pull down to refresh backend data.',
            actionLabel: 'Add lead',
            onAction: onAddLead,
          )
        else if (filtered.isEmpty)
          PremiumEmptyState(
            icon: Icons.filter_alt_off_rounded,
            title: 'No matching leads',
            message: 'Clear search or select another status filter.',
          )
        else
          for (final lead in filtered) ...[
            _LeadCard(lead: lead),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  List<LeadItem> _filteredLeads() {
    final cleanQuery = query.trim().toLowerCase();
    return leads.where((lead) {
      if (statusFilter != null && lead.status != statusFilter) return false;
      if (cleanQuery.isEmpty) return true;
      final haystack = [
        lead.title,
        lead.customerName,
        lead.phone,
        lead.email,
        lead.source,
        lead.serviceInterest,
        lead.assignedTo,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(cleanQuery);
    }).toList(growable: false);
  }
}

class _HeaderWithAction extends StatelessWidget {
  const _HeaderWithAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.metaLabel,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String metaLabel;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumListHeader(
          icon: icon,
          title: title,
          subtitle: subtitle,
          metaLabel: metaLabel,
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded),
            label: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}

class _LeadFilters extends StatelessWidget {
  const _LeadFilters({
    required this.query,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
  });

  final String query;
  final LeadStatus? statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<LeadStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: onQueryChanged,
          decoration: const InputDecoration(
            hintText: 'Search lead, phone, source or service',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: statusFilter == null,
                onTap: () => onStatusChanged(null),
              ),
              for (final status in LeadStatus.values.where((item) => item != LeadStatus.unknown))
                _FilterChip(
                  label: _leadStatusLabel(status),
                  selected: statusFilter == status,
                  onTap: () => onStatusChanged(status),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}

class _LeadsLoadingView extends StatelessWidget {
  const _LeadsLoadingView({required this.onAddLead});

  final VoidCallback onAddLead;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
      children: [
        _HeaderWithAction(
          icon: Icons.trending_up_rounded,
          title: 'Leads',
          subtitle: 'Review opportunities, contacts and follow-up sources.',
          metaLabel: 'Loading',
          actionLabel: 'Add lead',
          onAction: onAddLead,
        ),
        const SizedBox(height: 14),
        const LinearProgressIndicator(minHeight: 3),
      ],
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
      subtitle: lead.customerName == '-' ? lead.id : lead.customerName,
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
        if (lead.serviceInterest != null)
          PremiumInfoChip(icon: Icons.design_services_rounded, label: lead.serviceInterest!),
        if (lead.createdAtLabel != null)
          PremiumInfoChip(icon: Icons.schedule_rounded, label: lead.createdAtLabel!),
      ],
    );
  }
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
