import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_list_header.dart';
import '../data/internal_service_case_page_repository.dart';
import '../domain/internal_service_case.dart';

const _pageSize = 50;

enum _CasePrimaryFilter {
  all('All'),
  active('Active'),
  waiting('Waiting'),
  review('Review'),
  completed('Completed');

  const _CasePrimaryFilter(this.label);
  final String label;
}

class InternalServiceCasesScreen extends ConsumerStatefulWidget {
  const InternalServiceCasesScreen({super.key});

  @override
  ConsumerState<InternalServiceCasesScreen> createState() =>
      _InternalServiceCasesScreenState();
}

class _InternalServiceCasesScreenState
    extends ConsumerState<InternalServiceCasesScreen> {
  final _searchController = TextEditingController();
  final List<InternalServiceCase> _additionalCases = [];
  Timer? _searchDebounce;
  late Future<InternalServiceCasePage> _pageFuture;
  _CasePrimaryFilter _primaryFilter = _CasePrimaryFilter.all;
  String _search = '';
  String? _statusFilter;
  String? _documentFilter;
  int? _nextStart;
  int _totalCount = 0;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _seededPage = false;

  @override
  void initState() {
    super.initState();
    _pageFuture = _fetchPage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<InternalServiceCasePage> _fetchPage({int start = 0}) {
    return ref.read(internalServiceCasePageRepositoryProvider).fetchPage(
          start: start,
          limit: _pageSize,
          search: _search,
          status: _statusFilter,
          documentStatus: _documentFilter,
        );
  }

  void _resetPaging() {
    _additionalCases.clear();
    _nextStart = null;
    _totalCount = 0;
    _hasMore = false;
    _loadingMore = false;
    _seededPage = false;
  }

  Future<void> _reload() async {
    setState(() {
      _resetPaging();
      _pageFuture = _fetchPage();
    });
    await _pageFuture;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final normalized = value.trim();
      if (normalized == _search) return;
      _search = normalized;
      _reload();
    });
    setState(() {});
  }

  Future<void> _loadMore() async {
    final start = _nextStart;
    if (_loadingMore || !_hasMore || start == null) return;

    setState(() => _loadingMore = true);
    try {
      final page = await _fetchPage(start: start);
      if (!mounted) return;
      setState(() {
        final known = _additionalCases.map((item) => item.id).toSet();
        _additionalCases.addAll(
          page.queue.cases.where((item) => known.add(item.id)),
        );
        _nextStart = page.nextStart;
        _hasMore = page.hasMore;
        _totalCount = page.totalCount;
      });
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'More cases unavailable',
        fallbackMessage: 'The next service-case page could not be loaded.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<InternalServiceCase> _mergeCases(List<InternalServiceCase> firstPage) {
    final seen = <String>{};
    final result = <InternalServiceCase>[];
    for (final item in [...firstPage, ..._additionalCases]) {
      if (seen.add(item.id)) result.add(item);
    }
    return result;
  }

  List<InternalServiceCase> _applyPrimaryFilter(
    List<InternalServiceCase> cases,
  ) {
    return cases.where((item) {
      return switch (_primaryFilter) {
        _CasePrimaryFilter.all => true,
        _CasePrimaryFilter.active => item.isActive,
        _CasePrimaryFilter.waiting =>
          item.isWaitingCustomer || item.isWaitingPayment,
        _CasePrimaryFilter.review =>
          item.isInReview ||
              item.uploadedDocuments > 0 ||
              item.rejectedDocuments > 0,
        _CasePrimaryFilter.completed => item.isCompleted,
      };
    }).toList(growable: false);
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_CaseFilterSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CaseFilterSheet(
        status: _statusFilter,
        documentStatus: _documentFilter,
      ),
    );
    if (!mounted || result == null) return;
    if (result.status == _statusFilter &&
        result.documentStatus == _documentFilter) {
      return;
    }
    _statusFilter = result.status;
    _documentFilter = result.documentStatus;
    await _reload();
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    if (_search.isEmpty) {
      setState(() {});
      return;
    }
    _search = '';
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final activeFilterCount = [
      _statusFilter,
      _documentFilter,
    ].where((value) => value?.trim().isNotEmpty == true).length;

    return Scaffold(
      backgroundColor: OmcPremium.canvas,
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          onRefresh: _reload,
          child: FutureBuilder<InternalServiceCasePage>(
            future: _pageFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !_seededPage) {
                return const _CasesLoadingView();
              }

              if (snapshot.hasError && !_seededPage) {
                return _CasesErrorView(
                  error: snapshot.error!,
                  onRetry: _reload,
                );
              }

              final page = snapshot.data;
              if (page == null) {
                return const _CasesLoadingView();
              }

              if (!_seededPage) {
                _seededPage = true;
                _nextStart = page.nextStart;
                _hasMore = page.hasMore;
                _totalCount = page.totalCount;
              }

              final loadedCases = _mergeCases(page.queue.cases);
              final visibleCases = _applyPrimaryFilter(loadedCases);

              return ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
                children: [
                  PremiumListHeader(
                    icon: Icons.work_outline_rounded,
                    title: 'Service Cases',
                    subtitle:
                        'Review customer work within your assigned OMC access scope.',
                    metaLabel: _totalCount == 0
                        ? '${loadedCases.length} loaded'
                        : '${loadedCases.length} / $_totalCount',
                    accentColor: OmcPremium.track,
                  ),
                  const SizedBox(height: 16),
                  _CaseSearchBar(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onClear: _clearSearch,
                    activeFilterCount: activeFilterCount,
                    onFilterTap: _openFilters,
                  ),
                  const SizedBox(height: 12),
                  _PrimaryFilters(
                    selected: _primaryFilter,
                    cases: loadedCases,
                    onSelected: (value) =>
                        setState(() => _primaryFilter = value),
                  ),
                  if (_statusFilter != null || _documentFilter != null) ...[
                    const SizedBox(height: 10),
                    _ActiveFilters(
                      status: _statusFilter,
                      documentStatus: _documentFilter,
                      onClear: () {
                        _statusFilter = null;
                        _documentFilter = null;
                        _reload();
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (visibleCases.isEmpty)
                    _CasesEmptyState(
                      hasBackendQuery:
                          _search.isNotEmpty ||
                          _statusFilter != null ||
                          _documentFilter != null,
                      primaryFilter: _primaryFilter,
                    )
                  else ...[
                    for (var index = 0;
                        index < visibleCases.length;
                        index++) ...[
                      _ServiceCaseCard(serviceCase: visibleCases[index]),
                      if (index != visibleCases.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                  if (_hasMore) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _loadingMore ? null : _loadMore,
                        icon: _loadingMore
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.expand_more_rounded),
                        label: Text(
                          _loadingMore
                              ? 'Loading more cases'
                              : 'Load more service cases',
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CaseSearchBar extends StatelessWidget {
  const _CaseSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.activeFilterCount,
    required this.onFilterTap,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final int activeFilterCount;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: OmcPremium.border),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search case, customer or service',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: onClear,
                        icon: const Icon(Icons.close_rounded),
                      ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Badge(
          isLabelVisible: activeFilterCount > 0,
          label: Text('$activeFilterCount'),
          child: IconButton.filledTonal(
            tooltip: 'Case filters',
            onPressed: onFilterTap,
            icon: const Icon(Icons.tune_rounded),
          ),
        ),
      ],
    );
  }
}

class _PrimaryFilters extends StatelessWidget {
  const _PrimaryFilters({
    required this.selected,
    required this.cases,
    required this.onSelected,
  });

  final _CasePrimaryFilter selected;
  final List<InternalServiceCase> cases;
  final ValueChanged<_CasePrimaryFilter> onSelected;

  int _count(_CasePrimaryFilter filter) {
    return cases.where((item) {
      return switch (filter) {
        _CasePrimaryFilter.all => true,
        _CasePrimaryFilter.active => item.isActive,
        _CasePrimaryFilter.waiting =>
          item.isWaitingCustomer || item.isWaitingPayment,
        _CasePrimaryFilter.review =>
          item.isInReview ||
              item.uploadedDocuments > 0 ||
              item.rejectedDocuments > 0,
        _CasePrimaryFilter.completed => item.isCompleted,
      };
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final filter in _CasePrimaryFilter.values) ...[
            ChoiceChip(
              selected: selected == filter,
              showCheckmark: false,
              onSelected: (_) => onSelected(filter),
              label: Text('${filter.label}  ${_count(filter)}'),
              selectedColor: OmcPremium.track.withValues(alpha: 0.10),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected == filter
                    ? OmcPremium.track.withValues(alpha: 0.25)
                    : OmcPremium.border,
              ),
              labelStyle: TextStyle(
                color: selected == filter
                    ? OmcPremium.track
                    : AppTheme.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (filter != _CasePrimaryFilter.values.last)
              const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.status,
    required this.documentStatus,
    required this.onClear,
  });

  final String? status;
  final String? documentStatus;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      if (status != null) 'Status: $status',
      if (documentStatus != null) 'Documents: $documentStatus',
    ];
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: labels
                .map(
                  (label) => Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(label),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        TextButton(onPressed: onClear, child: const Text('Clear')),
      ],
    );
  }
}

class _ServiceCaseCard extends StatelessWidget {
  const _ServiceCaseCard({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final statusColor = _caseStatusColor(serviceCase);
    final progress = (serviceCase.progressPercent ?? _derivedProgress(serviceCase))
        .clamp(0, 100)
        .toDouble() /
        100;

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(
          '/internal-workspace/service-cases/${Uri.encodeComponent(serviceCase.id)}',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _caseStatusIcon(serviceCase),
                    color: statusColor,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceCase.displayService,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        serviceCase.displayCustomer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(
                  label: serviceCase.statusLabel,
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFE8EDF0),
                      valueColor: AlwaysStoppedAnimation(statusColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _InfoChip(
                  icon: Icons.tag_rounded,
                  label: serviceCase.id,
                ),
                if (serviceCase.priority.trim().isNotEmpty &&
                    serviceCase.priority != '-')
                  _InfoChip(
                    icon: Icons.flag_outlined,
                    label: serviceCase.priority,
                  ),
                if (serviceCase.pendingDocuments > 0)
                  _InfoChip(
                    icon: Icons.upload_file_rounded,
                    label: '${serviceCase.pendingDocuments} docs pending',
                    color: OmcPremium.action,
                  ),
                if (serviceCase.uploadedDocuments > 0)
                  _InfoChip(
                    icon: Icons.fact_check_outlined,
                    label: '${serviceCase.uploadedDocuments} docs to review',
                    color: OmcPremium.review,
                  ),
                if (serviceCase.rejectedDocuments > 0)
                  _InfoChip(
                    icon: Icons.error_outline_rounded,
                    label: '${serviceCase.rejectedDocuments} rejected',
                    color: OmcPremium.danger,
                  ),
              ],
            ),
            if (serviceCase.nextStep?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.045),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  serviceCase.nextStep!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = AppTheme.textSecondary,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 124),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.13)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CaseFilterSelection {
  const _CaseFilterSelection({this.status, this.documentStatus});
  final String? status;
  final String? documentStatus;
}

class _CaseFilterSheet extends StatefulWidget {
  const _CaseFilterSheet({required this.status, required this.documentStatus});

  final String? status;
  final String? documentStatus;

  @override
  State<_CaseFilterSheet> createState() => _CaseFilterSheetState();
}

class _CaseFilterSheetState extends State<_CaseFilterSheet> {
  String? _status;
  String? _documentStatus;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _documentStatus = widget.documentStatus;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Case filters',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'These filters run on the backend before pagination.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _status ?? '',
              decoration: const InputDecoration(
                labelText: 'Operational status',
                prefixIcon: Icon(Icons.timeline_rounded),
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('Any status')),
                DropdownMenuItem(value: 'Open', child: Text('Open')),
                DropdownMenuItem(
                  value: 'In Progress',
                  child: Text('In Progress'),
                ),
                DropdownMenuItem(
                  value: 'Waiting for Customer',
                  child: Text('Waiting for Customer'),
                ),
                DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
              ],
              onChanged: (value) => setState(
                () => _status = value == null || value.isEmpty ? null : value,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _documentStatus ?? '',
              decoration: const InputDecoration(
                labelText: 'Document state',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('Any documents')),
                DropdownMenuItem(
                  value: 'uploaded',
                  child: Text('Needs review'),
                ),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (value) => setState(
                () => _documentStatus =
                    value == null || value.isEmpty ? null : value,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _status = null;
                      _documentStatus = null;
                    });
                  },
                  child: const Text('Reset'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    _CaseFilterSelection(
                      status: _status,
                      documentStatus: _documentStatus,
                    ),
                  ),
                  child: const Text('Apply filters'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CasesEmptyState extends StatelessWidget {
  const _CasesEmptyState({
    required this.hasBackendQuery,
    required this.primaryFilter,
  });

  final bool hasBackendQuery;
  final _CasePrimaryFilter primaryFilter;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: OmcPremium.track.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              hasBackendQuery
                  ? Icons.search_off_rounded
                  : Icons.work_outline_rounded,
              color: OmcPremium.track,
              size: 29,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hasBackendQuery
                ? 'No matching service cases'
                : primaryFilter == _CasePrimaryFilter.all
                ? 'No service cases in your scope'
                : 'No ${primaryFilter.label.toLowerCase()} cases loaded',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasBackendQuery
                ? 'Try another search or filter.'
                : 'Cases assigned or relevant to your OMC access will appear here.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CasesLoadingView extends StatelessWidget {
  const _CasesLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
      children: const [
        PremiumListHeader(
          icon: Icons.work_outline_rounded,
          title: 'Service Cases',
          subtitle: 'Loading your scoped service-case queue.',
          metaLabel: 'Loading',
          accentColor: OmcPremium.track,
        ),
        SizedBox(height: 18),
        PremiumCard(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

class _CasesErrorView extends StatelessWidget {
  const _CasesErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
      children: [
        const PremiumListHeader(
          icon: Icons.work_outline_rounded,
          title: 'Service Cases',
          subtitle: 'Your scoped service-case workspace.',
          metaLabel: 'Unavailable',
          accentColor: OmcPremium.track,
        ),
        const SizedBox(height: 18),
        AppErrorState.fromError(
          error: error,
          onRetry: onRetry,
          fallbackTitle: 'Service cases unavailable',
          fallbackMessage:
              'Your service-case queue could not be loaded. Please try again.',
        ),
      ],
    );
  }
}

Color _caseStatusColor(InternalServiceCase item) {
  if (item.isCompleted) return OmcPremium.success;
  if (item.isCancelled || item.isExpired) return OmcPremium.system;
  if (item.isFinancialHold || item.rejectedDocuments > 0) {
    return OmcPremium.danger;
  }
  if (item.isWaitingCustomer || item.isWaitingPayment) {
    return OmcPremium.action;
  }
  if (item.isInReview || item.uploadedDocuments > 0) return OmcPremium.review;
  if (item.isInProgress) return OmcPremium.track;
  return OmcPremium.services;
}

IconData _caseStatusIcon(InternalServiceCase item) {
  if (item.isCompleted) return Icons.check_circle_outline_rounded;
  if (item.isCancelled || item.isExpired) return Icons.block_rounded;
  if (item.isFinancialHold || item.rejectedDocuments > 0) {
    return Icons.error_outline_rounded;
  }
  if (item.isWaitingCustomer || item.isWaitingPayment) {
    return Icons.hourglass_top_rounded;
  }
  if (item.isInReview || item.uploadedDocuments > 0) {
    return Icons.fact_check_outlined;
  }
  return Icons.work_outline_rounded;
}

int _derivedProgress(InternalServiceCase item) {
  if (item.isCompleted) return 100;
  if (item.isCancelled || item.isExpired) return 0;
  if (item.isInProgress) return 75;
  if (item.isInReview) return 60;
  if (item.isWaitingCustomer || item.isWaitingPayment) return 45;
  return 25;
}
