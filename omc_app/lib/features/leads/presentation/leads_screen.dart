import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/forms/dirty_form_controller.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../auth/application/auth_controller.dart';
import '../data/leads_repository.dart';
import '../domain/lead_item.dart';

class LeadsScreen extends ConsumerStatefulWidget {
  const LeadsScreen({this.openCreateOnLoad = false, super.key});

  final bool openCreateOnLoad;

  @override
  ConsumerState<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends ConsumerState<LeadsScreen> {
  int _start = 0;
  Timer? _debounce;
  String _query = '';
  LeadStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    if (widget.openCreateOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            ref.read(authControllerProvider).capabilities.canManageLeads) {
          _showCreateLeadSheet();
        }
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _query = value;
        _start = 0;
      });
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    setState(() {
      _query = '';
      _start = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pageProvider = leadsResultPageProvider((
      start: _start,
      search: _query,
    ));
    final resultAsync = ref.watch(pageProvider);
    final canCreateLeads = ref
        .watch(authControllerProvider)
        .capabilities
        .canManageLeads;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator.adaptive(
          onRefresh: () async {
            ref.invalidate(leadsProvider);
            ref.invalidate(leadsPageProvider);
            ref.invalidate(leadsResultPageProvider);
            await ref.read(pageProvider.future);
          },
          child: resultAsync.when(
            data: (page) => _LeadsContent(
              leads: page.items,
              query: _query,
              statusFilter: _statusFilter,
              pageNumber: _start ~/ 50 + 1,
              canGoPrevious: _start > 0,
              nextStart: page.nextStart,
              onQueryChanged: _search,
              onClearSearch: _clearSearch,
              onStatusChanged: (value) => setState(() => _statusFilter = value),
              onPrevious: _start == 0
                  ? null
                  : () => setState(() => _start -= 50),
              onNext: page.nextStart == null
                  ? null
                  : () => setState(() => _start = page.nextStart!),
              onAddLead: canCreateLeads ? _showCreateLeadSheet : null,
            ),
            loading: () => _LeadsLoadingView(
              onAddLead: canCreateLeads ? _showCreateLeadSheet : null,
            ),
            error: (error, _) => _BackendUnavailableState(
              message: _backendErrorMessage(error),
              onRetry: () => ref.invalidate(pageProvider),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateLeadSheet() async {
    if (!ref.read(authControllerProvider).capabilities.canManageLeads) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your role cannot create leads.')),
      );
      return;
    }

    final titleController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final sourceController = TextEditingController(text: 'Mobile App');
    final serviceController = TextEditingController();
    final notesController = TextEditingController();
    final dirtyFormController = DirtyFormController();
    final controllers = <TextEditingController>[
      titleController,
      nameController,
      phoneController,
      emailController,
      sourceController,
      serviceController,
      notesController,
    ];
    void markDirty() => dirtyFormController.markDirty();
    for (final controller in controllers) {
      controller.addListener(markDirty);
    }
    var saving = false;

    Future<void> closeSheet(BuildContext sheetContext) async {
      if (saving) return;
      if (dirtyFormController.shouldBlockExit) {
        final discard = await showDiscardChangesDialog(sheetContext);
        if (!discard || !sheetContext.mounted) return;
        dirtyFormController.allowNextExit();
      }
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              if (saving) return;
              if (!ref
                  .read(authControllerProvider)
                  .capabilities
                  .canManageLeads) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Your role cannot create leads.'),
                  ),
                );
                return;
              }

              final title = titleController.text.trim();
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lead title is required.')),
                );
                return;
              }

              dirtyFormController.beginSubmitting();
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
                ref.invalidate(leadsPageProvider);
                ref.invalidate(leadsResultPageProvider);
                if (!sheetContext.mounted) return;
                dirtyFormController.submissionSucceeded();
                Navigator.of(sheetContext).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Lead created successfully.')),
                );
              } catch (error) {
                dirtyFormController.submissionFailed();
                if (!sheetContext.mounted) return;
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(content: Text(_backendErrorMessage(error))),
                );
              } finally {
                if (context.mounted) setSheetState(() => saving = false);
              }
            }

            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            return PopScope<Object?>(
              canPop: !saving,
              child: UnsavedChangesGuard(
                controller: dirtyFormController,
                child: AnimatedPadding(
                  duration: AppMotion.quick,
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: FractionallySizedBox(
                    heightFactor: 0.94,
                    child: Material(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.sheet),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.sm,
                              AppSpacing.sm,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Add new lead',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: AppSpacing.xxs),
                                      Text(
                                        'Capture the opportunity and contact details.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppTheme.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                IconButton.outlined(
                                  tooltip: 'Close lead form',
                                  onPressed: saving
                                      ? null
                                      : () => closeSheet(sheetContext),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _LeadFormSectionTitle(
                                    title: 'Opportunity',
                                    subtitle:
                                        'Basic lead and service information.',
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  _LeadFormField(
                                    controller: titleController,
                                    label: 'Lead title',
                                    hint: 'Example: Tax filing enquiry',
                                    icon: Icons.badge_outlined,
                                    requiredField: true,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _LeadFormField(
                                    controller: serviceController,
                                    label: 'Service interest',
                                    hint: 'Service the lead is interested in',
                                    icon: Icons.design_services_outlined,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _LeadFormField(
                                    controller: sourceController,
                                    label: 'Lead source',
                                    hint: 'Example: Mobile App',
                                    icon: Icons.campaign_outlined,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  const _LeadFormSectionTitle(
                                    title: 'Contact details',
                                    subtitle:
                                        'Information used for follow-up communication.',
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  _LeadFormField(
                                    controller: nameController,
                                    label: 'Contact name',
                                    hint: 'Person or business name',
                                    icon: Icons.person_outline_rounded,
                                    textInputAction: TextInputAction.next,
                                    textCapitalization:
                                        TextCapitalization.words,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _LeadFormField(
                                    controller: phoneController,
                                    label: 'Phone number',
                                    hint: 'Primary contact number',
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _LeadFormField(
                                    controller: emailController,
                                    label: 'Email address',
                                    hint: 'Contact email address',
                                    icon: Icons.mail_outline_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  const _LeadFormSectionTitle(
                                    title: 'Additional notes',
                                    subtitle:
                                        'Optional context for the internal team.',
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
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
                              AppSpacing.lg,
                              AppSpacing.sm,
                              AppSpacing.lg,
                              AppSpacing.sm +
                                  MediaQuery.paddingOf(context).bottom,
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: AppTheme.border),
                              ),
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: saving ? null : submit,
                                icon: saving
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.add_rounded),
                                label: Text(
                                  saving ? 'Creating lead...' : 'Create lead',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    for (final controller in controllers) {
      controller.removeListener(markDirty);
      controller.dispose();
    }
    dirtyFormController.dispose();
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
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          requiredField ? '$label *' : label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          minLines: minLines,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
        ),
      ],
    );
  }
}

String _backendErrorMessage(Object error) {
  return AppFailureClassifier.classify(
    error,
    fallbackTitle: 'Data unavailable',
    fallbackMessage: 'Could not load leads right now. Please try again.',
  ).message;
}

class _BackendUnavailableState extends StatelessWidget {
  const _BackendUnavailableState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _PageList(
      children: [
        const _PipelineHeader(onAddLead: null),
        const SizedBox(height: AppSpacing.xl),
        PremiumEmptyState(
          icon: Icons.trending_up_rounded,
          title: 'Leads unavailable',
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
    required this.pageNumber,
    required this.canGoPrevious,
    required this.nextStart,
    required this.onQueryChanged,
    required this.onClearSearch,
    required this.onStatusChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onAddLead,
  });

  final List<LeadItem> leads;
  final String query;
  final LeadStatus? statusFilter;
  final int pageNumber;
  final bool canGoPrevious;
  final int? nextStart;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<LeadStatus?> onStatusChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onAddLead;

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLeads();
    final counts = _statusCounts(leads);

    return _PageList(
      children: [
        _PipelineHeader(onAddLead: onAddLead),
        const SizedBox(height: AppSpacing.xl),
        _LeadSearchField(
          query: query,
          onQueryChanged: onQueryChanged,
          onClear: onClearSearch,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Stage filter', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        _LeadStatusFilters(
          selectedStatus: statusFilter,
          counts: counts,
          totalCount: leads.length,
          onChanged: onStatusChanged,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Stage counts describe this loaded server page only.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        _ResultsHeader(
          title: statusFilter == null
              ? 'Leads on this page'
              : '${_leadStatusLabel(statusFilter!)} leads',
          count: filtered.length,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (leads.isEmpty)
          PremiumEmptyState(
            icon: Icons.person_add_alt_1_rounded,
            title: 'No leads yet',
            message:
                'Add the first opportunity or pull down to refresh backend data.',
            actionLabel: onAddLead == null ? null : 'Add lead',
            onAction: onAddLead,
          )
        else if (filtered.isEmpty)
          const PremiumEmptyState(
            icon: Icons.filter_alt_off_rounded,
            title: 'No matching leads',
            message: 'Try another search or stage filter.',
          )
        else
          for (var index = 0; index < filtered.length; index++) ...[
            _LeadCard(lead: filtered[index]),
            if (index != filtered.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.xl),
        _Pager(
          pageNumber: pageNumber,
          pageLoadedCount: leads.length,
          visibleCount: filtered.length,
          canGoPrevious: canGoPrevious,
          canGoNext: nextStart != null,
          onPrevious: onPrevious,
          onNext: onNext,
        ),
      ],
    );
  }

  List<LeadItem> _filteredLeads() {
    if (statusFilter == null) return leads;
    return leads
        .where((lead) => lead.status == statusFilter)
        .toList(growable: false);
  }
}

class _PageList extends StatelessWidget {
  const _PageList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = AppLayout.pageInsetFor(constraints.maxWidth);
        final horizontal =
            constraints.maxWidth > AppLayout.generalMaxWidth + inset * 2
            ? (constraints.maxWidth - AppLayout.generalMaxWidth) / 2
            : inset;
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            horizontal,
            18,
            horizontal,
            AppSpacing.xl,
          ),
          children: children,
        );
      },
    );
  }
}

class _PipelineHeader extends StatelessWidget {
  const _PipelineHeader({required this.onAddLead});

  final VoidCallback? onAddLead;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 360 || textScale >= 1.5;
        final identity = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Leads', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Opportunities, contacts and follow-up context.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        );
        final add = FilledButton.icon(
          onPressed: onAddLead,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add lead'),
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              if (onAddLead != null) ...[
                const SizedBox(height: AppSpacing.md),
                add,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: identity),
            if (onAddLead != null) ...[
              const SizedBox(width: AppSpacing.md),
              add,
            ],
          ],
        );
      },
    );
  }
}

class _LeadSearchField extends StatefulWidget {
  const _LeadSearchField({
    required this.query,
    required this.onQueryChanged,
    required this.onClear,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;

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
        labelText: 'Search leads',
        hintText: 'Name, phone, source or service',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _controller.clear();
                  widget.onClear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
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
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          ChoiceChip(
            selected: selectedStatus == null,
            onSelected: (_) => onChanged(null),
            label: Text('All · $totalCount'),
          ),
          for (final status in statuses) ...[
            const SizedBox(width: AppSpacing.xs),
            ChoiceChip(
              selected: selectedStatus == status,
              onSelected: (_) => onChanged(status),
              label: Text(
                '${_leadStatusLabel(status)} · ${counts[status] ?? 0}',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$count shown',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
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
    final displayName = _displayName(lead);
    final serviceInterest = lead.serviceInterest?.trim();
    final contactRows = <_LeadDetail>[
      if (lead.phone?.trim().isNotEmpty == true)
        _LeadDetail(Icons.phone_outlined, 'Phone', lead.phone!.trim()),
      if (lead.email?.trim().isNotEmpty == true)
        _LeadDetail(Icons.mail_outline_rounded, 'Email', lead.email!.trim()),
    ];
    final followUpRows = <_LeadDetail>[
      if (lead.source?.trim().isNotEmpty == true)
        _LeadDetail(Icons.campaign_outlined, 'Source', lead.source!.trim()),
      if (lead.assignedTo?.trim().isNotEmpty == true)
        _LeadDetail(
          Icons.person_outline_rounded,
          'Assigned to',
          lead.assignedTo!.trim(),
        ),
      if (lead.createdAtLabel?.trim().isNotEmpty == true)
        _LeadDetail(
          Icons.calendar_today_outlined,
          'Created',
          lead.createdAtLabel!.trim(),
        ),
    ];

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.push('/leads/${Uri.encodeComponent(lead.id)}'),
      semanticLabel:
          '$displayName. ${_leadStatusLabel(lead.status)} lead. ${serviceInterest?.isNotEmpty == true ? 'Service interest $serviceInterest.' : ''} Open lead details.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (lead.title.trim().isNotEmpty &&
                        lead.title.trim() != '-' &&
                        lead.title.trim() != displayName) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        lead.title.trim(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _LeadStatusBadge(status: lead.status),
            ],
          ),
          if (contactRows.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _AdaptiveDetails(rows: contactRows),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'Service interest',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            serviceInterest?.isNotEmpty == true
                ? serviceInterest!
                : 'Not added',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (followUpRows.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Divider(height: 1),
            ),
            Text(
              'Follow-up context',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            _AdaptiveDetails(rows: followUpRows),
          ],
        ],
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
}

class _LeadStatusBadge extends StatelessWidget {
  const _LeadStatusBadge({required this.status});

  final LeadStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _leadStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _leadStatusBackground(status),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        _leadStatusLabel(status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class _LeadDetail {
  const _LeadDetail(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

class _AdaptiveDetails extends StatelessWidget {
  const _AdaptiveDetails({required this.rows});

  final List<_LeadDetail> rows;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final singleColumn = constraints.maxWidth < 520 || textScale >= 1.5;
        final width = singleColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: rows
              .map(
                (row) => SizedBox(
                  width: width,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(row.icon, size: 20, color: AppTheme.textSecondary),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.label,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              row.value,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.pageNumber,
    required this.pageLoadedCount,
    required this.visibleCount,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int pageNumber;
  final int pageLoadedCount;
  final int visibleCount;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 360 || textScale >= 1.5;
        final summary = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Page $pageNumber',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '$visibleCount shown from $pageLoadedCount loaded on this server page.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        );
        final actions = Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            OutlinedButton(
              onPressed: canGoPrevious ? onPrevious : null,
              child: const Text('Previous'),
            ),
            OutlinedButton(
              onPressed: canGoNext ? onNext : null,
              child: const Text('Next'),
            ),
          ],
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summary,
              const SizedBox(height: AppSpacing.sm),
              actions,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: summary),
            const SizedBox(width: AppSpacing.md),
            actions,
          ],
        );
      },
    );
  }
}

class _LeadsLoadingView extends StatelessWidget {
  const _LeadsLoadingView({required this.onAddLead});

  final VoidCallback? onAddLead;

  @override
  Widget build(BuildContext context) {
    return _PageList(
      children: [
        _PipelineHeader(onAddLead: onAddLead),
        const SizedBox(height: AppSpacing.xl),
        const PremiumCard(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
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
      return AppTheme.info;
    case LeadStatus.contacted:
      return AppTheme.processing;
    case LeadStatus.qualified:
      return AppTheme.warning;
    case LeadStatus.converted:
      return AppTheme.success;
    case LeadStatus.lost:
    case LeadStatus.unknown:
      return AppTheme.processing;
  }
}

Color _leadStatusBackground(LeadStatus status) {
  switch (status) {
    case LeadStatus.newLead:
      return AppTheme.infoSoft;
    case LeadStatus.contacted:
      return AppTheme.processingSoft;
    case LeadStatus.qualified:
      return AppTheme.warningSoft;
    case LeadStatus.converted:
      return AppTheme.successSoft;
    case LeadStatus.lost:
    case LeadStatus.unknown:
      return AppTheme.processingSoft;
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
