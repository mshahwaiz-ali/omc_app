import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../profile/data/profile_repository.dart';
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
    final authState = ref.watch(authControllerProvider);
    final profile = ref
        .watch(profileSummaryProvider)
        .maybeWhen(data: (profile) => profile, orElse: () => null);
    final capabilities = profile?.capabilities ?? authState.capabilities;

    return Scaffold(
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
                ref.invalidate(profileSummaryProvider);
                await ref.read(profileSummaryProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 148),
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
                  const SizedBox(height: 18),
                  _SearchAndFilterRow(
                    controller: _searchController,
                    query: _query,
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
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${sorted.length} ${sorted.length == 1 ? 'request' : 'requests'}',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _openSortSheet(context),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        label: Text(_sortOption.label),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                      if (i != sorted.length - 1) const SizedBox(height: 16),
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
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sort services',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                for (final option in _SortOption.values) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      option.label,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    trailing: _sortOption == option
                        ? const Icon(
                            Icons.check_rounded,
                            color: OmcPremium.track,
                          )
                        : null,
                    onTap: () {
                      setState(() => _sortOption = option);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ],
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
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter services',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                for (final filter in _ServiceCaseFilter.values) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      filter.label,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '${counts.valueFor(filter)} service(s)',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: _selectedFilter == filter
                        ? const Icon(
                            Icons.check_rounded,
                            color: OmcPremium.track,
                          )
                        : null,
                    onTap: () {
                      setState(() => _selectedFilter = filter);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ],
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

  _ServiceCaseState _stateFor(ServiceCase serviceCase) {
    final status = serviceCase.status.trim().toLowerCase();
    final nextStep = serviceCase.nextStep?.trim().toLowerCase() ?? '';

    final isCancelled =
        status.contains('cancel') ||
        status.contains('reject') ||
        status.contains('declin') ||
        status.contains('blocked');
    final isClosed =
        !isCancelled &&
        (status.contains('complete') ||
            status.contains('closed') ||
            status.contains('done') ||
            status.contains('resolved'));
    final needsAction =
        !isCancelled &&
        !isClosed &&
        (serviceCase.customerActionRequired ||
            serviceCase.missingDocuments.isNotEmpty ||
            (serviceCase.missingDocumentsCount ?? 0) > 0 ||
            serviceCase.rejectedDocumentTotal > 0 ||
            serviceCase.rejectedPaymentTotal > 0 ||
            serviceCase.paymentDetails.any(
              (payment) => payment.needsCustomerAction,
            ) ||
            status.contains('waiting for document') ||
            status.contains('waiting for payment') ||
            status.contains('waiting for customer') ||
            status.contains('action required') ||
            nextStep.contains('upload') ||
            nextStep.contains('pay') ||
            nextStep.contains('submit'));
    final isInReview =
        !isCancelled &&
        !isClosed &&
        !needsAction &&
        (status.contains('review') ||
            status.contains('processing') ||
            status.contains('pending') ||
            status.contains('documents under review') ||
            status.contains('payment under review'));
    final isInProgress =
        !isCancelled &&
        !isClosed &&
        !needsAction &&
        !isInReview &&
        (status.contains('progress') || status.contains('working'));
    final isOpen =
        !isCancelled &&
        !isClosed &&
        !needsAction &&
        !isInReview &&
        !isInProgress;

    return _ServiceCaseState(
      isCancelled: isCancelled,
      isClosed: isClosed,
      needsAction: needsAction,
      isInReview: isInReview,
      isInProgress: isInProgress,
      isOpen: isOpen,
    );
  }

  int _stateRank(_ServiceCaseState state) {
    if (state.isCancelled) return 4;
    if (state.needsAction) return 3;
    if (state.isInReview) return 2;
    if (state.isInProgress || state.isOpen) return 1;
    return 0;
  }
}

// Retained while older customer layouts are migrated to OmcIdentityHeader.
// ignore: unused_element
class _Header extends StatelessWidget {
  const _Header({
    required this.displayName,
    required this.avatarUrl,
    required this.actionNeededCount,
    required this.onNewService,
  });

  final String displayName;
  final String? avatarUrl;
  final int actionNeededCount;
  final VoidCallback onNewService;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                    _greeting(),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _TopActionBadge(count: actionNeededCount),
            const SizedBox(width: 12),
            _Avatar(name: displayName, avatarUrl: avatarUrl),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Services',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 34,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.65,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Manage and track all your services & requests',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onNewService,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('New Service'),
              style: FilledButton.styleFrom(
                backgroundColor: OmcPremium.services,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrackHeader extends StatelessWidget {
  const _TrackHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.textPrimary.withValues(alpha: 0.08),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.textPrimary,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Services',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 27,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Track requests, documents and payments',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
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
    required this.onChanged,
    required this.onFilterTap,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 13, right: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E4EA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: Color(0xFF6D7179)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: 'Search service or request ID',
                hintStyle: const TextStyle(
                  color: Color(0xFF8A8E96),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          controller.clear();
                          onChanged('');
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: const Color(0xFFF2F3F6),
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              onTap: onFilterTap,
              borderRadius: BorderRadius.circular(13),
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.tune_rounded,
                  size: 21,
                  color: Color(0xFF555961),
                ),
              ),
            ),
          ),
        ],
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

    return SizedBox(
      height: 36,
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
                ? AppTheme.primary.withValues(alpha: 0.10)
                : Colors.white,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              onTap: () => onSelected(filter),
              borderRadius: BorderRadius.circular(11),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primary.withValues(alpha: 0.32)
                        : const Color(0xFFE1E4E9),
                  ),
                ),
                child: Text(
                  '$label  $count',
                  style: TextStyle(
                    color: selected
                        ? AppTheme.primary
                        : const Color(0xFF686D76),
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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
    final route = '/my-services/${Uri.encodeComponent(serviceCase.id)}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE3E6EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F6),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _serviceIcon(serviceCase, state),
                      color: const Color(0xFF555B64),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceCase.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (reference?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            reference!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(label: palette.label, color: palette.color),
                ],
              ),
              const SizedBox(height: 11),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE9EBEF)),
                ),
                child: Row(
                  children: [
                    Icon(
                      state.isClosed
                          ? Icons.check_circle_outline_rounded
                          : Icons.description_outlined,
                      color: const Color(0xFF646A73),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.isClosed
                            ? 'Request closed'
                            : missingCount > 0
                            ? '$missingCount document${missingCount == 1 ? '' : 's'} missing'
                            : serviceCase.documentSummaryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!state.isClosed) ...[
                      const SizedBox(width: 8),
                      Text(
                        '$progressPercent%',
                        style: TextStyle(
                          color: palette.color,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!state.isClosed && nextStep?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 15,
                        color: Color(0xFF555A63),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Next: ',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              TextSpan(text: nextStep),
                            ],
                          ),
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
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 15,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      state.isClosed
                          ? 'Closed ${serviceCase.updatedAtLabel}'
                          : 'Updated ${serviceCase.updatedAtLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => context.push(route),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    child: Text(
                      needsUpload ? 'Upload documents' : 'View details',
                      style: TextStyle(
                        color: needsUpload
                            ? AppTheme.primary
                            : AppTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        _LoadingBlock(width: 150, height: 18, radius: 999, color: color),
        const SizedBox(height: 8),
        _LoadingBlock(width: 210, height: 34, radius: 14, color: color),
        const SizedBox(height: 22),
        _LoadingBlock(
          width: double.infinity,
          height: 176,
          radius: 24,
          color: color,
        ),
        const SizedBox(height: 16),
        _LoadingBlock(
          width: double.infinity,
          height: 46,
          radius: 16,
          color: color,
        ),
        const SizedBox(height: 12),
        _LoadingBlock(
          width: double.infinity,
          height: 120,
          radius: 22,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PremiumCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.assignment_turned_in_outlined,
                size: 42,
                color: OmcPremium.services,
              ),
              const SizedBox(height: 12),
              const Text(
                'No service requests yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start a guided request from the catalogue. Tracking appears here after submission.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onStartRequest,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Start a request'),
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
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No matching services',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nothing matched the ${filter.label.toLowerCase()} filter or search term.',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonal(
            onPressed: onClear,
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}

class _TopActionBadge extends StatelessWidget {
  const _TopActionBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final badgeCount = count.clamp(0, 99);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: AppTheme.textPrimary,
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: OmcPremium.services,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.6),
              ),
              child: Text(
                badgeCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final cleanAvatarUrl = avatarUrl?.trim();
    final imageUrl = cleanAvatarUrl == null || cleanAvatarUrl.isEmpty
        ? null
        : ApiConfig.resolveFileUrl(cleanAvatarUrl);
    final color = _serviceAvatarColor(name);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: imageUrl == null ? color.withValues(alpha: 0.10) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
    );
  }
}

Color _serviceAvatarColor(String name) {
  const colors = [
    OmcPremium.services,
    OmcPremium.documents,
    OmcPremium.payments,
    OmcPremium.track,
    OmcPremium.leads,
    OmcPremium.tasks,
  ];
  final source = name.trim().isEmpty ? 'OMC' : name.trim();
  final index =
      source.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % colors.length;
  return colors[index];
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
    required this.isInProgress,
    required this.isOpen,
  });

  final bool isCancelled;
  final bool isClosed;
  final bool needsAction;
  final bool isInReview;
  final bool isInProgress;
  final bool isOpen;
}

