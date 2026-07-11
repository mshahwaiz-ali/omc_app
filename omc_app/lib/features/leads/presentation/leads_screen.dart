import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_empty_state.dart';
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
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
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
                await ref
                    .read(leadsRepositoryProvider)
                    .createLead(
                      title: title,
                      customerName: nameController.text,
                      phone: phoneController.text,
                      email: emailController.text,
                      source: sourceController.text,
                      serviceInterest: serviceController.text,
                      notes: notesController.text,
                    );

                ref.invalidate(leadsProvider);

                if (!sheetContext.mounted) return;

                Navigator.of(sheetContext).pop();

                if (!mounted) return;

                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Lead created successfully.')),
                );
              } catch (error) {
                final message = _backendErrorMessage(error);

                if (!sheetContext.mounted) return;

                ScaffoldMessenger.of(
                  sheetContext,
                ).showSnackBar(SnackBar(content: Text(message)));
              } finally {
                if (context.mounted) {
                  setSheetState(() => saving = false);
                }
              }
            }

            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: FractionallySizedBox(
                heightFactor: 0.94,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD7DCE5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEDEF),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.person_add_alt_1_rounded,
                                color: Color(0xFFD71937),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 13),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add new lead',
                                    style: TextStyle(
                                      color: Color(0xFF10182D),
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Capture the opportunity and contact details.',
                                    style: TextStyle(
                                      color: Color(0xFF718096),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.of(sheetContext).pop(),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0xFFE4E8EF),
                                ),
                              ),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF344054),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE8EBF1)),
                      Expanded(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _LeadFormSectionTitle(
                                title: 'Opportunity',
                                subtitle: 'Basic lead and service information.',
                              ),
                              const SizedBox(height: 12),
                              _LeadFormField(
                                controller: titleController,
                                label: 'Lead title',
                                hint: 'Example: Tax filing enquiry',
                                icon: Icons.badge_outlined,
                                requiredField: true,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 12),
                              _LeadFormField(
                                controller: serviceController,
                                label: 'Service interest',
                                hint: 'Service the lead is interested in',
                                icon: Icons.design_services_outlined,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 12),
                              _LeadFormField(
                                controller: sourceController,
                                label: 'Lead source',
                                hint: 'Example: Mobile App',
                                icon: Icons.campaign_outlined,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 22),
                              const _LeadFormSectionTitle(
                                title: 'Contact details',
                                subtitle:
                                    'Information used for follow-up communication.',
                              ),
                              const SizedBox(height: 12),
                              _LeadFormField(
                                controller: nameController,
                                label: 'Contact name',
                                hint: 'Person or business name',
                                icon: Icons.person_outline_rounded,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                              ),
                              const SizedBox(height: 12),
                              _LeadFormField(
                                controller: phoneController,
                                label: 'Phone number',
                                hint: 'Primary contact number',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 12),
                              _LeadFormField(
                                controller: emailController,
                                label: 'Email address',
                                hint: 'Contact email address',
                                icon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 22),
                              const _LeadFormSectionTitle(
                                title: 'Additional notes',
                                subtitle:
                                    'Optional context for the internal team.',
                              ),
                              const SizedBox(height: 12),
                              _LeadFormField(
                                controller: notesController,
                                label: 'Notes',
                                hint:
                                    'Add requirements, background or follow-up notes',
                                icon: Icons.notes_rounded,
                                minLines: 4,
                                maxLines: 6,
                                textInputAction: TextInputAction.newline,
                                textCapitalization:
                                    TextCapitalization.sentences,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          14,
                          20,
                          14 + MediaQuery.paddingOf(context).bottom,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Color(0xFFE8EBF1)),
                          ),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: saving ? null : submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFD71937),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFF1A8B3),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: saving
                                ? const SizedBox(
                                    width: 19,
                                    height: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add_rounded, size: 21),
                            label: Text(
                              saving ? 'Creating lead...' : 'Create lead',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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

class _LeadFormSectionTitle extends StatelessWidget {
  const _LeadFormSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF172033),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF7B8AA4),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LeadFormField extends StatelessWidget {
  const _LeadFormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.requiredField = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool requiredField;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        label: Text(requiredField ? '$label *' : label),
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        prefixIcon: Padding(
          padding: EdgeInsets.only(
            left: 6,
            right: 2,
            bottom: maxLines > 1 ? 62 : 0,
          ),
          child: Icon(icon, color: const Color(0xFF64748B), size: 21),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(
          color: Color(0xFF667085),
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFFA0A9B8),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFFE5E9F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFFD71937), width: 1.4),
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
    final counts = _statusCounts(leads);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
      children: [
        _LeadsHeader(
          totalCount: leads.length,
          filteredCount: filtered.length,
          hasActiveFilter: statusFilter != null || query.trim().isNotEmpty,
          onAddLead: onAddLead,
          onClearFilters: () {
            onQueryChanged('');
            onStatusChanged(null);
          },
        ),
        const SizedBox(height: 20),
        _LeadSearchField(query: query, onQueryChanged: onQueryChanged),
        const SizedBox(height: 14),
        _LeadStatusFilters(
          selectedStatus: statusFilter,
          counts: counts,
          totalCount: leads.length,
          onChanged: onStatusChanged,
        ),
        const SizedBox(height: 18),
        _LeadOverviewGrid(totalCount: leads.length, counts: counts),
        const SizedBox(height: 22),
        _SectionHeading(
          title: statusFilter == null
              ? 'All leads'
              : '${_leadStatusLabel(statusFilter!)} leads',
          subtitle: filtered.isEmpty
              ? 'No matching opportunities'
              : '${filtered.length} ${filtered.length == 1 ? 'opportunity' : 'opportunities'}',
        ),
        const SizedBox(height: 12),
        if (leads.isEmpty)
          PremiumEmptyState(
            icon: Icons.person_add_alt_1_rounded,
            title: 'No leads yet',
            message:
                'Add the first opportunity or pull down to refresh backend data.',
            actionLabel: 'Add lead',
            onAction: onAddLead,
          )
        else if (filtered.isEmpty)
          PremiumEmptyState(
            icon: Icons.filter_alt_off_rounded,
            title: 'No matching leads',
            message: 'Clear the search or select another status filter.',
            actionLabel: 'Clear filters',
            onAction: () {
              onQueryChanged('');
              onStatusChanged(null);
            },
          )
        else ...[
          for (var index = 0; index < filtered.length; index++) ...[
            _LeadCard(lead: filtered[index]),
            if (index != filtered.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 14),
          _LeadListFooter(
            visibleCount: filtered.length,
            totalCount: leads.length,
            onAddLead: onAddLead,
          ),
        ],
      ],
    );
  }

  List<LeadItem> _filteredLeads() {
    final cleanQuery = query.trim().toLowerCase();

    return leads
        .where((lead) {
          if (statusFilter != null && lead.status != statusFilter) {
            return false;
          }

          if (cleanQuery.isEmpty) return true;

          final haystack = [
            lead.id,
            lead.title,
            lead.customerName,
            lead.phone,
            lead.email,
            lead.source,
            lead.serviceInterest,
            lead.assignedTo,
          ].whereType<String>().join(' ').toLowerCase();

          return haystack.contains(cleanQuery);
        })
        .toList(growable: false);
  }
}

