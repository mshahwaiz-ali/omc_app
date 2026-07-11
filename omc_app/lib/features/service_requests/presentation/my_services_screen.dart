import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
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
    final capabilities = profile?.capabilities ?? authState.capabilities;
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
                  _TrackHeader(
                    unreadNotifications: unreadNotifications,
                    avatarUrl: ApiConfig.resolveFileUrl(avatarUrl),
                    displayName: displayName,
                    onBack: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                    onNotifications: () => context.push('/notifications'),
                    onAvatar: () => context.push('/profile'),
                  ),
                  const SizedBox(height: 24),
                  _SearchAndFilterRow(
                    controller: _searchController,
                    query: _query,
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    onFilterTap: () => _openFilterSheet(context, counts),
                  ),
                  const SizedBox(height: 18),
                  _FilterRow(
                    cases: cases,
                    selectedFilter: _selectedFilter,
                    onSelected: (filter) =>
                        setState(() => _selectedFilter = filter),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'My Services (${sorted.length})',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 19,
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
                  const SizedBox(height: 26),
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
  const _TrackHeader({
    required this.unreadNotifications,
    required this.avatarUrl,
    required this.displayName,
    required this.onBack,
    required this.onNotifications,
    required this.onAvatar,
  });

  final int unreadNotifications;
  final String? avatarUrl;
  final String displayName;
  final VoidCallback onBack;
  final VoidCallback onNotifications;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.textPrimary.withValues(alpha: 0.09),
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.textPrimary,
                size: 27,
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Services',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Track requests, documents and payments',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onNotifications,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.textPrimary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
            if (unreadNotifications > 0)
              Positioned(
                right: -3,
                top: -4,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 21,
                    minHeight: 21,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: OmcPremium.danger,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    unreadNotifications > 99 ? '99+' : '$unreadNotifications',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 9),
        InkWell(
          onTap: onAvatar,
          customBorder: const CircleBorder(),
          child: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.textPrimary.withValues(alpha: 0.10),
              ),
            ),
            child: ClipOval(
              child: avatarUrl?.trim().isNotEmpty == true
                  ? Image.network(
                      avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _TrackInitialsAvatar(name: displayName),
                    )
                  : _TrackInitialsAvatar(name: displayName),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackInitialsAvatar extends StatelessWidget {
  const _TrackInitialsAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();

    return Container(
      color: OmcPremium.services.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? 'U' : initials,
        style: const TextStyle(
          color: OmcPremium.services,
          fontWeight: FontWeight.w900,
        ),
      ),
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
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppTheme.textPrimary.withValues(alpha: 0.09),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: 'Search service or request ID',
                hintStyle: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.search_rounded,
                    color: AppTheme.textSecondary,
                    size: 27,
                  ),
                ),
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
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 58,
          child: OutlinedButton.icon(
            onPressed: onFilterTap,
            icon: const Icon(Icons.filter_alt_outlined, size: 22),
            label: const Text('Filter'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.textPrimary,
              side: BorderSide(
                color: AppTheme.textPrimary.withValues(alpha: 0.10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(21),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
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
      height: 49,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = filter == selectedFilter;
          final count = filter.count(cases);
          final color = _filterColor(filter);

          return InkWell(
            onTap: () => onSelected(filter),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 17),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.06) : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? color
                      : AppTheme.textPrimary.withValues(alpha: 0.09),
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    filter == _ServiceCaseFilter.open ? 'Active' : filter.label,
                    style: TextStyle(
                      color: selected ? color : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: selected ? 0.14 : 0.09),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
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
        (missingCount > 0 ||
            serviceCase.missingDocuments.isNotEmpty ||
            (nextStep?.toLowerCase().contains('upload') ?? false));

    final borderColor = palette.color.withValues(alpha: 0.22);
    final route = '/my-services/${Uri.encodeComponent(serviceCase.id)}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: palette.color.withValues(alpha: 0.035),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: palette.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Icon(
                      _serviceIcon(serviceCase, state),
                      color: palette.color,
                      size: 31,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                serviceCase.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 18,
                                  height: 1.18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _StatusPill(
                              label: palette.label,
                              color: palette.color,
                            ),
                          ],
                        ),
                        if (reference?.isNotEmpty == true) ...[
                          const SizedBox(height: 5),
                          Text(
                            reference!,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  backgroundColor: AppTheme.textPrimary
                                      .withValues(alpha: 0.06),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    palette.color,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              '$progressPercent%',
                              style: TextStyle(
                                color: palette.color,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Padding(
                padding: const EdgeInsets.only(left: 80),
                child: Column(
                  children: [
                    if (nextStep?.isNotEmpty == true)
                      _ServiceInformationRow(
                        icon: state.isClosed
                            ? Icons.check_circle_outline_rounded
                            : Icons.error_outline_rounded,
                        text: state.isClosed
                            ? nextStep!
                            : 'Next step: $nextStep',
                        color: palette.color,
                        trailing: missingCount > 0
                            ? _InlineBadge(
                                label:
                                    '$missingCount document${missingCount == 1 ? '' : 's'} missing',
                                color: OmcPremium.danger,
                              )
                            : null,
                      ),
                    if (nextStep?.isNotEmpty == true)
                      const SizedBox(height: 12),
                    _ServiceInformationRow(
                      icon: Icons.calendar_month_outlined,
                      text: state.isClosed
                          ? 'Completed ${serviceCase.updatedAtLabel}'
                          : 'Updated ${serviceCase.updatedAtLabel}',
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              Divider(
                height: 1,
                color: AppTheme.textPrimary.withValues(alpha: 0.07),
              ),
              const SizedBox(height: 14),
              if (needsUpload && capabilities.canUploadDocuments)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push(route),
                        icon: const Icon(Icons.upload_rounded),
                        label: const Text('Upload document'),
                        style: FilledButton.styleFrom(
                          backgroundColor: OmcPremium.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(route),
                        icon: const Icon(Icons.open_in_new_rounded, size: 19),
                        label: const Text('Open workspace'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: OmcPremium.danger,
                          side: BorderSide(
                            color: OmcPremium.danger.withValues(alpha: 0.18),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(route),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: Text(
                      state.isClosed ? 'View summary' : 'View details',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: BorderSide(
                        color: AppTheme.textPrimary.withValues(alpha: 0.10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
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

class _ServiceInformationRow extends StatelessWidget {
  const _ServiceInformationRow({
    required this.icon,
    required this.text,
    required this.color,
    this.trailing,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color == AppTheme.textSecondary
                  ? AppTheme.textSecondary
                  : AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

class _InlineBadge extends StatelessWidget {
  const _InlineBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.cases});

  final List<ServiceCase> cases;

  @override
  Widget build(BuildContext context) {
    if (cases.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppTheme.textPrimary.withValues(alpha: 0.07),
          ),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.history_rounded,
              color: AppTheme.textSecondary,
              size: 30,
            ),
            SizedBox(height: 10),
            Text(
              'No recent service activity',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < cases.length; index++) ...[
            _ActivityRow(serviceCase: cases[index]),
            if (index != cases.length - 1)
              Divider(
                height: 1,
                indent: 70,
                endIndent: 16,
                color: AppTheme.textPrimary.withValues(alpha: 0.07),
              ),
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
    final nextStep = serviceCase.nextStep?.trim();
    final subtitle = nextStep?.isNotEmpty == true
        ? nextStep!
        : serviceCase.actionRequiredLabel;

    return InkWell(
      onTap: () =>
          context.push('/my-services/${Uri.encodeComponent(serviceCase.id)}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: palette.color.withValues(alpha: 0.09),
                shape: BoxShape.circle,
              ),
              child: Icon(
                state.isClosed
                    ? Icons.check_circle_outline_rounded
                    : palette.icon,
                color: palette.color,
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              serviceCase.updatedAtLabel,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
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
