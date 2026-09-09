import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/premium_card.dart';
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
    return ref
        .read(internalServiceCasePageRepositoryProvider)
        .fetchPage(
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
    return cases
        .where((item) {
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
        })
        .toList(growable: false);
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_CaseFilterSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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

  void _clearBackendFilters() {
    _statusFilter = null;
    _documentFilter = null;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final activeFilterCount = [
      _statusFilter,
      _documentFilter,
    ].where((value) => value?.trim().isNotEmpty == true).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        top: true,
        bottom: false,
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

              return _QueueListView(
                children: [
                  _QueueHeader(
                    countLabel:
                        '${loadedCases.length} loaded · $_totalCount scoped backend matches',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _CaseSearchBar(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onClear: _clearSearch,
                    activeFilterCount: activeFilterCount,
                    onFilterTap: _openFilters,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _FilterSummary(
                    search: _search,
                    status: _statusFilter,
                    documentStatus: _documentFilter,
                    primaryFilter: _primaryFilter,
                    hasBackendFilters: activeFilterCount > 0,
                    onClearBackendFilters: _clearBackendFilters,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _PrimaryFilters(
                    selected: _primaryFilter,
                    cases: loadedCases,
                    onSelected: (value) =>
                        setState(() => _primaryFilter = value),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _ResultsHeader(
                    visibleCount: visibleCases.length,
                    loadedCount: loadedCases.length,
                    primaryFilter: _primaryFilter,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (visibleCases.isEmpty)
                    _CasesEmptyState(
                      hasBackendQuery:
                          _search.isNotEmpty ||
                          _statusFilter != null ||
                          _documentFilter != null,
                      primaryFilter: _primaryFilter,
                    )
                  else ...[
                    for (
                      var index = 0;
                      index < visibleCases.length;
                      index++
                    ) ...[
                      _ServiceCaseCard(serviceCase: visibleCases[index]),
                      if (index != visibleCases.length - 1)
                        const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                  if (_hasMore) ...[
                    const SizedBox(height: AppSpacing.md),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppTouchTarget.secondaryButtonHeight,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: _loadingMore ? null : _loadMore,
                        icon: _loadingMore
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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

class _QueueListView extends StatelessWidget {
  const _QueueListView({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageInset = AppLayout.pageInsetFor(constraints.maxWidth);
        final horizontal = constraints.maxWidth >
                AppLayout.generalMaxWidth + pageInset * 2
            ? (constraints.maxWidth - AppLayout.generalMaxWidth) / 2
            : pageInset;

        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 164),
          children: children,
        );
      },
    );
  }
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader({required this.countLabel});

  final String countLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service cases',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Review customer work within your assigned OMC access scope.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.dataset_outlined,
                size: 20,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                countLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 360 || textScale >= 1.5;
        final searchField = TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Search service cases',
            hintText: 'Case, customer or service',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        );
        final filterButton = ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppTouchTarget.secondaryButtonHeight,
          ),
          child: OutlinedButton.icon(
            onPressed: onFilterTap,
            icon: const Icon(Icons.tune_rounded),
            label: Text(
              activeFilterCount == 0
                  ? 'Filters'
                  : 'Filters ($activeFilterCount)',
            ),
          ),
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: AppSpacing.xs),
              filterButton,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: searchField),
            const SizedBox(width: AppSpacing.xs),
            filterButton,
          ],
        );
      },
    );
  }
}

class _FilterSummary extends StatelessWidget {
  const _FilterSummary({
    required this.search,
    required this.status,
    required this.documentStatus,
    required this.primaryFilter,
    required this.hasBackendFilters,
    required this.onClearBackendFilters,
  });