class _LeadsHeader extends StatelessWidget {
  const _LeadsHeader({
    required this.totalCount,
    required this.filteredCount,
    required this.hasActiveFilter,
    required this.onAddLead,
    required this.onClearFilters,
  });

  final int totalCount;
  final int filteredCount;
  final bool hasActiveFilter;
  final VoidCallback onAddLead;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderBackButton(onPressed: () => context.pop()),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leads',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF10182D),
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review opportunities, contacts and follow-up sources.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            _HeaderCountBadge(
              label: hasActiveFilter
                  ? '$filteredCount/$totalCount'
                  : totalCount == 0
                  ? 'Empty'
                  : '$totalCount',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onAddLead,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD71937),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 21),
              label: const Text(
                'Add lead',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (hasActiveFilter)
              OutlinedButton.icon(
                onPressed: onClearFilters,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.filter_alt_off_rounded, size: 19),
                label: const Text(
                  'Clear filters',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HeaderBackButton extends StatelessWidget {
  const _HeaderBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Color(0xFFE8ECF3)),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: const SizedBox(
          width: 46,
          height: 46,
          child: Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
        ),
      ),
    );
  }
}

class _HeaderCountBadge extends StatelessWidget {
  const _HeaderCountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 66),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F3),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFD71937),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LeadSearchField extends StatefulWidget {
  const _LeadSearchField({required this.query, required this.onQueryChanged});

  final String query;
  final ValueChanged<String> onQueryChanged;

  @override
  State<_LeadSearchField> createState() => _LeadSearchFieldState();
}