_ServiceCaseState _stateFor(ServiceCase serviceCase) {
  final status = serviceCase.status.trim().toLowerCase();
  final nextStep = serviceCase.nextStep?.trim().toLowerCase() ?? '';

  final isCancelled =
      status.contains('cancel') ||
      status.contains('reject') ||
      status.contains('declin') ||
      status.contains('blocked');
  final isClosed =
      !isCancelled &&
      (status.contains('complete') ||
          status.contains('closed') ||
          status.contains('done') ||
          status.contains('resolved'));
  final needsAction =
      !isCancelled &&
      !isClosed &&
      (serviceCase.customerActionRequired ||
          serviceCase.missingDocuments.isNotEmpty ||
          (serviceCase.missingDocumentsCount ?? 0) > 0 ||
          serviceCase.rejectedDocumentTotal > 0 ||
          serviceCase.rejectedPaymentTotal > 0 ||
          serviceCase.paymentDetails.any(
            (payment) => payment.needsCustomerAction,
          ) ||
          status.contains('waiting for document') ||
          status.contains('waiting for payment') ||
          status.contains('waiting for customer') ||
          status.contains('action required') ||
          nextStep.contains('upload') ||
          nextStep.contains('pay') ||
          nextStep.contains('submit'));
  final isInReview =
      !isCancelled &&
      !isClosed &&
      !needsAction &&
      (status.contains('review') ||
          status.contains('processing') ||
          status.contains('pending') ||
          status.contains('documents under review') ||
          status.contains('payment under review'));
  final isInProgress =
      !isCancelled &&
      !isClosed &&
      !needsAction &&
      !isInReview &&
      (status.contains('progress') || status.contains('working'));
  final isOpen =
      !isCancelled && !isClosed && !needsAction && !isInReview && !isInProgress;

  return _ServiceCaseState(
    isCancelled: isCancelled,
    isClosed: isClosed,
    needsAction: needsAction,
    isInReview: isInReview,
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
      color: Color(0xFFEF4444),
      icon: Icons.cancel_rounded,
    );
  }
  if (state.isClosed) {
    return const _Palette(
      label: 'Completed',
      color: Color(0xFF16A34A),
      icon: Icons.check_circle_rounded,
    );
  }
  if (state.needsAction) {
    return const _Palette(
      label: 'Action needed',
      color: Color(0xFFF59E0B),
      icon: Icons.priority_high_rounded,
    );
  }
  if (state.isInReview) {
    return const _Palette(
      label: 'In Review',
      color: Color(0xFF14B8A6),
      icon: Icons.fact_check_outlined,
    );
  }
  if (state.isInProgress) {
    return const _Palette(
      label: 'In Progress',
      color: Color(0xFF2563EB),
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

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning,';
  if (hour < 17) return 'Good afternoon,';
  return 'Good evening,';
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return 'OM';
  if (parts.length == 1) {
    final value = parts.first;
    return value.length >= 2
        ? value.substring(0, 2).toUpperCase()
        : value.substring(0, 1).toUpperCase();
  }
  return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
}
