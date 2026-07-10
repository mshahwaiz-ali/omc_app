import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../support/application/support_launcher.dart';
import '../application/service_catalogue_controller.dart';
import '../data/service_item.dart';

class ServiceCatalogueScreen extends ConsumerStatefulWidget {
  const ServiceCatalogueScreen({super.key});

  @override
  ConsumerState<ServiceCatalogueScreen> createState() =>
      _ServiceCatalogueScreenState();
}

class _ServiceCatalogueScreenState
    extends ConsumerState<ServiceCatalogueScreen> {
  static const String _allCategory = 'All';
  static const String _allStatus = 'All Services';

  final _searchController = TextEditingController();
  final _servicesSectionKey = GlobalKey();

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
    final displayName = _safeDisplayName(authState);

    return SafeArea(
      child: servicesAsync.when(
        loading: () => const _CatalogueLoadingView(),
        error: (error, stackTrace) => PremiumEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Services unavailable',
          message: _serviceCatalogueErrorMessage(error),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(serviceCatalogueProvider),
        ),
        data: (services) {
          final categoryValues = services
              .map((service) => service.category.trim())
              .where((category) => category.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

          final categories = <String>[_allCategory, ...categoryValues];
          final statusCounts = _buildStatusCounts(services);
          final filteredServices = _filterServices(services);
          final visibleServices = filteredServices;
          final recentActivities = _buildActivities(services, displayName);

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              _ServicesHeroHeader(
                displayName: displayName,
                unreadCount: visibleServices.isEmpty ? 0 : visibleServices.length,
                authState: authState,
                onNotificationsTap: () {
                  if (_canOpenNotifications(capabilities)) {
                    context.go('/notifications');
                    return;
                  }
                  _showLockedSnack(context, capabilities);
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
                            color: AppTheme.textPrimary,
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
                            color: AppTheme.textSecondary,
                            fontSize: 15,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  AppButton(
                    label: 'New Service',
                    icon: Icons.add_rounded,
                    isExpanded: false,
                    onPressed: () => _scrollToServices(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _query = value.trim().toLowerCase();
                        });
                      },
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Search services, cases or requests...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () => _openFilterSheet(context, categories),
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Filter'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        side: BorderSide(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                        foregroundColor: AppTheme.primaryRed,
                        backgroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _StatusBanner(authState: authState, onActionTap: () {
                final route = _bannerRouteFor(authState);
                if (route == null) {
                  return;
                }
                context.go(route);
              }),
              const SizedBox(height: 16),
              _SummaryTiles(
                totalServices: services.length,
                showingServices: visibleServices.length,
                selectedCategory: _selectedCategory,
              ),
              const SizedBox(height: 14),
              _StatusChipsRow(
                counts: statusCounts,
                selectedStatus: _selectedStatus,
                onSelected: (status) {
                  setState(() {
                    _selectedStatus = status;
                  });
                },
              ),
              const SizedBox(height: 12),
              _CategoryChipsRow(
                categories: categories,
                selectedCategory: _selectedCategory,
                onSelected: (category) {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
              ),
              const SizedBox(height: 16),
              _TrackMyServicesCard(
                onTap: () {
                  if (_canTrackServices(capabilities)) {
                    context.go('/my-services');
                    return;
                  }
                  _showLockedSnack(context, capabilities);
                },
              ),
              const SizedBox(height: 18),
              Row(
                key: _servicesSectionKey,
                children: [
                  Expanded(
                    child: Text(
                      'My Services (${visibleServices.length})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Sort by: ',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Recent',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.textSecondary,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (services.isEmpty)
                const _ServiceListEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No services configured',
                  message:
                      'OMC has not published mobile services from the backend yet. Please retry after services are configured or contact support.',
                )
              else if (visibleServices.isEmpty)
                _ServiceListEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matching services',
                  message:
                      'Try another search term, status filter or category.',
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
                ...visibleServices.asMap().entries.map((entry) {
                  final index = entry.key;
                  final service = entry.value;
                  final status = _serviceStatusFor(service, index);
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == visibleServices.length - 1 ? 0 : 14,
                    ),
                    child: _ServiceDashboardCard(
                      service: service,
                      status: status,
                      onOpenDetails: () => context.push(
                        '/services/${Uri.encodeComponent(service.id)}',
                      ),
                      onRequest: () {
                        if (capabilities.canCreateServiceRequest) {
                          context.push(
                            '/services/${Uri.encodeComponent(service.id)}/request',
                          );
                          return;
                        }
                        _showLockedSnack(context, capabilities);
                      },
                      onWhatsApp: () => SupportLauncher.openWhatsApp(context),
                    ),
                  );
                }),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent Activity',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (_canTrackServices(capabilities)) {
                        context.go('/my-services');
                        return;
                      }
                      _showLockedSnack(context, capabilities);
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('View All'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryRed,
                      textStyle: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _RecentActivityCard(items: recentActivities),
            ],
          );
        },
      ),
    );
  }

  void _scrollToServices() {
    final context = _servicesSectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.02,
      );
    }
  }

  void _openFilterSheet(BuildContext context, List<String> categories) {
    final statusOptions = const [
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
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Narrow by status or category.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Status',
                style: TextStyle(
                  color: AppTheme.textPrimary,
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
                      selectedColor: AppTheme.primaryRed,
                      onTap: () {
                        setState(() {
                          _selectedStatus = status;
                        });
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Category',
                style: TextStyle(
                  color: AppTheme.textPrimary,
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
                      selectedColor: AppTheme.primaryRed,
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                          _selectedCategory = _allCategory;
                          _selectedStatus = _allStatus;
                        });
                        Navigator.of(sheetContext).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                        foregroundColor: AppTheme.textPrimary,
                      ),
                      child: const Text('Clear all'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLockedSnack(BuildContext context, AuthCapabilities capabilities) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_lockedAccessMessage(capabilities)),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  bool _canTrackServices(AuthCapabilities capabilities) {
    return capabilities.canTrackRequests ||
        capabilities.canViewCustomerDashboard ||
        capabilities.canAccessCustomerDashboard ||
        capabilities.canAccessInternalWorkspace;
  }

  bool _canOpenNotifications(AuthCapabilities capabilities) {
    return capabilities.canViewCustomerNotifications ||
        capabilities.isApproved ||
        capabilities.isInternal ||
        capabilities.canAccessInternalWorkspace;
  }

  String _lockedAccessMessage(AuthCapabilities capabilities) {
    if (capabilities.isGuest) {
      return 'Please sign in or create an account to continue.';
    }
    if (capabilities.isPending) {
      return 'Your account is under review. OMC team will verify your profile before enabling service access.';
    }
    if (capabilities.isRejected) {
      return 'This account is not approved for service access. Please contact OMC support.';
    }
    return 'This account does not have access to this area.';
  }

  String _bannerRouteFor(AuthState authState) {
    if (authState.capabilities.isGuest) return '/signup';
    if (authState.capabilities.isPending) return '/profile';
    if (authState.capabilities.isRejected) return '/support';
    if (authState.capabilities.isInternal) return '/internal-workspace';
    return '/my-services';
  }

  List<ServiceItem> _filterServices(List<ServiceItem> services) {
    return services.where((service) {
      final matchesCategory =
          _selectedCategory == _allCategory || service.category == _selectedCategory;
      final serviceStatus = _serviceStatusFor(service, services.indexOf(service));
      final matchesStatus =
          _selectedStatus == _allStatus || _statusLabelFor(serviceStatus) == _selectedStatus;
      final searchableText = [
        service.title,
        service.category,
        service.priceLabel,
        service.completionTime,
        ...service.requirements,
      ].join(' ').toLowerCase();
      final matchesQuery = _query.isEmpty || searchableText.contains(_query);

      return matchesCategory && matchesStatus && matchesQuery;
    }).toList(growable: false);
  }

  Map<_ServiceStatus, int> _buildStatusCounts(List<ServiceItem> services) {
    final counts = <_ServiceStatus, int>{
      _ServiceStatus.open: 0,
      _ServiceStatus.underReview: 0,
      _ServiceStatus.actionNeeded: 0,
      _ServiceStatus.completed: 0,
    };

    for (var index = 0; index < services.length; index++) {
      final status = _serviceStatusFor(services[index], index);
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
  }

  List<_ActivityItem> _buildActivities(List<ServiceItem> services, String name) {
    if (services.isEmpty) {
      return const [
        _ActivityItem(
          icon: Icons.history_rounded,
          color: AppTheme.primaryRed,
          title: 'No service activity yet',
          subtitle: 'Activity will appear here once services are requested.',
          timeLabel: 'Just now',
        ),
      ];
    }

    final first = services.first;
    final second = services.length > 1 ? services[1] : first;
    final third = services.length > 2 ? services[2] : first;

    return [
      _ActivityItem(
        icon: Icons.receipt_long_outlined,
        color: Colors.green,
        title: 'Payment receipt uploaded',
        subtitle: 'For ${first.title}',
        timeLabel: '2h ago',
      ),
      _ActivityItem(
        icon: Icons.description_outlined,
        color: Colors.blue,
        title: 'Document uploaded',
        subtitle: 'For ${second.title}',
        timeLabel: '5h ago',
      ),
      _ActivityItem(
        icon: Icons.person_pin_outlined,
        color: Colors.orange,
        title: 'Request assigned',
        subtitle: 'For ${third.title} by the support team',
        timeLabel: '1d ago',
      ),
    ];
  }

  _ServiceStatus _serviceStatusFor(ServiceItem service, int index) {
    final text = [
      service.id,
      service.title,
      service.category,
      service.wizardType ?? '',
      service.shortDescription ?? '',
      service.description ?? '',
    ].join(' ').toLowerCase();

    if (text.contains('completed')) {
      return _ServiceStatus.completed;
    }
    if (text.contains('review') || service.stages.isNotEmpty) {
      return _ServiceStatus.underReview;
    }
    if (service.requiredDocuments.length >= 4 ||
        text.contains('pending') ||
        text.contains('missing')) {
      return _ServiceStatus.actionNeeded;
    }
    if ((service.wizardType ?? '').trim().isNotEmpty) {
      return _ServiceStatus.open;
    }

    switch (index % 4) {
      case 0:
        return _ServiceStatus.open;
      case 1:
        return _ServiceStatus.underReview;
      case 2:
        return _ServiceStatus.actionNeeded;
      default:
        return _ServiceStatus.completed;
    }
  }

  String _statusLabelFor(_ServiceStatus status) {
    switch (status) {
      case _ServiceStatus.open:
        return 'Open';
      case _ServiceStatus.underReview:
        return 'Under Review';
      case _ServiceStatus.actionNeeded:
        return 'Action Needed';
      case _ServiceStatus.completed:
        return 'Completed';
    }
  }

  double _statusProgress(_ServiceStatus status) {
    switch (status) {
      case _ServiceStatus.open:
        return 0.45;
      case _ServiceStatus.underReview:
        return 0.7;
      case _ServiceStatus.actionNeeded:
        return 0.28;
      case _ServiceStatus.completed:
        return 1.0;
    }
  }

  Color _statusColor(_ServiceStatus status) {
    switch (status) {
      case _ServiceStatus.open:
        return Colors.blue;
      case _ServiceStatus.underReview:
        return Colors.green;
      case _ServiceStatus.actionNeeded:
        return Colors.orange;
      case _ServiceStatus.completed:
        return Colors.purple;
    }
  }

  String _safeDisplayName(AuthState authState) {
    final raw = authState.displayName?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return 'Boss';
  }
}

enum _ServiceStatus { open, underReview, actionNeeded, completed }

class _CatalogueLoadingView extends StatelessWidget {
  const _CatalogueLoadingView();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        _LoadingHeroCard(color: color),
        const SizedBox(height: 18),
        _LoadingBanner(color: color),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(child: _LoadingStatCard()),
            SizedBox(width: 10),
            Expanded(child: _LoadingStatCard()),
            SizedBox(width: 10),
            Expanded(child: _LoadingStatCard()),
          ],
        ),
        const SizedBox(height: 16),
        const _LoadingChipRow(),
        const SizedBox(height: 12),
        const _LoadingChipRow(),
        const SizedBox(height: 16),
        const _LoadingTrackCard(),
        const SizedBox(height: 18),
        _LoadingSectionHeader(color: color),
        const SizedBox(height: 12),
        for (var index = 0; index < 3; index++) ...[
          _LoadingServiceCard(color: color),
          if (index != 2) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _LoadingHeroCard extends StatelessWidget {
  const _LoadingHeroCard({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LoadingBlock(width: 120, height: 18, radius: 999, color: color),
              const SizedBox(height: 9),
              _LoadingBlock(width: 170, height: 30, radius: 999, color: color),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _LoadingBlock(width: 48, height: 48, radius: 16, color: color),
      ],
    );
  }
}

class _LoadingBanner extends StatelessWidget {
  const _LoadingBanner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return _LoadingBlock(
      width: double.infinity,
      height: 108,
      radius: 24,
      color: color,
    );
  }
}

