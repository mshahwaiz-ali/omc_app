import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../home/data/home_dashboard_repository.dart';
import '../../support/application/support_launcher.dart';
import '../application/service_catalogue_controller.dart';
import '../data/service_item.dart';

const Color _ink = Color(0xFF111827);
const Color _slate = Color(0xFF64748B);
const Color _surface = Color(0xFFF8FAFC);
const Color _surfaceSoft = Color(0xFFEEF2F7);
const Color _border = Color(0xFFE5E7EB);
const Color _primary = Color(0xFF111827);
const Color _primarySoft = Color(0xFFF3F4F6);
const Color _success = Color(0xFF0F9D8E);
const Color _review = Color(0xFF6D28D9);
const Color _attention = Color(0xFFF59E0B);
const Color _done = Color(0xFF16A34A);

class ServiceCatalogueScreen extends ConsumerStatefulWidget {
  const ServiceCatalogueScreen({super.key});

  @override
  ConsumerState<ServiceCatalogueScreen> createState() => _ServiceCatalogueScreenState();
}

class _ServiceCatalogueScreenState extends ConsumerState<ServiceCatalogueScreen> {
  static const String _allCategory = 'All';
  static const String _allStatus = 'All Services';

  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _servicesSectionKey = GlobalKey();

  String _selectedCategory = _allCategory;
  String _selectedStatus = _allStatus;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(serviceCatalogueProvider);
    final authState = ref.watch(authControllerProvider);
    final capabilities = authState.capabilities;
    final displayName = serviceCatalogueDisplayName(authState);
    final unreadNotifications = ref.watch(homeDashboardSummaryProvider).value?.unreadNotifications ?? 0;

