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
import '../../support/application/support_launcher.dart';
import '../application/service_catalogue_controller.dart';
import '../data/service_item.dart';

const Color _ink = Color(0xFF0F172A);
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
const Color _roseSoft = Color(0xFFFFF1F3);
const Color _roseBorder = Color(0xFFF6CDD6);

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
    final displayName = _safeDisplayName(authState);

    return SafeArea(
      child: servicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          final categories = <String>[_allCategory, ...categoryValues];
          final filteredServices = _filterServices(services);
          final statusCounts = _buildStatusCounts(services);
          final recentActivities = _buildActivities(services);

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              _ServicesHeroHeader(
                displayName: displayName,
                unreadCount: _canOpenNotifications(capabilities)
                    ? (recentActivities.isEmpty ? 0 : recentActivities.length)
                    : 0,
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
                onActionTap: () => context.go(_bannerRouteFor(authState)),
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
                    return;
                  }
                  _showLockedSnack(context, capabilities);
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
                  const SizedBox(width: 10),
                  const Text(
                    'Sort by: Recent',
                    style: TextStyle(
                      color: _slate,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: _slate),
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
                  final status = _serviceStatusFor(service, index);
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == filteredServices.length - 1 ? 0 : 14,
                    ),
                    child: _ServiceDashboardCard(
                      service: service,
                      status: status,
                      onTap: () => context.push('/services/${Uri.encodeComponent(service.id)}'),
                      onRequest: () {
                        if (capabilities.canCreateServiceRequest) {
                          context.push('/services/${Uri.encodeComponent(service.id)}/request');
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
                        color: _ink,
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
                      foregroundColor: _ink,
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
                        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                        foregroundColor: _ink,
                      ),
                      child: const Text('Clear all'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
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
    final filtered = <ServiceItem>[];
    for (var index = 0; index < services.length; index++) {
      final service = services[index];
      final matchesCategory =
          _selectedCategory == _allCategory || service.category == _selectedCategory;
      final serviceStatus = _serviceStatusFor(service, index);
      final matchesStatus = _selectedStatus == _allStatus ||
          _statusLabelFor(serviceStatus) == _selectedStatus;
      final searchableText = [
        service.title,
        service.category,
        service.priceLabel,
        service.completionTime,
        service.description ?? '',
        service.shortDescription ?? '',
        ...service.requirements,
      ].join(' ').toLowerCase();
      final matchesQuery = _query.isEmpty || searchableText.contains(_query);
      if (matchesCategory && matchesStatus && matchesQuery) {
        filtered.add(service);
      }
    }
    return filtered;
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

  List<_ActivityItem> _buildActivities(List<ServiceItem> services) {
    if (services.isEmpty) {
      return const [
        _ActivityItem(
          icon: Icons.history_rounded,
          color: _primary,
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
        color: _success,
        title: 'Payment receipt uploaded',
        subtitle: 'For ${first.title}',
        timeLabel: '2h ago',
      ),
      _ActivityItem(
        icon: Icons.description_outlined,
        color: _review,
        title: 'Document uploaded',
        subtitle: 'For ${second.title}',
        timeLabel: '5h ago',
      ),
      _ActivityItem(
        icon: Icons.person_pin_outlined,
        color: _attention,
        title: 'Request assigned',
        subtitle: 'For ${third.title} by the support team',
        timeLabel: '1d ago',
      ),
    ];
  }

  _ServiceStatus _serviceStatusFor(ServiceItem service, int index) {
    if (index == 1) return _ServiceStatus.underReview;
    if (index == 2) return _ServiceStatus.actionNeeded;
    if (index == 3) return _ServiceStatus.completed;
    if (index > 3) return _ServiceStatus.completed;
    return _ServiceStatus.open;
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

  Color _statusColor(_ServiceStatus status) {
    switch (status) {
      case _ServiceStatus.open:
        return _primary;
      case _ServiceStatus.underReview:
        return _review;
      case _ServiceStatus.actionNeeded:
        return _attention;
      case _ServiceStatus.completed:
        return _done;
    }
  }

  double _statusProgress(_ServiceStatus status, int seed) {
    switch (seed % 5) {
      case 0:
        return 0.45;
      case 1:
        return 0.65;
      case 2:
        return 0.20;
      case 3:
        return 0.80;
      default:
        return status == _ServiceStatus.completed ? 1.0 : 0.55;
    }
  }

  _ServiceTone _serviceTone(ServiceItem service) {
    final source = '${service.category} ${service.title} ${service.wizardType ?? ''}'.toLowerCase();

    if (source.contains('visa')) {
      return const _ServiceTone(icon: Icons.flight_takeoff_rounded, color: Color(0xFF0F9D8E));
    }
    if (source.contains('tax') || source.contains('ntn') || source.contains('gst')) {
      return const _ServiceTone(icon: Icons.receipt_long_outlined, color: Color(0xFF4F46E5));
    }
    if (source.contains('business') || source.contains('setup')) {
      return const _ServiceTone(icon: Icons.apartment_outlined, color: Color(0xFF7C3AED));
    }
    if (source.contains('document')) {
      return const _ServiceTone(icon: Icons.description_outlined, color: Color(0xFF6366F1));
    }
    if (source.contains('payment') || source.contains('receipt') || source.contains('invoice')) {
      return const _ServiceTone(icon: Icons.payments_outlined, color: Color(0xFF059669));
    }
    if (source.contains('hr') || source.contains('employee')) {
      return const _ServiceTone(icon: Icons.groups_rounded, color: Color(0xFF14B8A6));
    }
    if (source.contains('lead')) {
      return const _ServiceTone(icon: Icons.record_voice_over_rounded, color: Color(0xFF8B5CF6));
    }
    if (source.contains('task') || source.contains('todo')) {
      return const _ServiceTone(icon: Icons.task_alt_rounded, color: Color(0xFFF97316));
    }
    if (source.contains('support') || source.contains('case') || source.contains('request')) {
      return const _ServiceTone(icon: Icons.support_agent_rounded, color: Color(0xFF334155));
    }

    return const _ServiceTone(icon: Icons.workspace_premium_outlined, color: Color(0xFF334155));
  }

  String? _wizardBadgeLabel(ServiceItem service) {
    final raw = service.wizardType?.trim();
    if (raw == null || raw.isEmpty) {
      return service.hasBackendTemplate ? 'Service Wizard' : null;
    }
    switch (raw.toLowerCase()) {
      case 'tax':
        return 'Tax Wizard';
      case 'gst':
        return 'GST Wizard';
      case 'business':
        return 'Business Wizard';
      default:
        return '${_titleCase(raw)} Wizard';
    }
  }

  String _safeDisplayName(AuthState authState) {
    final displayName = authState.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final companyName = authState.companyName?.trim();
    if (companyName != null && companyName.isNotEmpty) return companyName;

    final userId = authState.userId?.trim();
    if (userId != null && userId.isNotEmpty) {
      final localPart = userId.contains('@') ? userId.split('@').first : userId;
      final pieces = localPart
          .split(RegExp(r'[._-]+'))
          .where((item) => item.trim().isNotEmpty)
          .map(_titleCase)
          .toList(growable: false);
      if (pieces.isNotEmpty) return pieces.join(' ');
      return localPart;
    }

    return authState.capabilities.isInternal ? 'Administrator' : 'My Services';
  }

  String _serviceCatalogueErrorMessage(Object error) {
    if (error is ApiError) return error.message;
    return 'Unable to load services right now. Please try again.';
  }

  String _titleCase(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}

enum _ServiceStatus { open, underReview, actionNeeded, completed }

class _ServiceTone {
  const _ServiceTone({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  Color get soft => color.withValues(alpha: 0.09);
  Color get border => color.withValues(alpha: 0.16);
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
                  color: _slate,
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
                  color: _ink,
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
            _AvatarButton(displayName: displayName, onTap: onProfileTap),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Icon(icon, color: _ink, size: 25),
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
                color: _primary,
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
  const _AvatarButton({required this.displayName, required this.onTap});

  final String displayName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            _initials(displayName),
            style: const TextStyle(
              color: _ink,
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
  const _StatusBanner({required this.authState, required this.onActionTap});

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
                    color: _ink,
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
                    color: _slate,
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
                  backgroundColor: _primary,
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
                    color: _slate,
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
      background: Color(0xFFF7F8FB),
      border: _border,
      iconBackground: _primarySoft,
      iconColor: _ink,
      icon: Icons.shield_outlined,
    );
  }

  if (authState.capabilities.isPending) {
    return const _StatusBannerData(
      title: 'Your profile is under review',
      message:
          'You have limited access. Complete your profile for full access to all services.',
      actionLabel: 'Complete Profile',
      background: Color(0xFFF7F8FB),
      border: _border,
      iconBackground: _primarySoft,
      iconColor: _ink,
      icon: Icons.verified_user_outlined,
    );
  }

  if (authState.capabilities.isRejected) {
    return const _StatusBannerData(
      title: 'Access restricted',
      message:
          'This account is not approved for service requests. Contact support to continue.',
      actionLabel: 'Contact Support',
      background: _roseSoft,
      border: _roseBorder,
      iconBackground: Color(0xFFFCE7EC),
      iconColor: Color(0xFFDB2777),
      icon: Icons.block_outlined,
    );
  }

  if (authState.capabilities.isInternal) {
    return const _StatusBannerData(
      title: 'Internal workspace connected',
      message:
          'Open review queues, service statuses and customer activity from one page.',
      actionLabel: 'Open Workspace',
      background: Color(0xFFF7F8FB),
      border: _border,
      iconBackground: _primarySoft,
      iconColor: _ink,
      icon: Icons.apartment_outlined,
    );
  }

  return const _StatusBannerData(
    title: 'Service dashboard ready',
    message:
        'Track requests, upload documents and review progress without leaving this page.',
    actionLabel: 'Open My Services',
    background: Color(0xFFF7F8FB),
    border: _border,
    iconBackground: _primarySoft,
    iconColor: _ink,
    icon: Icons.workspace_premium_outlined,
  );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.totalServices,
    required this.openServices,
    required this.underReviewServices,
    required this.actionNeededServices,
    required this.completedServices,
  });

  final int totalServices;
  final int openServices;
  final int underReviewServices;
  final int actionNeededServices;
  final int completedServices;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.3,
      children: [
        _SummaryTile(
          icon: Icons.folder_outlined,
          label: 'Services',
          value: totalServices.toString(),
          subtitle: 'Total',
          tint: _ink,
        ),
        _SummaryTile(
          icon: Icons.visibility_outlined,
          label: 'Open',
          value: openServices.toString(),
          subtitle: 'Active cases',
          tint: _primary,
        ),
        _SummaryTile(
          icon: Icons.schedule_outlined,
          label: 'Under Review',
          value: underReviewServices.toString(),
          subtitle: 'Awaiting review',
          tint: _review,
        ),
        _SummaryTile(
          icon: Icons.verified_outlined,
          label: 'Completed',
          value: completedServices.toString(),
          subtitle: 'This month',
          tint: _done,
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
    required this.subtitle,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tint.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: tint, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1.0,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _slate,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tint,
              fontSize: 10.5,
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
    final items = <({String label, Color color, int count})>[
      (
        label: 'All Services',
        color: _primary,
        count: counts.values.fold<int>(0, (a, b) => a + b),
      ),
      (label: 'Open', color: _primary, count: counts[_ServiceStatus.open] ?? 0),
      (label: 'Under Review', color: _review, count: counts[_ServiceStatus.underReview] ?? 0),
      (label: 'Action Needed', color: _attention, count: counts[_ServiceStatus.actionNeeded] ?? 0),
      (label: 'Completed', color: _done, count: counts[_ServiceStatus.completed] ?? 0),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return _FilterPill(
            label: item.label,
            count: item.count,
            selected: selectedStatus == item.label,
            selectedColor: item.color,
            onTap: () => onSelected(item.label),
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
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          return _FilterPill(
            label: category,
            selected: selectedCategory == category,
            selectedColor: _primary,
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
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: count == null ? 12 : 11, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? selectedColor.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? selectedColor.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: selected ? 0.04 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: selected ? selectedColor : selectedColor.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? selectedColor : _ink,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.08,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected ? selectedColor.withValues(alpha: 0.14) : AppTheme.cardSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: selected ? selectedColor : _slate,
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
              color: _primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.assignment_outlined, color: _ink, size: 23),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track My Services',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'View active cases, missing documents and progress.',
                  style: TextStyle(
                    color: _slate,
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
              color: _primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: _ink,
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
    required this.onTap,
    required this.onRequest,
    required this.onWhatsApp,
  });

  final ServiceItem service;
  final _ServiceStatus status;
  final VoidCallback onTap;
  final VoidCallback onRequest;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final visibleRequirements = service.requirements.take(3).toList();
    final remainingRequirements = service.requirements.length - visibleRequirements.length;
    final wizardLabel = _wizardBadgeLabel(service);
    final statusLabel = _statusLabelFor(status);
    final statusColor = _statusColor(status);
    final progress = _statusProgress(status, service.id.hashCode.abs());
    final tone = _serviceTone(service);
    final subtitle = (service.shortDescription ?? service.description ?? '').trim();

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: tone.soft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tone.border),
                ),
                child: Icon(tone.icon, color: tone.color, size: 24),
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
                      style: TextStyle(
                        color: tone.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.05,
                      ),
                    ),
                    if (wizardLabel != null) ...[
                      const SizedBox(height: 7),
                      _WizardBadge(label: wizardLabel, color: tone.color),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      service.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 18,
                        height: 1.16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
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
                    color: _slate,
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
                color: tone.color,
              ),
              PremiumInfoChip(
                icon: Icons.schedule_rounded,
                label: service.completionTime,
                color: _review,
              ),
            ],
          ),
          if (service.governmentFeeLabel != null && service.governmentFeeLabel!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: tone.color.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.account_balance_outlined, color: tone.color, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      service.governmentFeeLabel!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _slate,
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
              const Text(
                'Progress',
                style: TextStyle(
                  color: _slate,
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
                color: _ink,
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
                  color: tone.color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+$remainingRequirements more',
                  style: TextStyle(
                    color: tone.color,
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
                child: FilledButton.icon(
                  onPressed: onRequest,
                  icon: Icon(
                    wizardLabel == null ? Icons.add_rounded : Icons.auto_awesome_rounded,
                    size: 18,
                  ),
                  label: Text(wizardLabel == null ? 'Request' : 'Start wizard'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
        color: color.withValues(alpha: 0.10),
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
  const _ProgressStrip({required this.value, required this.color});

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
  const _WizardBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, color: color, size: 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
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
        color: _primary.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: _primary, size: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _slate,
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
                    color: _ink,
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
                    color: _slate,
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
                  color: _slate,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Icon(
                Icons.chevron_right_rounded,
                color: _slate,
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.filled,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      );
    }

    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: _primary),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          side: BorderSide(color: _primary.withValues(alpha: 0.14)),
          foregroundColor: _primary,
          backgroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ServiceTone {
  const _ServiceTone({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  Color get soft => color.withValues(alpha: 0.09);
  Color get border => color.withValues(alpha: 0.16);
}

String _initials(String value) {
  final cleaned = value.trim();
  if (cleaned.isEmpty) return 'A';
  final parts = cleaned.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) {
    final firstRune = cleaned.runes.isNotEmpty ? cleaned.runes.first : 65;
    return String.fromCharCode(firstRune).toUpperCase();
  }
  final buffer = StringBuffer();
  buffer.write(parts.first[0]);
  if (parts.length > 1) {
    buffer.write(parts.last[0]);
  }
  return buffer.toString().toUpperCase();
}