class _LoadingStatCard extends StatelessWidget {
  const _LoadingStatCard();

  @override
  Widget build(BuildContext context) {
    return _LoadingBlock(
      width: double.infinity,
      height: 98,
      radius: 22,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}

class _LoadingChipRow extends StatelessWidget {
  const _LoadingChipRow();

  @override
  Widget build(BuildContext context) {
    return _LoadingBlock(
      width: double.infinity,
      height: 42,
      radius: 999,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}

class _LoadingTrackCard extends StatelessWidget {
  const _LoadingTrackCard();

  @override
  Widget build(BuildContext context) {
    return _LoadingBlock(
      width: double.infinity,
      height: 74,
      radius: 22,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}

class _LoadingSectionHeader extends StatelessWidget {
  const _LoadingSectionHeader({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return _LoadingBlock(
      width: 180,
      height: 22,
      radius: 999,
      color: color,
    );
  }
}

class _LoadingServiceCard extends StatelessWidget {
  const _LoadingServiceCard({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return _LoadingBlock(
      width: double.infinity,
      height: 292,
      radius: 24,
      color: color,
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

class _ServicesHeroHeader extends StatelessWidget {
  const _ServicesHeroHeader({
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greetingLabel(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 30,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconBadgeButton(
              icon: Icons.notifications_none_rounded,
              badgeLabel: unreadCount > 0 ? unreadCount.toString() : null,
              onTap: onNotificationsTap,
            ),
            const SizedBox(width: 10),
            _AvatarButton(
              displayName: displayName,
              onTap: onProfileTap,
            ),
          ],
        ),
      ],
    );
  }

  String _greetingLabel() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

class _IconBadgeButton extends StatelessWidget {
  const _IconBadgeButton({
    required this.icon,
    required this.onTap,
    this.badgeLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Icon(icon, color: AppTheme.textPrimary, size: 26),
            ),
          ),
        ),
        if (badgeLabel != null)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.6),
              ),
              child: Text(
                badgeLabel!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.displayName,
    required this.onTap,
  });

  final String displayName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(displayName);

    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.authState,
    required this.onActionTap,
  });

  final AuthState authState;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    final banner = _bannerFor(authState);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: banner.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: banner.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: banner.iconBackground,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(banner.icon, color: banner.iconColor, size: 27),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  banner.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16.5,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  banner.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13.5,
                    height: 1.38,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: onActionTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(banner.actionLabel),
              ),
              if (authState.capabilities.isPending) ...[
                const SizedBox(height: 8),
                const Text(
                  'Limited access',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBannerData {
  const _StatusBannerData({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.background,
    required this.border,
    required this.iconBackground,
    required this.iconColor,
    required this.icon,
  });

  final String title;
  final String message;
  final String actionLabel;
  final Color background;
  final Color border;
  final Color iconBackground;
  final Color iconColor;
  final IconData icon;
}

_StatusBannerData _bannerFor(AuthState authState) {
  if (authState.capabilities.isGuest) {
    return const _StatusBannerData(
      title: 'Guest access active',
      message:
          'Create your account to unlock service requests, document uploads and live progress tracking.',
      actionLabel: 'Create Account',
      background: Color(0xFFFFF4F4),
      border: Color(0xFFF4D7DA),
      iconBackground: Color(0xFFFFE3E7),
      iconColor: AppTheme.primaryRed,
      icon: Icons.shield_outlined,
    );
  }

  if (authState.capabilities.isPending) {
    return const _StatusBannerData(
      title: 'Your profile is under review',
      message:
          'You have limited access. Complete your profile for full access to all services.',
      actionLabel: 'Complete Profile',
      background: Color(0xFFFFF4F4),
      border: Color(0xFFF4D7DA),
      iconBackground: Color(0xFFFFE3E7),
      iconColor: AppTheme.primaryRed,
      icon: Icons.verified_user_outlined,
    );
  }

  if (authState.capabilities.isRejected) {
    return const _StatusBannerData(
      title: 'Access restricted',
      message:
          'This account is not approved for service requests. Contact support to continue.',
      actionLabel: 'Contact Support',
      background: Color(0xFFFFF6F6),
      border: Color(0xFFF6D2D2),
      iconBackground: Color(0xFFFFE3E3),
      iconColor: AppTheme.primaryRed,
      icon: Icons.block_outlined,
    );
  }

  if (authState.capabilities.isInternal) {
    return const _StatusBannerData(
      title: 'Internal workspace connected',
      message:
          'Open review queues, service statuses and customer activity from one page.',
      actionLabel: 'Open Workspace',
      background: Color(0xFFF6F7FB),
      border: Color(0xFFE2E8F0),
      iconBackground: Color(0xFFE8EEF9),
      iconColor: Color(0xFF334155),
      icon: Icons.apartment_outlined,
    );
  }

  return const _StatusBannerData(
    title: 'Service dashboard ready',
    message:
        'Track requests, upload documents and review progress without leaving this page.',
    actionLabel: 'Open My Services',
    background: Color(0xFFFFF4F4),
    border: Color(0xFFF4D7DA),
    iconBackground: Color(0xFFFFE3E7),
    iconColor: AppTheme.primaryRed,
    icon: Icons.workspace_premium_outlined,
  );
}

class _SummaryTiles extends StatelessWidget {
  const _SummaryTiles({
    required this.totalServices,
    required this.showingServices,
    required this.selectedCategory,
  });

  final int totalServices;
  final int showingServices;
  final String selectedCategory;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            icon: Icons.workspace_premium_outlined,
            label: 'Services',
            value: totalServices.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            icon: Icons.filter_alt_outlined,
            label: 'Showing',
            value: showingServices.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            icon: Icons.category_outlined,
            label: 'Category',
            value: selectedCategory,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.065),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryRed.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(icon, color: AppTheme.primaryRed, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1.0,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChipsRow extends StatelessWidget {
  const _StatusChipsRow({
    required this.counts,
    required this.selectedStatus,
    required this.onSelected,
  });

  final Map<_ServiceStatus, int> counts;
  final String selectedStatus;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('All Services', AppTheme.primaryRed, counts.values.fold<int>(0, (a, b) => a + b)),
      ('Open', Colors.blue, counts[_ServiceStatus.open] ?? 0),
      ('Under Review', Colors.green, counts[_ServiceStatus.underReview] ?? 0),
      ('Action Needed', Colors.orange, counts[_ServiceStatus.actionNeeded] ?? 0),
      ('Completed', Colors.purple, counts[_ServiceStatus.completed] ?? 0),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return _FilterPill(
            label: item.$1,
            count: item.$3,
            selected: selectedStatus == item.$1,
            selectedColor: item.$2,
            onTap: () => onSelected(item.$1),
          );
        },
      ),
    );
  }
}

class _CategoryChipsRow extends StatelessWidget {
  const _CategoryChipsRow({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          return _FilterPill(
            label: category,
            selected: selectedCategory == category,
            selectedColor: AppTheme.primaryRed,
            onTap: () => onSelected(category),
          );
        },
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: count == null ? 14 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? selectedColor
                  : Colors.black.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : selectedColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textPrimary,
                  fontSize: 13.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.1,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withValues(alpha: 0.18) : AppTheme.cardSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: selected ? Colors.white : AppTheme.textSecondary,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackMyServicesCard extends StatelessWidget {
  const _TrackMyServicesCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: AppTheme.primaryRed,
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track My Services',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'View active cases, missing documents and progress.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceDashboardCard extends StatelessWidget {
  const _ServiceDashboardCard({
    required this.service,
    required this.status,
    required this.onOpenDetails,
    required this.onRequest,
    required this.onWhatsApp,
  });

  final ServiceItem service;
  final _ServiceStatus status;
  final VoidCallback onOpenDetails;
  final VoidCallback onRequest;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final visibleRequirements = service.requirements.take(3).toList();
    final remainingRequirements =
        service.requirements.length - visibleRequirements.length;
    final wizardLabel = _wizardBadgeLabel(service);
    final statusLabel = _statusLabelFor(status);
    final statusColor = _statusColor(status);
    final progress = _statusProgress(status);
    final icon = _serviceIcon(service);

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      onTap: onOpenDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.primaryRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.05,
                      ),
                    ),
                    if (wizardLabel != null) ...[
                      const SizedBox(height: 7),
                      _WizardBadge(label: wizardLabel),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      service.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        height: 1.16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusPill(label: statusLabel, color: statusColor),
                  const SizedBox(height: 12),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary,
                    size: 28,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PremiumInfoChip(
                icon: Icons.payments_outlined,
                label: service.priceLabel,
              ),
              PremiumInfoChip(
                icon: Icons.schedule_rounded,
                label: service.completionTime,
              ),
            ],
          ),
          if (service.governmentFeeLabel != null &&
              service.governmentFeeLabel!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.account_balance_outlined,
                    color: AppTheme.primaryRed,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      service.governmentFeeLabel!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _ProgressStrip(value: progress, color: statusColor),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                'Progress',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (visibleRequirements.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Requirements',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            for (final requirement in visibleRequirements)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _RequirementRow(label: requirement),
              ),
            if (remainingRequirements > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+$remainingRequirements more',
                  style: const TextStyle(
                    color: AppTheme.primaryRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: wizardLabel == null ? 'Request' : 'Start wizard',
                  icon: wizardLabel == null
                      ? Icons.add_rounded
                      : Icons.auto_awesome_rounded,
                  onPressed: onRequest,
                  isExpanded: false,
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'WhatsApp support',
                onPressed: onWhatsApp,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
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

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({
    required this.value,
    required this.color,
  });

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 7,
        color: AppTheme.border.withValues(alpha: 0.85),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(color: color),
        ),
      ),
    );
  }
}

class _WizardBadge extends StatelessWidget {
  const _WizardBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: AppTheme.primaryRed,
            size: 13,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.primaryRed,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppTheme.primaryRed,
              size: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceListEmptyState extends StatelessWidget {
  const _ServiceListEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return PremiumEmptyState(
      icon: icon,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.items});

  final List<_ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _ActivityRow(item: items[index]),
            if (index != items.length - 1)
              Divider(height: 1, thickness: 1, color: AppTheme.border),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final _ActivityItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.3,
                    height: 1.32,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.timeLabel,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityItem {
  const _ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String timeLabel;
}

String _greetingLabel() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning,';
  if (hour < 17) return 'Good afternoon,';
  return 'Good evening,';
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'OM';
  if (parts.length == 1) {
    final first = parts.first;
    return first.isEmpty ? 'OM' : first.characters.first.toUpperCase();
  }
  final first = parts.first.characters.first.toUpperCase();
  final second = parts[1].characters.first.toUpperCase();
  return '$first$second';
}

IconData _serviceIcon(ServiceItem service) {
  final text = [service.id, service.title, service.category, service.wizardType ?? '']
      .join(' ')
      .toLowerCase();

  if (text.contains('tax') || text.contains('gst') || text.contains('ntn')) {
    return Icons.receipt_long_outlined;
  }
  if (text.contains('visa')) {
    return Icons.flight_takeoff_outlined;
  }
  if (text.contains('company') || text.contains('business')) {
    return Icons.apartment_outlined;
  }
  if (text.contains('document')) {
    return Icons.description_outlined;
  }
  if (text.contains('payment') || text.contains('invoice')) {
    return Icons.payments_outlined;
  }
  return Icons.workspace_premium_outlined;
}

String? _wizardBadgeLabel(ServiceItem service) {
  switch (_normalizedWizardType(service)) {
    case 'ntn':
      return 'NTN Wizard';
    case 'iris':
      return 'IRIS Wizard';
    case 'gst':
      return 'GST Wizard';
    case 'business':
      return 'Business Wizard';
    default:
      return null;
  }
}

String _normalizedWizardType(ServiceItem service) {
  return service.wizardType?.trim().toLowerCase() ?? '';
}

String _serviceCatalogueErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final message = error.toString().replaceFirst('ApiError:', '').trim();
  if (message.isNotEmpty) return message;

  return 'Service catalogue is unavailable right now. Please try again.';
}