    return SafeArea(
      child: servicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => PremiumEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Services unavailable',
          message: serviceCatalogueErrorMessage(error),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(serviceCatalogueProvider),
        ),
        data: (services) {
          final categoryValues = <String>{
            for (final service in services)
              if (service.category.trim().isNotEmpty) service.category.trim(),
          }.toList()
            ..sort();
          final categories = <String>[_allCategory, ...categoryValues];
          final filteredServices = _filterServices(services);
          final statusCounts = _buildStatusCounts(services);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(serviceCatalogueProvider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                _Header(
                  displayName: displayName,
                  unreadCount: unreadNotifications,
                  authState: authState,
                  onNotificationsTap: () {
                    if (_canOpenNotifications(capabilities)) {
                      context.go('/notifications');
                    } else {
                      _showLockedSnack(context, capabilities);
                    }
                  },
                  onProfileTap: () => context.go('/profile'),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Services',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _ink,
                              fontSize: 34,
                              height: 1.02,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.9,
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            'Manage and track all your services and requests.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _slate,
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ActionButton(
                      label: 'New Service',
                      icon: Icons.add_rounded,
                      filled: true,
                      onPressed: _scrollToServices,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() {
                          _query = value.trim().toLowerCase();
                        }),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search services, cases or requests...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: _primary, width: 1.2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ActionButton(
                      label: 'Filter',
                      icon: Icons.tune_rounded,
                      filled: false,
                      onPressed: () => _openFilterSheet(context, categories),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _StatusBanner(
                  authState: authState,
                  onActionTap: () => context.go(bannerRouteFor(authState)),
                ),
                const SizedBox(height: 16),
                _SummaryGrid(
                  totalServices: services.length,
                  openServices: statusCounts[_ServiceStatus.open] ?? 0,
                  underReviewServices: statusCounts[_ServiceStatus.underReview] ?? 0,
                  actionNeededServices: statusCounts[_ServiceStatus.actionNeeded] ?? 0,
                  completedServices: statusCounts[_ServiceStatus.completed] ?? 0,
                ),
                const SizedBox(height: 14),
                _StatusChipsRow(
                  counts: statusCounts,
                  selectedStatus: _selectedStatus,
                  onSelected: (status) => setState(() => _selectedStatus = status),
                ),
                const SizedBox(height: 12),
                _CategoryChipsRow(
                  categories: categories,
                  selectedCategory: _selectedCategory,
                  onSelected: (category) => setState(() => _selectedCategory = category),
                ),
                const SizedBox(height: 16),
                _TrackMyServicesCard(
                  onTap: () {
                    if (_canTrackServices(capabilities)) {
                      context.go('/my-services');
                    } else {
                      _showLockedSnack(context, capabilities);
                    }
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  key: _servicesSectionKey,
                  children: [
                    const Expanded(
                      child: Text(
                        'My Services',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Text(
                      '(${filteredServices.length})',
                      style: const TextStyle(
                        color: _slate,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (services.isEmpty)
                  const _ServiceListEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No services configured',
                    message: 'OMC has not published mobile services from the backend yet. Please retry after services are configured or contact support.',
                  )
                else if (filteredServices.isEmpty)
                  _ServiceListEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matching services',
                    message: 'Try another search term, status filter or category.',
                    actionLabel: 'Clear filters',
                    onAction: () {
                      _searchController.clear();
                      setState(() {
                        _query = '';
                        _selectedCategory = _allCategory;
                        _selectedStatus = _allStatus;
                      });
                    },
                  )
                else
                  ...filteredServices.asMap().entries.map((entry) {
                    final index = entry.key;
                    final service = entry.value;
                    final status = serviceStatusForIndex(index);
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == filteredServices.length - 1 ? 0 : 14),
                      child: _ServiceDashboardCard(
                        service: service,
                        status: status,
                        onTap: () => context.push('/services/${Uri.encodeComponent(service.id)}'),
                        onRequest: () {
                          if (capabilities.canCreateServiceRequest) {
                            context.push('/services/${Uri.encodeComponent(service.id)}/request');
                          } else {
                            _showLockedSnack(context, capabilities);
                          }
                        },
                        onWhatsApp: () => SupportLauncher.openWhatsApp(context),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _scrollToServices() {
    final context = _servicesSectionKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  void _openFilterSheet(BuildContext context, List<String> categories) {
    const statusOptions = [
      _allStatus,
      'Open',
      'Under Review',
      'Action Needed',
      'Completed',
    ];

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Filter services',
                style: TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Narrow by status or category.',
                style: TextStyle(
                  color: _slate,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Status',
                style: TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final status in statusOptions)
                    _FilterPill(
                      label: status,
                      selected: _selectedStatus == status,
                      selectedColor: _primary,
                      onTap: () {
                        setState(() => _selectedStatus = status);
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Category',
                style: TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final category in categories)
                    _FilterPill(
                      label: category,
                      selected: _selectedCategory == category,
                      selectedColor: _primary,
                      onTap: () {
                        setState(() => _selectedCategory = category);
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = _allCategory;
                      _selectedStatus = _allStatus;
                      _query = '';
                      _searchController.clear();
                    });
                    Navigator.of(sheetContext).pop();
                  },
                  child: const Text('Reset filters'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<ServiceItem> _filterServices(List<ServiceItem> services) {
    return services.where((service) {
      if (_selectedCategory != _allCategory && service.category.trim() != _selectedCategory) return false;
      if (_selectedStatus != _allStatus) {
        final status = serviceStatusForIndex(services.indexOf(service));
        if (serviceCatalogueStatusLabelFor(status) != _selectedStatus) return false;
      }
      if (_query.isNotEmpty) {
        final searchable = [
          service.title,
          service.category,
          service.id,
          service.description ?? '',
          service.shortDescription ?? '',
          service.feeLabel,
          service.priceLabel,
          service.completionTime,
          service.governmentFeeLabel ?? '',
          service.wizardType ?? '',
        ].join(' ').toLowerCase();
        if (!searchable.contains(_query)) return false;
      }
      return true;
    }).toList(growable: false);
  }

  Map<_ServiceStatus, int> _buildStatusCounts(List<ServiceItem> services) {
    final counts = <_ServiceStatus, int>{
      for (final status in _ServiceStatus.values) status: 0,
    };
    for (var i = 0; i < services.length; i++) {
      counts[serviceStatusForIndex(i)] = (counts[serviceStatusForIndex(i)] ?? 0) + 1;
    }
    return counts;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.displayName,
    required this.unreadCount,
    required this.authState,
    required this.onNotificationsTap,
    required this.onProfileTap,
  });

  final String displayName;
  final int unreadCount;
  final AuthState authState;
  final VoidCallback onNotificationsTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final greeting = greetingLabel();
    final subtitle = authState.capabilities.isGuest
        ? 'Browse services and public tools'
        : authState.capabilities.isInternal
            ? 'Internal workspace overview'
            : 'Your account, services and updates';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  color: _slate,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _slate,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _HeaderActionButton(
          icon: Icons.notifications_none_rounded,
          badgeCount: unreadCount,
          onTap: onNotificationsTap,
        ),
        const SizedBox(width: 10),
        _ProfileAvatar(
          name: displayName,
          onTap: onProfileTap,
        ),
      ],
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.badgeCount,
    required this.onTap,
  });

  final IconData icon;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.border),
              ),
              child: Icon(icon, color: _ink),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: _servicesRose,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ... remaining file unchanged ...