class _LeadSearchFieldState extends State<_LeadSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _LeadSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.query != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onQueryChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search lead, phone, source or service...',
        hintStyle: const TextStyle(
          color: Color(0xFF7B8AA4),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 8, right: 4),
          child: Icon(Icons.search_rounded, color: Color(0xFF172033), size: 25),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 52,
          minHeight: 54,
        ),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _controller.clear();
                  widget.onQueryChanged('');
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFE3E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFD71937), width: 1.4),
        ),
      ),
    );
  }
}

class _LeadStatusFilters extends StatelessWidget {
  const _LeadStatusFilters({
    required this.selectedStatus,
    required this.counts,
    required this.totalCount,
    required this.onChanged,
  });

  final LeadStatus? selectedStatus;
  final Map<LeadStatus, int> counts;
  final int totalCount;
  final ValueChanged<LeadStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final statuses = LeadStatus.values
        .where((status) => status != LeadStatus.unknown)
        .toList(growable: false);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatusFilterButton(
            label: 'All',
            count: totalCount,
            selected: selectedStatus == null,
            color: const Color(0xFFD71937),
            onTap: () => onChanged(null),
          ),
          for (final status in statuses) ...[
            const SizedBox(width: 9),
            _StatusFilterButton(
              label: _leadStatusLabel(status),
              count: counts[status] ?? 0,
              selected: selectedStatus == status,
              color: _leadStatusColor(status),
              onTap: () => onChanged(status),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusFilterButton extends StatelessWidget {
  const _StatusFilterButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.10) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? color.withValues(alpha: 0.25)
              : const Color(0xFFE3E7EE),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 11, 10, 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : const Color(0xFF172033),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 9),
              Container(
                constraints: const BoxConstraints(minWidth: 28),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? color : const Color(0xFFF0F2F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF4B5565),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadOverviewGrid extends StatelessWidget {
  const _LeadOverviewGrid({required this.totalCount, required this.counts});

  final int totalCount;
  final Map<LeadStatus, int> counts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900
            ? 5
            : width >= 620
            ? 3
            : 2;
        final spacing = 12.0;
        final itemWidth = (width - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _LeadMetricCard(
              width: itemWidth,
              value: totalCount,
              label: 'Total Leads',
              caption: 'All time',
              icon: Icons.groups_2_outlined,
              color: const Color(0xFFD71937),
            ),
            _LeadMetricCard(
              width: itemWidth,
              value: counts[LeadStatus.newLead] ?? 0,
              label: 'New Leads',
              caption: 'Awaiting action',
              icon: Icons.auto_awesome_rounded,
              color: const Color(0xFF2563EB),
            ),
            _LeadMetricCard(
              width: itemWidth,
              value: counts[LeadStatus.contacted] ?? 0,
              label: 'Contacted',
              caption: 'In follow-up',
              icon: Icons.phone_in_talk_outlined,
              color: const Color(0xFFF97316),
            ),
            _LeadMetricCard(
              width: itemWidth,
              value: counts[LeadStatus.qualified] ?? 0,
              label: 'Qualified',
              caption: 'Sales ready',
              icon: Icons.workspace_premium_outlined,
              color: const Color(0xFF9333EA),
            ),
            _LeadMetricCard(
              width: itemWidth,
              value: counts[LeadStatus.converted] ?? 0,
              label: 'Converted',
              caption: 'Successful',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF16A34A),
            ),
          ],
        );
      },
    );
  }
}

class _LeadMetricCard extends StatelessWidget {
  const _LeadMetricCard({
    required this.width,
    required this.value,
    required this.label,
    required this.caption,
    required this.icon,
    required this.color,
  });