  final String search;
  final String? status;
  final String? documentStatus;
  final _CasePrimaryFilter primaryFilter;
  final bool hasBackendFilters;
  final VoidCallback onClearBackendFilters;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final searchLabel = search.trim().isEmpty
        ? 'No search term'
        : 'Search “${search.trim()}”';
    final statusLabel = status?.trim().isNotEmpty == true
        ? status!.trim()
        : 'Any operational status';
    final documentLabel = _documentFilterDisplay(documentStatus);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackAction = constraints.maxWidth < 360 || textScale >= 1.5;
        final summary = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.filter_alt_outlined,
                size: 20,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Backend query',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '$searchLabel · $statusLabel · Documents: $documentLabel',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Loaded view: ${primaryFilter.label}. Chip counts describe loaded cases only.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final clear = TextButton(
          onPressed: hasBackendFilters ? onClearBackendFilters : null,
          child: const Text('Clear backend filters'),
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppTheme.cardSoft,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: AppTheme.border),
          ),
          child: stackAction
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    summary,
                    if (hasBackendFilters) ...[
                      const SizedBox(height: AppSpacing.xs),
                      clear,
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: summary),
                    if (hasBackendFilters) ...[
                      const SizedBox(width: AppSpacing.xs),
                      clear,
                    ],
                  ],
                ),
        );
      },
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
            Semantics(
              selected: selected == filter,
              label: '${filter.label}, ${_count(filter)} loaded cases',
              child: ChoiceChip(
                selected: selected == filter,
                onSelected: (_) => onSelected(filter),
                label: Text('${filter.label} · ${_count(filter)}'),
              ),
            ),
            if (filter != _CasePrimaryFilter.values.last)
              const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.visibleCount,
    required this.loadedCount,
    required this.primaryFilter,
  });

  final int visibleCount;
  final int loadedCount;
  final _CasePrimaryFilter primaryFilter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stack = constraints.maxWidth < 320 || textScale >= 1.5;
        final title = Text(
          primaryFilter == _CasePrimaryFilter.all
              ? 'Cases'
              : '${primaryFilter.label} cases',
          style: Theme.of(context).textTheme.titleLarge,
        );
        final count = Text(
          '$visibleCount shown from $loadedCount loaded',
          textAlign: stack ? TextAlign.start : TextAlign.end,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: AppSpacing.xxs), count],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: count),
          ],
        );
      },
    );
  }
}

