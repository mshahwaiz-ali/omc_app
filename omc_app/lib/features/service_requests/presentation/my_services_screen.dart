import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/omc_identity_header.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../home/data/home_dashboard_repository.dart';
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
    final capabilities = authState.capabilities;
    final displayName =
        profile?.displayName ??
        authState.displayName ??
        _displayNameFromUserId(authState.userId ?? '');
    final avatarUrl = profile?.avatarUrl ?? authState.avatarUrl;
    final unreadNotifications =
        ref.watch(homeDashboardSummaryProvider).value?.unreadNotifications ?? 0;

    return Scaffold(
      body: SafeArea(
        top: true,
        child: casesAsync.when(
          loading: () => const _LoadingState(),
          error: (error, _) => _ErrorState(
            message: _cleanErrorMessage(error),
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
            final banner = _BannerData.from(capabilities, counts);
            final activityCases = _applySort(
              cases,
            ).take(3).toList(growable: false);

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
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                children: [
                  OmcIdentityHeader(
                    displayName: displayName,
                    avatarUrl: ApiConfig.resolveFileUrl(avatarUrl),
                    unreadNotifications: unreadNotifications,
                    onNotifications: () => context.push('/notifications'),
                    onAvatar: () => context.push('/profile'),
                  ),
                  const SizedBox(height: 18),
                  _SearchAndFilterRow(
                    controller: _searchController,
                    query: _query,
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    onFilterTap: () => _openFilterSheet(context, counts),
                  ),
                  const SizedBox(height: 16),
                  _StatusBanner(
                    data: banner,
                    onPrimary: () => context.go(banner.actionRoute),
                  ),
                  const SizedBox(height: 16),
                  _FilterRow(
                    cases: cases,
                    selectedFilter: _selectedFilter,
                    onSelected: (filter) =>
                        setState(() => _selectedFilter = filter),
                  ),
                  const SizedBox(height: 18),
                  _SectionHeader(
                    title: 'My Services (${cases.length})',
                    actionLabel: 'Sort by: ${_sortOption.label}',
                    onTap: () => _openSortSheet(context),
                  ),
                  const SizedBox(height: 10),
                  if (sorted.isEmpty)
                    _FilterEmptyState(
                      filter: _selectedFilter,
                      onClear: _resetFilters,
                    )
                  else
                    for (var i = 0; i < sorted.length; i++) ...[
                      _ServiceCard(serviceCase: sorted[i]),
                      if (i != sorted.length - 1) const SizedBox(height: 12),
                    ],
                  const SizedBox(height: 22),
                  _SectionHeader(
                    title: 'Recent Activity',
                    actionLabel: 'View all',
                    onTap: () => context.go('/my-services'),
                  ),
                  const SizedBox(height: 10),
                  _ActivityCard(cases: activityCases),
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
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search services, cases or requests...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 98,
          child: OutlinedButton.icon(
            onPressed: onFilterTap,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Filter'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 17),
              foregroundColor: OmcPremium.track,
              side: BorderSide(color: OmcPremium.track.withValues(alpha: 0.16)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.data, required this.onPrimary});

  final _BannerData data;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: data.tint,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: data.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: data.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(data.icon, color: data.accent, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onPrimary,
            style: FilledButton.styleFrom(
              backgroundColor: data.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: Text(data.actionLabel),
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
    final filters = <_ServiceCaseFilter>[
      _ServiceCaseFilter.all,
      _ServiceCaseFilter.open,
      _ServiceCaseFilter.inReview,
      _ServiceCaseFilter.actionNeeded,
      _ServiceCaseFilter.completed,
    ];

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = selectedFilter == filter;
          final count = filter.count(cases);
          final color = _filterColor(filter);

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onSelected(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.12) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? color.withValues(alpha: 0.30)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    filter.label,
                    style: TextStyle(
                      color: selected ? color : AppTheme.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: selected ? 0.14 : 0.07),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: selected ? color : AppTheme.textSecondary,
                        fontSize: 10.5,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.15,
            ),
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final state = _stateFor(serviceCase);
    final palette = _paletteFor(state);
    final progressPercent =
        serviceCase.progressPercent ??
        (serviceCase.progress.clamp(0, 1) * 100).round();

    return PremiumCard(
      onTap: () => context.go('/my-services/${serviceCase.id}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: OmcPremium.services.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: OmcPremium.services.withValues(alpha: 0.07),
                  ),
                ),
                child: const Icon(
                  Icons.folder_shared_rounded,
                  color: OmcPremium.services,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
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
                                serviceCase.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15.5,
                                  height: 1.2,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.15,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                serviceCase.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(label: palette.label, color: palette.color),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Requested on ${serviceCase.createdAtLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey.shade400,
                          size: 22,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
            decoration: BoxDecoration(
              color: palette.color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: serviceCase.progress.clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: palette.color.withValues(alpha: 0.10),
                    valueColor: AlwaysStoppedAnimation<Color>(palette.color),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '$progressPercent%',
                      style: TextStyle(
                        color: palette.color,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      serviceCase.actionRequiredLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PremiumInfoChip(
                icon: Icons.description_outlined,
                label: serviceCase.documentSummaryLabel,
              ),
              PremiumInfoChip(
                icon: Icons.payments_outlined,
                label: serviceCase.paymentSummaryLabel,
              ),
              if (serviceCase.reference != null &&
                  serviceCase.reference!.trim().isNotEmpty)
                PremiumInfoChip(
                  icon: Icons.confirmation_number_outlined,
                  label: serviceCase.reference!,
                ),
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.cases});

  final List<ServiceCase> cases;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < cases.length; i++) ...[
            _ActivityRow(serviceCase: cases[i]),
            if (i != cases.length - 1)
              const Divider(height: 1, indent: 74, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final state = _stateFor(serviceCase);
    final palette = _paletteFor(state);
    final subtitle = serviceCase.nextStep?.trim().isNotEmpty == true
        ? serviceCase.nextStep!
        : serviceCase.actionRequiredLabel;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () => context.go('/my-services/${serviceCase.id}'),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: palette.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(palette.icon, color: palette.color, size: 22),
      ),
      title: Text(
        serviceCase.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '$subtitle • ${serviceCase.updatedAtLabel}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
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
    required this.message,
    required this.onRetry,
    required this.onStartRequest,
  });

  final String message;
  final VoidCallback onRetry;
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
                Icons.cloud_off_rounded,
                size: 42,
                color: OmcPremium.danger,
              ),
              const SizedBox(height: 12),
              const Text(
                'Service tracking unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onStartRequest,
                      child: const Text('Start request'),
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

class _BannerData {
  const _BannerData({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionRoute,
    required this.icon,
    required this.accent,
    required this.tint,
    required this.border,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final String actionRoute;
  final IconData icon;
  final Color accent;
  final Color tint;
  final Color border;

  factory _BannerData.from(AuthCapabilities capabilities, _Counts counts) {
    if (capabilities.isGuest) {
      return const _BannerData(
        title: 'Sign in to track your services',
        subtitle:
            'Guest access is limited. Create an account to submit requests and follow progress.',
        actionLabel: 'Sign in',
        actionRoute: '/profile',
        icon: Icons.lock_outline_rounded,
        accent: Color(0xFF8B5CF6),
        tint: Color(0xFFF7F0FF),
        border: Color(0xFFE9D5FF),
      );
    }

    if (capabilities.isPending) {
      return const _BannerData(
        title: 'Your profile is under review',
        subtitle:
            'You have limited access. Complete your profile for full access to all services.',
        actionLabel: 'Complete profile',
        actionRoute: '/profile',
        icon: Icons.verified_user_outlined,
        accent: OmcPremium.services,
        tint: Color(0xFFFFF4F5),
        border: Color(0xFFFED7DC),
      );
    }

    if (capabilities.isRejected) {
      return const _BannerData(
        title: 'Access needs attention',
        subtitle:
            'Your profile requires review before full service access can be restored.',
        actionLabel: 'Contact support',
        actionRoute: '/services',
        icon: Icons.block_rounded,
        accent: Color(0xFFEF4444),
        tint: Color(0xFFFFF4F4),
        border: Color(0xFFFECACA),
      );
    }

    if (counts.actionNeeded > 0) {
      return const _BannerData(
        title: 'Action is needed on some requests',
        subtitle:
            'A few cases are waiting on documents or payment steps. Open the ones marked action needed.',
        actionLabel: 'Open requests',
        actionRoute: '/my-services',
        icon: Icons.priority_high_rounded,
        accent: Color(0xFFF59E0B),
        tint: Color(0xFFFFFAED),
        border: Color(0xFFFDE68A),
      );
    }

    return const _BannerData(
      title: 'Your services are moving',
      subtitle: 'Track progress, documents and updates from one place.',
      actionLabel: 'Browse services',
      actionRoute: '/services',
      icon: Icons.timeline_rounded,
      accent: Color(0xFF14B8A6),
      tint: Color(0xFFF0FFFD),
      border: Color(0xFFA7F3D0),
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

Color _filterColor(_ServiceCaseFilter filter) {
  switch (filter) {
    case _ServiceCaseFilter.all:
      return OmcPremium.services;
    case _ServiceCaseFilter.open:
      return const Color(0xFF2563EB);
    case _ServiceCaseFilter.inReview:
      return const Color(0xFF14B8A6);
    case _ServiceCaseFilter.actionNeeded:
      return const Color(0xFFF59E0B);
    case _ServiceCaseFilter.completed:
      return const Color(0xFF16A34A);
    case _ServiceCaseFilter.cancelled:
      return const Color(0xFFEF4444);
  }
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

String _displayNameFromUserId(String userId) {
  final cleaned = userId.trim();
  if (cleaned.isEmpty) return 'Ali Raza';

  final localPart = cleaned.contains('@') ? cleaned.split('@').first : cleaned;
  final pieces = localPart
      .split(RegExp(r'[._\-\s]+'))
      .where((piece) => piece.trim().isNotEmpty)
      .toList(growable: false);
  if (pieces.isEmpty) return localPart;
  return pieces.map(_titleCase).join(' ');
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
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

String _cleanErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final message = error.toString().replaceFirst('ApiError:', '').trim();
  if (message.isNotEmpty) return message;
  return 'Service tracking is unavailable right now. Please try again.';
}