  final double width;
  final int value;
  final String label;
  final String caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 136),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0F2F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A172033),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const Spacer(),
              Text(
                '$value',
                style: const TextStyle(
                  color: Color(0xFF10182D),
                  fontSize: 27,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF172033),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF7B8AA4),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF10182D),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF7B8AA4),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.lead});

  final LeadItem lead;

  @override
  Widget build(BuildContext context) {
    final statusColor = _leadStatusColor(lead.status);
    final displayName = _displayName(lead);
    final supportingTitle = _supportingTitle(lead);
    final initials = _initials(displayName);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: () {
          context.push('/leads/${Uri.encodeComponent(lead.id)}');
        },
        borderRadius: BorderRadius.circular(23),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: const Color(0xFFF0F2F6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x09172033),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LeadAvatar(initials: initials, color: statusColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF10182D),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _LeadStatusBadge(
                          status: lead.status,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF172033),
                            size: 23,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          supportingTitle,
                          style: const TextStyle(
                            color: Color(0xFF5F718F),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (lead.source != null) ...[
                          const Text(
                            '•',
                            style: TextStyle(
                              color: Color(0xFF9AA6B8),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'via ${lead.source}',
                            style: const TextStyle(
                              color: Color(0xFF5F718F),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (lead.phone != null || lead.email != null) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          if (lead.phone != null)
                            _LeadMetadata(
                              icon: Icons.phone_outlined,
                              label: lead.phone!,
                            ),
                          if (lead.email != null)
                            _LeadMetadata(
                              icon: Icons.mail_outline_rounded,
                              label: lead.email!,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 11),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (lead.createdAtLabel != null)
                          _LeadMetadata(
                            icon: Icons.calendar_today_outlined,
                            label: lead.createdAtLabel!,
                          ),
                        _LeadStageTag(
                          label: _leadStatusLabel(lead.status),
                          color: statusColor,
                        ),
                        if (lead.assignedTo != null)
                          _LeadMetadata(
                            icon: Icons.person_outline_rounded,
                            label: lead.assignedTo!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayName(LeadItem item) {
    final customer = item.customerName.trim();
    if (customer.isNotEmpty && customer != '-') return customer;

    final title = item.title.trim();
    if (title.isNotEmpty && title != '-') return title;

    return item.id;
  }

  String _supportingTitle(LeadItem item) {
    final service = item.serviceInterest?.trim();
    if (service != null && service.isNotEmpty) return service;

    final title = item.title.trim();
    if (title.isNotEmpty && title != '-' && title != _displayName(item)) {
      return title;
    }

    return 'Lead opportunity';
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) return 'L';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _LeadAvatar extends StatelessWidget {
  const _LeadAvatar({required this.initials, required this.color});

  final String initials;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 57,
      height: 57,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: color,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LeadStatusBadge extends StatelessWidget {
  const _LeadStatusBadge({required this.status, required this.color});

  final LeadStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _leadStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LeadMetadata extends StatelessWidget {
  const _LeadMetadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF60718D)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF60718D),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadStageTag extends StatelessWidget {
  const _LeadStageTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sell_outlined, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadListFooter extends StatelessWidget {
  const _LeadListFooter({
    required this.visibleCount,
    required this.totalCount,
    required this.onAddLead,
  });

  final int visibleCount;
  final int totalCount;
  final VoidCallback onAddLead;

  @override
  Widget build(BuildContext context) {
    final allVisible = visibleCount == totalCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD71937).withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: Color(0xFFD71937),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allVisible ? 'All leads loaded' : 'Filtered results',
                  style: const TextStyle(
                    color: Color(0xFF10182D),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  allVisible
                      ? 'Add another opportunity or pull down to refresh.'
                      : 'Showing $visibleCount of $totalCount leads.',
                  style: const TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onAddLead,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD71937),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Add lead',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
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
        _LeadsHeader(
          totalCount: 0,
          filteredCount: 0,
          hasActiveFilter: false,
          onAddLead: onAddLead,
          onClearFilters: () {},
        ),
        const SizedBox(height: 22),
        const LinearProgressIndicator(
          minHeight: 3,
          color: Color(0xFFD71937),
          backgroundColor: Color(0xFFFFE5E9),
        ),
      ],
    );
  }
}

Map<LeadStatus, int> _statusCounts(List<LeadItem> leads) {
  final counts = <LeadStatus, int>{
    for (final status in LeadStatus.values) status: 0,
  };

  for (final lead in leads) {
    counts[lead.status] = (counts[lead.status] ?? 0) + 1;
  }

  return counts;
}

Color _leadStatusColor(LeadStatus status) {
  switch (status) {
    case LeadStatus.newLead:
      return const Color(0xFFD71937);
    case LeadStatus.contacted:
      return const Color(0xFF2563EB);
    case LeadStatus.qualified:
      return const Color(0xFF9333EA);
    case LeadStatus.converted:
      return const Color(0xFF16A34A);
    case LeadStatus.lost:
      return const Color(0xFF64748B);
    case LeadStatus.unknown:
      return const Color(0xFF64748B);
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
