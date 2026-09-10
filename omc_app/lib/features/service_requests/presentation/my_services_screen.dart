import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/providers/effective_capabilities_provider.dart';
import '../../../app/theme.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_state.dart';
import '../data/service_case.dart';
import '../data/service_case_repository.dart';

class MyServicesScreen extends ConsumerStatefulWidget {
  const MyServicesScreen({super.key});

  @override
  ConsumerState<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends ConsumerState<MyServicesScreen> {
  final TextEditingController _searchController = TextEditingController();

  _ServiceCaseFilter _selectedFilter = _ServiceCaseFilter.all;
  _SortOption _sortOption = _SortOption.recent;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(serviceCasesProvider);
    final capabilities = ref.watch(effectiveCapabilitiesProvider);

    return Scaffold(
      key: OmcWidgetKeys.trackScreen,
      body: SafeArea(
        top: true,
        child: casesAsync.when(
          loading: () => const _LoadingState(),
          error: (error, _) => _ErrorState(
            error: error,
            onRetry: () => ref.invalidate(serviceCasesProvider),
            onStartRequest: () => context.go('/services'),
          ),
          data: (cases) {
            if (cases.isEmpty) {
              return _EmptyState(onStartRequest: () => context.go('/services'));
            }

            final filtered = _applyFilters(cases);
            final sorted = _applySort(filtered);
            final counts = _Counts.fromCases(cases);

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(serviceCasesProvider);
                await ref.read(serviceCasesProvider.future);
              },
              child: OmcPageListView(
                topPadding: 10,
                bottomPadding: AppSpacing.xl,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _TrackHeader(
                    onBack: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  _SearchAndFilterRow(
                    controller: _searchController,
                    query: _query,
                    hasActiveFilter: _selectedFilter != _ServiceCaseFilter.all,
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    onFilterTap: () => _openFilterSheet(context, counts),
                  ),
                  const SizedBox(height: 14),
                  _FilterRow(
                    cases: cases,
                    selectedFilter: _selectedFilter,
                    onSelected: (filter) =>
                        setState(() => _selectedFilter = filter),
                  ),
                  const SizedBox(height: 22),
                  _ResultsHeader(
                    count: sorted.length,
                    sortLabel: _sortOption.label,
                    onSort: () => _openSortSheet(context),
                  ),
                  const SizedBox(height: 12),
                  if (sorted.isEmpty)
                    _FilterEmptyState(
                      filter: _selectedFilter,
                      onClear: _resetFilters,
                    )
                  else
                    for (var i = 0; i < sorted.length; i++) ...[
                      _ServiceCard(
                        serviceCase: sorted[i],
                        capabilities: capabilities,
                      ),
                      if (i != sorted.length - 1) const SizedBox(height: 12),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<ServiceCase> _applyFilters(List<ServiceCase> cases) {
    return cases
        .where((serviceCase) {
          if (!_selectedFilter.matches(serviceCase)) return false;
          if (_query.isEmpty) return true;

          final searchable = <String>[
            serviceCase.title,
            serviceCase.category,
            serviceCase.status,
            serviceCase.statusLabel,
            serviceCase.lifecycleState,
            serviceCase.effectiveOperationalStatus,
            serviceCase.settlement.status,
            serviceCase.activation.bridgeState,
            serviceCase.hold.reason,
            serviceCase.reference ?? '',
            serviceCase.createdAtLabel,
            serviceCase.updatedAtLabel,
            serviceCase.nextStep ?? '',
            serviceCase.remarks ?? '',
            serviceCase.documentSummaryLabel,
            serviceCase.paymentSummaryLabel,
            serviceCase.actionRequiredLabel,
          ].join(' ').toLowerCase();

          return searchable.contains(_query);
        })
        .toList(growable: false);
  }

  List<ServiceCase> _applySort(List<ServiceCase> cases) {
    final sorted = cases.toList(growable: false);

    switch (_sortOption) {
      case _SortOption.recent:
        return sorted;
      case _SortOption.progress:
        sorted.sort((a, b) => b.progress.compareTo(a.progress));
        return sorted;
      case _SortOption.status:
        sorted.sort(
          (a, b) =>
              _stateRank(_stateFor(b)).compareTo(_stateRank(_stateFor(a))),
        );
        return sorted;
      case _SortOption.oldest:
        return sorted.reversed.toList(growable: false);
    }
  }

  void _openSortSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sort requests',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how the current filtered results are ordered.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                for (final option in _SortOption.values)
                  ListTile(
                    minTileHeight: 56,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      option.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: _sortOption == option
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () {
                      setState(() => _sortOption = option);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFilterSheet(BuildContext context, _Counts counts) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter requests',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Show requests by their current service state.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                for (final filter in _ServiceCaseFilter.values)
                  ListTile(
                    minTileHeight: 64,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      filter.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${counts.valueFor(filter)} request${counts.valueFor(filter) == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    trailing: _selectedFilter == filter
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () {
                      setState(() => _selectedFilter = filter);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _resetFilters();
                    },
                    child: const Text('Reset filters'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedFilter = _ServiceCaseFilter.all;
      _sortOption = _SortOption.recent;
      _query = '';
      _searchController.clear();
    });
  }

  int _stateRank(_ServiceCaseState state) {
    if (state.isCancelled) return 4;
    if (state.needsAction) return 3;
    if (state.isInReview) return 2;
    if (state.isInProgress || state.isOpen) return 1;
    return 0;
  }
}

class _TrackHeader extends StatelessWidget {
  const _TrackHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton.outlined(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My requests',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Track service status, required documents and payment progress.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchAndFilterRow extends StatelessWidget {
  const _SearchAndFilterRow({
    required this.controller,
    required this.query,
    required this.hasActiveFilter,
    required this.onChanged,
    required this.onFilterTap,
  });

  final TextEditingController controller;
  final String query;
  final bool hasActiveFilter;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search service or request ID',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (query.isNotEmpty)
              IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.close_rounded),
              ),
            IconButton(
              tooltip: hasActiveFilter
                  ? 'Filter requests, active'
                  : 'Filter requests',
              onPressed: onFilterTap,
              icon: Badge(
                isLabelVisible: hasActiveFilter,
                smallSize: 7,
                child: const Icon(Icons.tune_rounded),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.cases,
    required this.selectedFilter,
    required this.onSelected,
  });

  final List<ServiceCase> cases;
  final _ServiceCaseFilter selectedFilter;
  final ValueChanged<_ServiceCaseFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    const filters = <_ServiceCaseFilter>[
      _ServiceCaseFilter.all,
      _ServiceCaseFilter.actionNeeded,
      _ServiceCaseFilter.open,
      _ServiceCaseFilter.completed,
    ];
    final theme = Theme.of(context);

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = filter == selectedFilter;
          final count = filter.count(cases);
          final label = filter == _ServiceCaseFilter.open
              ? 'Active'
              : filter.label;

          return Material(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => onSelected(filter),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primary.withValues(alpha: 0.28)
                        : AppTheme.border,
                  ),
                ),
                child: Text(
                  '$label  $count',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: selected
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.count,
    required this.sortLabel,
    required this.onSort,
  });

  final int count;
  final String sortLabel;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            '$count ${count == 1 ? 'request' : 'requests'}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onSort,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          label: Text(sortLabel),
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.serviceCase, required this.capabilities});

  final ServiceCase serviceCase;
  final AuthCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final state = _stateFor(serviceCase);
    final palette = _paletteFor(state);
    final progress = serviceCase.progress.clamp(0.0, 1.0);
    final progressPercent =
        serviceCase.progressPercent ?? (progress * 100).round();
    final reference = serviceCase.reference?.trim();
    final nextStep = serviceCase.nextStep?.trim();
    final missingCount =
        serviceCase.missingDocumentsCount ??
        serviceCase.missingDocuments.length;
    final needsUpload =
        state.needsAction &&
        capabilities.canUploadDocuments &&
        (missingCount > 0 ||
            serviceCase.missingDocuments.isNotEmpty ||
            (nextStep?.toLowerCase().contains('upload') ?? false));
    final isInternal = capabilities.canAccessInternalWorkspace;
    final customerName = serviceCase.customerName?.trim();

    final route = Uri(
      path: '/my-services/${Uri.encodeComponent(serviceCase.id)}',
      queryParameters: isInternal
          ? {
              'assisted': '1',
              if (customerName != null && customerName.isNotEmpty)
                'customer_name': customerName,
            }
          : null,
    ).toString();

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 340 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.45;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ServiceCardHeader(
                    serviceCase: serviceCase,
                    palette: palette,
                    reference: reference,
                    stacked: stacked,
                  ),
                  const SizedBox(height: 14),
                  if (!state.isClosed && nextStep?.isNotEmpty == true)
                    _NextStepPanel(
                      label: nextStep!,
                      needsAction: state.needsAction,
                    )
                  else
                    _RequestSummaryPanel(
                      label: state.isClosed
                          ? 'Request closed'
                          : missingCount > 0
                          ? '$missingCount document${missingCount == 1 ? '' : 's'} missing'
                          : serviceCase.documentSummaryLabel,
                      progressPercent: state.isClosed ? null : progressPercent,
                    ),
                  const SizedBox(height: 14),
                  _ServiceCardFooter(
                    dateLabel: state.isClosed
                        ? 'Closed ${serviceCase.updatedAtLabel}'
                        : 'Updated ${serviceCase.updatedAtLabel}',
                    actionLabel: needsUpload
                        ? 'Upload documents'
                        : 'View details',
                    emphasizeAction: needsUpload,
                    stacked: stacked,
                    onAction: () => context.push(route),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ServiceCardHeader extends StatelessWidget {
  const _ServiceCardHeader({
    required this.serviceCase,
    required this.palette,
    required this.reference,
    required this.stacked,
  });

  final ServiceCase serviceCase;
  final _Palette palette;
  final String? reference;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OmcIconBadge(
          icon: _serviceIcon(serviceCase, _stateFor(serviceCase)),
          color: AppTheme.textSecondary,
          size: 44,
          iconSize: 21,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                serviceCase.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              if (reference?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  reference!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final status = OmcStatusBadge(
      label: palette.label,
      color: palette.color,
      icon: palette.icon,
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [identity, const SizedBox(height: 12), status],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: identity),
        const SizedBox(width: 12),
        status,
      ],
    );
  }
}

class _NextStepPanel extends StatelessWidget {
  const _NextStepPanel({required this.label, required this.needsAction});

  final String label;
  final bool needsAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: needsAction
            ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.24)
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: needsAction
              ? theme.colorScheme.tertiary.withValues(alpha: 0.22)
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            needsAction ? 'Action needed' : 'Next step',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestSummaryPanel extends StatelessWidget {
  const _RequestSummaryPanel({required this.label, this.progressPercent});

  final String label;
  final int? progressPercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.description_outlined,
            color: AppTheme.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          if (progressPercent != null) ...[
            const SizedBox(width: 10),
            Text(
              '$progressPercent%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceCardFooter extends StatelessWidget {
  const _ServiceCardFooter({
    required this.dateLabel,
    required this.actionLabel,
    required this.emphasizeAction,
    required this.stacked,
    required this.onAction,
  });

  final String dateLabel;
  final String actionLabel;
  final bool emphasizeAction;
  final bool stacked;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.schedule_rounded,
          size: 17,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            dateLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );

    final action = TextButton.icon(
      onPressed: onAction,
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
      label: Text(actionLabel),
      style: TextButton.styleFrom(
        foregroundColor: emphasizeAction
            ? AppTheme.primary
            : AppTheme.textPrimary,
      ),
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [date, const SizedBox(height: 8), action],
      );
    }

    return Row(
      children: [
        Expanded(child: date),
        const SizedBox(width: 8),
        action,
      ],
    );
  }
}

IconData _serviceIcon(ServiceCase serviceCase, _ServiceCaseState state) {
  final key = '${serviceCase.title} ${serviceCase.category}'
      .trim()
      .toLowerCase();

  if (state.isClosed) return Icons.verified_user_outlined;
  if (key.contains('tax')) return Icons.business_center_outlined;
  if (key.contains('company') || key.contains('business')) {
    return Icons.account_balance_outlined;
  }
  if (key.contains('gst') || key.contains('registration')) {
    return Icons.shield_outlined;
  }

  return Icons.work_outline_rounded;
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return OmcPageListView(
      topPadding: 14,
      bottomPadding: AppSpacing.xl,
      children: [
        _LoadingBlock(width: 170, height: 30, radius: 10, color: color),
        const SizedBox(height: 10),
        _LoadingBlock(width: 260, height: 18, radius: 9, color: color),
        const SizedBox(height: 24),
        _LoadingBlock(
          width: double.infinity,
          height: 56,
          radius: 14,
          color: color,
        ),
        const SizedBox(height: 14),
        _LoadingBlock(
          width: double.infinity,
          height: 190,
          radius: 16,
          color: color,
        ),
        const SizedBox(height: 12),
        _LoadingBlock(
          width: double.infinity,
          height: 190,
          radius: 16,
          color: color,
        ),
      ],
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.onRetry,
    required this.onStartRequest,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onStartRequest;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppErrorState.fromError(
              error: error,
              onRetry: onRetry,
              fallbackTitle: 'Service tracking unavailable',
              fallbackMessage:
                  'We could not load your service requests. Please try again.',
              compact: true,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStartRequest,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Start a request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onStartRequest});

  final VoidCallback onStartRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PremiumCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OmcIconBadge(
                icon: Icons.assignment_turned_in_outlined,
                color: AppTheme.textSecondary,
                size: 52,
                iconSize: 25,
              ),
              const SizedBox(height: 16),
              Text(
                'No service requests yet',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start a guided request from the catalogue. Tracking appears here after submission.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onStartRequest,
                  child: const Text('Start a request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterEmptyState extends StatelessWidget {
  const _FilterEmptyState({required this.filter, required this.onClear});

  final _ServiceCaseFilter filter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No matching requests',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nothing matched the ${filter.label.toLowerCase()} filter or search term.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onClear,
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}

class _Counts {
  const _Counts({
    required this.open,
    required this.inReview,
    required this.actionNeeded,
    required this.completed,
    required this.cancelled,
  });

  final int open;
  final int inReview;
  final int actionNeeded;
  final int completed;
  final int cancelled;

  factory _Counts.fromCases(List<ServiceCase> cases) {
    var open = 0;
    var inReview = 0;
    var actionNeeded = 0;
    var completed = 0;
    var cancelled = 0;

    for (final serviceCase in cases) {
      final state = _stateFor(serviceCase);
      if (state.isCancelled) {
        cancelled += 1;
      } else if (state.isClosed) {
        completed += 1;
      } else if (state.needsAction) {
        actionNeeded += 1;
      } else if (state.isInReview) {
        inReview += 1;
      } else {
        open += 1;
      }
    }

    return _Counts(
      open: open,
      inReview: inReview,
      actionNeeded: actionNeeded,
      completed: completed,
      cancelled: cancelled,
    );
  }

  int valueFor(_ServiceCaseFilter filter) {
    switch (filter) {
      case _ServiceCaseFilter.all:
        return open + inReview + actionNeeded + completed + cancelled;
      case _ServiceCaseFilter.open:
        return open;
      case _ServiceCaseFilter.inReview:
        return inReview;
      case _ServiceCaseFilter.actionNeeded:
        return actionNeeded;
      case _ServiceCaseFilter.completed:
        return completed;
      case _ServiceCaseFilter.cancelled:
        return cancelled;
    }
  }
}

class _ServiceCaseState {
  const _ServiceCaseState({
    required this.isCancelled,
    required this.isClosed,
    required this.needsAction,
    required this.isInReview,
    required this.isOverdue,
    required this.isHistorical,
    required this.isInProgress,
    required this.isOpen,
  });

  final bool isCancelled;
  final bool isClosed;
  final bool needsAction;
  final bool isInReview;
  final bool isOverdue;
  final bool isHistorical;
  final bool isInProgress;
  final bool isOpen;
}

_ServiceCaseState _stateFor(ServiceCase serviceCase) {
  final lifecycle = serviceCase.normalizedLifecycleState;
  final operational = serviceCase.normalizedOperationalStatus;
  final nextStep = serviceCase.nextStep?.trim().toLowerCase() ?? '';
  final historicalLifecycle = lifecycle == 'historical';

  final isCancelled = serviceCase.isTerminalRequest;

  final isClosed =
      !isCancelled &&
      (serviceCase.isCompletedRequest ||
          (!serviceCase.hasCanonicalLifecycle &&
              (operational.contains('complete') ||
                  operational.contains('closed') ||
                  operational.contains('done') ||
                  operational.contains('resolved'))));

  // Historical imports must never inherit modern document/payment action
  // requirements. Their state is projected from existing ERP evidence.
  final needsAction =
      !historicalLifecycle &&
      !isCancelled &&
      !isClosed &&
      (serviceCase.customerActionRequired ||
          serviceCase.missingDocuments.isNotEmpty ||
          (serviceCase.missingDocumentsCount ?? 0) > 0 ||
          serviceCase.rejectedDocumentTotal > 0 ||
          serviceCase.rejectedPaymentTotal > 0 ||
          serviceCase.receipt.isRejected ||
          lifecycle == 'pending payment' ||
          serviceCase.paymentDetails.any(
            (payment) => payment.needsCustomerAction,
          ) ||
          operational.contains('waiting for customer') ||
          operational.contains('action required') ||
          nextStep.contains('upload') ||
          nextStep.contains('pay') ||
          nextStep.contains('submit'));

  final isInReview =
      !isCancelled &&
      !isClosed &&
      !needsAction &&
      (serviceCase.isFinancialHold ||
          serviceCase.settlement.requiresReview ||
          lifecycle == 'activation failed' ||
          lifecycle == 'activating' ||
          operational.contains('review') ||
          operational.contains('processing'));

  final isOverdue =
      !isCancelled &&
      !isClosed &&
      !needsAction &&
      !isInReview &&
      operational.contains('overdue');

  final isHistorical =
      !isCancelled &&
      !isClosed &&
      !needsAction &&
      !isInReview &&
      historicalLifecycle &&
      operational == 'historical';

  final isInProgress =
      !isCancelled &&
      !isClosed &&
      !needsAction &&
      !isInReview &&
      !isOverdue &&
      !isHistorical &&
      (lifecycle == 'ready for activation' ||
          lifecycle == 'activated' ||
          operational.contains('progress') ||
          operational.contains('working'));

  // Open is the broad active-filter bucket. Overdue and neutral historical
  // records remain active while keeping their own visual badges.
  final isOpen =
      !isCancelled && !isClosed && !needsAction && !isInReview && !isInProgress;

  return _ServiceCaseState(
    isCancelled: isCancelled,
    isClosed: isClosed,
    needsAction: needsAction,
    isInReview: isInReview,
    isOverdue: isOverdue,
    isHistorical: isHistorical,
    isInProgress: isInProgress,
    isOpen: isOpen,
  );
}

class _Palette {
  const _Palette({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}

_Palette _paletteFor(_ServiceCaseState state) {
  if (state.isCancelled) {
    return const _Palette(
      label: 'Cancelled',
      color: Color(0xFFB42318),
      icon: Icons.cancel_outlined,
    );
  }
  if (state.isClosed) {
    return const _Palette(
      label: 'Completed',
      color: Color(0xFF16803C),
      icon: Icons.check_circle_outline_rounded,
    );
  }
  if (state.isOverdue) {
    return const _Palette(
      label: 'Overdue',
      color: Color(0xFFA15C00),
      icon: Icons.schedule_rounded,
    );
  }
  if (state.isHistorical) {
    return const _Palette(
      label: 'Historical',
      color: Color(0xFF64748B),
      icon: Icons.history_rounded,
    );
  }
  if (state.needsAction) {
    return const _Palette(
      label: 'Action needed',
      color: Color(0xFFA15C00),
      icon: Icons.priority_high_rounded,
    );
  }
  if (state.isInReview) {
    return const _Palette(
      label: 'In review',
      color: Color(0xFF0F766E),
      icon: Icons.fact_check_outlined,
    );
  }
  if (state.isInProgress) {
    return const _Palette(
      label: 'In progress',
      color: Color(0xFF315A9E),
      icon: Icons.sync_rounded,
    );
  }
  return const _Palette(
    label: 'Open',
    color: OmcPremium.open,
    icon: Icons.timeline_rounded,
  );
}

enum _ServiceCaseFilter {
  all,
  open,
  inReview,
  actionNeeded,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case _ServiceCaseFilter.all:
        return 'All Services';
      case _ServiceCaseFilter.open:
        return 'Open';
      case _ServiceCaseFilter.inReview:
        return 'In Review';
      case _ServiceCaseFilter.actionNeeded:
        return 'Action Needed';
      case _ServiceCaseFilter.completed:
        return 'Completed';
      case _ServiceCaseFilter.cancelled:
        return 'Cancelled';
    }
  }

  bool matches(ServiceCase serviceCase) {
    final state = _stateFor(serviceCase);
    switch (this) {
      case _ServiceCaseFilter.all:
        return true;
      case _ServiceCaseFilter.open:
        return state.isOpen;
      case _ServiceCaseFilter.inReview:
        return state.isInReview;
      case _ServiceCaseFilter.actionNeeded:
        return state.needsAction;
      case _ServiceCaseFilter.completed:
        return state.isClosed;
      case _ServiceCaseFilter.cancelled:
        return state.isCancelled;
    }
  }

  int count(List<ServiceCase> cases) => cases.where(matches).length;
}

enum _SortOption {
  recent,
  progress,
  status,
  oldest;

  String get label {
    switch (this) {
      case _SortOption.recent:
        return 'Recent';
      case _SortOption.progress:
        return 'Progress';
      case _SortOption.status:
        return 'Status';
      case _SortOption.oldest:
        return 'Oldest';
    }
  }
}