class _ServiceCaseCard extends StatelessWidget {
  const _ServiceCaseCard({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final statusColor = _caseStatusColor(serviceCase);
    final statusBackground = _caseStatusBackground(serviceCase);
    final progress =
        (serviceCase.progressPercent ?? _derivedProgress(serviceCase))
            .clamp(0, 100)
            .toDouble() /
        100;
    final nextStep = serviceCase.nextStep?.trim();
    final priority = serviceCase.priority.trim();
    final metaItems = <_CaseMetaItem>[
      _CaseMetaItem(
        icon: Icons.tag_rounded,
        label: 'Case',
        value: serviceCase.id,
      ),
      if (priority.isNotEmpty && priority != '-')
        _CaseMetaItem(
          icon: Icons.flag_outlined,
          label: 'Priority',
          value: priority,
        ),
      if (serviceCase.pendingDocuments > 0)
        _CaseMetaItem(
          icon: Icons.upload_file_rounded,
          label: 'Pending documents',
          value: '${serviceCase.pendingDocuments}',
        ),
      if (serviceCase.uploadedDocuments > 0)
        _CaseMetaItem(
          icon: Icons.fact_check_outlined,
          label: 'Documents to review',
          value: '${serviceCase.uploadedDocuments}',
        ),
      if (serviceCase.rejectedDocuments > 0)
        _CaseMetaItem(
          icon: Icons.error_outline_rounded,
          label: 'Rejected documents',
          value: '${serviceCase.rejectedDocuments}',
          color: AppTheme.danger,
        ),
    ];
    final semanticNextStep = nextStep?.isNotEmpty == true
        ? nextStep!
        : 'No next step supplied';

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.push(
        '/internal-workspace/service-cases/${Uri.encodeComponent(serviceCase.id)}',
      ),
      semanticLabel:
          '${serviceCase.displayCustomer}. ${serviceCase.displayService}. ${serviceCase.statusLabel}. Next required action: $semanticNextStep. Open service case.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(
                  _caseStatusIcon(serviceCase),
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceCase.displayCustomer,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      serviceCase.displayService,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Current operational state',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _StatusBanner(
            label: serviceCase.statusLabel,
            color: statusColor,
            background: statusBackground,
            icon: _caseStatusIcon(serviceCase),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ProgressRow(progress: progress, color: statusColor),
          const SizedBox(height: AppSpacing.md),
          _NextActionBlock(nextStep: nextStep),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1),
          ),
          Text(
            'Case details',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CaseMetaGrid(items: metaItems),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.label,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress $percent%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: AppTheme.border,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _NextActionBlock extends StatelessWidget {
  const _NextActionBlock({required this.nextStep});

  final String? nextStep;

  @override
  Widget build(BuildContext context) {
    final hasNextStep = nextStep?.trim().isNotEmpty == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.cardSoft,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next required action',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  hasNextStep
                      ? nextStep!.trim()
                      : 'No next step was supplied for this case.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: hasNextStep
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseMetaItem {
  const _CaseMetaItem({
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppTheme.textSecondary,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _CaseMetaGrid extends StatelessWidget {
  const _CaseMetaGrid({required this.items});

  final List<_CaseMetaItem> items;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final singleColumn = constraints.maxWidth < 520 || textScale >= 1.5;
        final itemWidth = singleColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - AppSpacing.md) / 2;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: _CaseMetaRow(item: item),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _CaseMetaRow extends StatelessWidget {
  const _CaseMetaRow({required this.item});

  final _CaseMetaItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(item.icon, size: 20, color: item.color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                item.value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: item.color == AppTheme.textSecondary
                      ? AppTheme.textPrimary
                      : item.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
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
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final availableHeight = (screenHeight - viewInsets.bottom)
        .clamp(240.0, screenHeight)
        .toDouble();

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: availableHeight * 0.9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Case filters',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Operational and document filters run on the backend before pagination.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Operational status',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: _status ?? '',
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText: 'Choose an operational status',
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
                  DropdownMenuItem(
                    value: 'Completed',
                    child: Text('Completed'),
                  ),
                  DropdownMenuItem(
                    value: 'Cancelled',
                    child: Text('Cancelled'),
                  ),
                ],
                onChanged: (value) => setState(
                  () => _status = value == null || value.isEmpty ? null : value,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Document state',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: _documentStatus ?? '',
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText: 'Choose a document state',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Any documents')),
                  DropdownMenuItem(
                    value: 'uploaded',
                    child: Text('Needs review'),
                  ),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(
                    value: 'approved',
                    child: Text('Approved'),
                  ),
                  DropdownMenuItem(
                    value: 'rejected',
                    child: Text('Rejected'),
                  ),
                ],
                onChanged: (value) => setState(
                  () => _documentStatus = value == null || value.isEmpty
                      ? null
                      : value,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stack =
                      constraints.maxWidth < 300 || textScale >= 1.5;
                  final reset = TextButton(
                    onPressed: () {
                      setState(() {
                        _status = null;
                        _documentStatus = null;
                      });
                    },
                    child: const Text('Reset'),
                  );
                  final apply = FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      _CaseFilterSelection(
                        status: _status,
                        documentStatus: _documentStatus,
                      ),
                    ),
                    child: const Text('Apply filters'),
                  );

                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        apply,
                        const SizedBox(height: AppSpacing.xs),
                        reset,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      reset,
                      const Spacer(),
                      apply,
                    ],
                  );
                },
              ),
            ],
          ),
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
    final hasLoadedViewFilter = primaryFilter != _CasePrimaryFilter.all;
    final title = hasBackendQuery
        ? 'No matching service cases'
        : hasLoadedViewFilter
        ? 'No ${primaryFilter.label.toLowerCase()} cases loaded'
        : 'No service cases in your scope';
    final message = hasBackendQuery
        ? 'Try another search term or backend filter.'
        : hasLoadedViewFilter
        ? 'This view filters only cases already loaded from the backend.'
        : 'Cases assigned or relevant to your OMC access will appear here.';

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.processingSoft,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Icon(
              hasBackendQuery
                  ? Icons.search_off_rounded
                  : Icons.work_outline_rounded,
              color: AppTheme.processing,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
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
    return const _QueueListView(
      children: [
        _QueueHeader(countLabel: 'Loading scoped results'),
        SizedBox(height: AppSpacing.xl),
        PremiumCard(
          padding: EdgeInsets.all(AppSpacing.xl),
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
    return _QueueListView(
      children: [
        const _QueueHeader(countLabel: 'Scoped results unavailable'),
        const SizedBox(height: AppSpacing.xl),
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

String _documentFilterDisplay(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'uploaded' => 'Needs review',
    'pending' => 'Pending',
    'approved' => 'Approved',
    'rejected' => 'Rejected',
    _ => 'Any document state',
  };
}

Color _caseStatusColor(InternalServiceCase item) {
  if (item.isCompleted) return AppTheme.success;
  if (item.isCancelled || item.isExpired) return AppTheme.processing;
  if (item.isFinancialHold || item.rejectedDocuments > 0) {
    return AppTheme.danger;
  }
  if (item.isWaitingCustomer || item.isWaitingPayment) {
    return AppTheme.warning;
  }
  if (item.isInReview || item.uploadedDocuments > 0) return AppTheme.info;
  if (item.isInProgress) return AppTheme.info;
  return AppTheme.processing;
}

Color _caseStatusBackground(InternalServiceCase item) {
  if (item.isCompleted) return AppTheme.successSoft;
  if (item.isCancelled || item.isExpired) return AppTheme.processingSoft;
  if (item.isFinancialHold || item.rejectedDocuments > 0) {
    return AppTheme.dangerSoft;
  }
  if (item.isWaitingCustomer || item.isWaitingPayment) {
    return AppTheme.warningSoft;
  }
  if (item.isInReview || item.uploadedDocuments > 0) {
    return AppTheme.infoSoft;
  }
  if (item.isInProgress) return AppTheme.infoSoft;
  return AppTheme.processingSoft;
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
