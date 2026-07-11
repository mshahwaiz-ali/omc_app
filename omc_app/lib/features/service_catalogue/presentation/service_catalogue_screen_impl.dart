import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../profile/data/profile_repository.dart';
import '../../support/application/support_launcher.dart';
import '../application/service_catalogue_controller.dart';
import '../data/service_item.dart';

const Color _ink = Color(0xFF111827);
const Color _slate = Color(0xFF64748B);
const Color _surface = Color(0xFFF8FAFC);
const Color _border = Color(0xFFE5E7EB);
const Color _primary = Color(0xFF111827);
const Color _primarySoft = Color(0xFFF3F4F6);
const Color _success = Color(0xFF0F9D8E);
const Color _review = Color(0xFF0F9F8F);
const Color _attention = Color(0xFFF59E0B);
const Color _done = Color(0xFF16A34A);
const Color _servicesRose = Color(0xFFE11D48);
const Color _roseSoft = Color(0xFFFFF1F3);
const Color _roseBorder = Color(0xFFF6CDD6);

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
          final categories = <String>{
            for (final service in services)
              if (service.category.trim().isNotEmpty) service.category.trim(),
          }.toList()..sort();

          final filteredServices = _filterServices(services);
          final statusCounts = _buildStatusCounts(services);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(serviceCatalogueProvider);
              ref.invalidate(profileSummaryProvider);
              await ref.read(profileSummaryProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                const Text(
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
                const SizedBox(height: 7),
                const Text(
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
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
                            borderSide: const BorderSide(
                              color: _primary,
                              width: 1.2,
                            ),
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
                  underReviewServices:
                      statusCounts[_ServiceStatus.underReview] ?? 0,
                  actionNeededServices:
                      statusCounts[_ServiceStatus.actionNeeded] ?? 0,
                  completedServices:
                      statusCounts[_ServiceStatus.completed] ?? 0,
                ),
                const SizedBox(height: 14),
                _StatusChipsRow(
                  counts: statusCounts,
                  selectedStatus: _selectedStatus,
                  onSelected: (status) =>
                      setState(() => _selectedStatus = status),
                ),
                const SizedBox(height: 12),
                _CategoryChipsRow(
                  categories: categories,
                  selectedCategory: _selectedCategory,
                  onSelected: (category) =>
                      setState(() => _selectedCategory = category),
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
                    message:
                        'OMC has not published mobile services from the backend yet. Please retry after services are configured or contact support.',
                  )
                else if (filteredServices.isEmpty)
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
                  ...filteredServices.asMap().entries.map((entry) {
                    final index = entry.key;
                    final service = entry.value;
                    final status = _serviceStatusForIndex(index);
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == filteredServices.length - 1 ? 0 : 14,
                      ),
                      child: _ServiceDashboardCard(
                        service: service,
                        status: status,
                        onTap: () => context.push(
                          '/services/${Uri.encodeComponent(service.id)}',
                        ),
                        requestLabel: _requestLabelFor(capabilities),
                        onRequest: () {
                          if (capabilities.canCreateServiceRequest) {
                            context.push(
                              '/services/${Uri.encodeComponent(service.id)}/request',
                            );
                          } else if (capabilities.isGuest) {
                            context.push('/signup');
                          } else if (capabilities.isPending) {
                            context.go('/under-review');
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
                      selectedColor: _statusFilterColor(status),
                      icon: _statusFilterIcon(status),
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
                      label: _displayCategoryLabel(category),
                      selected: _selectedCategory == category,
                      selectedColor: _servicesRose,
                      icon: category == _allCategory
                          ? Icons.apps_rounded
                          : Icons.category_outlined,
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
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    setState(() {
                      _selectedCategory = _allCategory;
                      _selectedStatus = _allStatus;
                    });
                    _searchController.clear();
                    _query = '';
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
    return services
        .asMap()
        .entries
        .where((entry) {
          final index = entry.key;
          final service = entry.value;

          if (_selectedCategory != _allCategory &&
              service.category.trim() != _selectedCategory) {
            return false;
          }

          final status = _serviceStatusForIndex(index);
          if (_selectedStatus != _allStatus &&
              _serviceCatalogueStatusLabelFor(status) != _selectedStatus) {
            return false;
          }

          if (_query.isEmpty) return true;

          final haystack = [
            service.id,
            service.title,
            service.category,
            service.description ?? '',
            service.shortDescription ?? '',
            service.feeLabel,
            service.priceLabel,
            service.completionTime,
            service.wizardType ?? '',
          ].join(' ').toLowerCase();

          return haystack.contains(_query);
        })
        .map((entry) => entry.value)
        .toList(growable: false);
  }

  Map<_ServiceStatus, int> _buildStatusCounts(List<ServiceItem> services) {
    final counts = <_ServiceStatus, int>{
      _ServiceStatus.open: 0,
      _ServiceStatus.underReview: 0,
      _ServiceStatus.actionNeeded: 0,
      _ServiceStatus.completed: 0,
    };

    for (var i = 0; i < services.length; i++) {
      final status = _serviceStatusForIndex(i);
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
  }

  void _showLockedSnack(BuildContext context, AuthCapabilities capabilities) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(lockedAccessMessage(capabilities)),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
    super.key,
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _ink,
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

// Retained while older catalogue layouts are migrated to OmcIdentityHeader.
// ignore: unused_element
class _Header extends StatelessWidget {
  const _Header({
    required this.displayName,
    required this.avatarUrl,
    required this.unreadCount,
    required this.authState,
    required this.onNotificationsTap,
    required this.onProfileTap,
  });

  final String displayName;
  final String? avatarUrl;
  final int unreadCount;
  final AuthState authState;
  final VoidCallback onNotificationsTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Good day,',
                style: TextStyle(
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
          avatarUrl: avatarUrl,
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
                color: _attention,
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.name,
    required this.avatarUrl,
    required this.onTap,
  });

  final String name;
  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final cleanAvatarUrl = avatarUrl?.trim();
    final imageUrl = cleanAvatarUrl == null || cleanAvatarUrl.isEmpty
        ? null
        : ApiConfig.resolveFileUrl(cleanAvatarUrl);
    final color = _avatarColor(name);
    return Material(
      color: imageUrl == null ? color.withValues(alpha: 0.12) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.16)),
          ),
          child: imageUrl == null
              ? Text(
                  initials,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : Image.network(
                  imageUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Text(
                    initials,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

Color _avatarColor(String name) {
  const colors = [
    _servicesRose,
    Color(0xFF3B6DF6),
    _success,
    _review,
    _attention,
  ];
  final source = name.trim().isEmpty ? 'OMC' : name.trim();
  final index =
      source.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % colors.length;
  return colors[index];
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.authState, required this.onActionTap});

  final AuthState authState;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    final banner = _bannerFor(authState);
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: banner.iconBackground,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(banner.icon, color: banner.iconColor, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  banner.title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  banner.message,
                  style: const TextStyle(
                    color: _slate,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onActionTap,
                  child: Text(banner.actionLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MetricCard(
          label: 'Total',
          value: totalServices.toString(),
          color: _primary,
        ),
        _MetricCard(
          label: 'Open',
          value: openServices.toString(),
          color: const Color(0xFF2563EB),
        ),
        _MetricCard(
          label: 'Review',
          value: underReviewServices.toString(),
          color: _review,
        ),
        _MetricCard(
          label: 'Action',
          value: actionNeededServices.toString(),
          color: _attention,
        ),
        _MetricCard(
          label: 'Done',
          value: completedServices.toString(),
          color: _done,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 20 * 2 - 10) / 2,
      child: PremiumCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: _slate,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
    final statuses = <String>[
      'All Services',
      ..._ServiceStatus.values.map(_serviceCatalogueStatusLabelFor),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        separatorBuilder: (context, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = statuses[index];
          final selected = label == selectedStatus;
          final count = label == 'All Services'
              ? counts.values.fold<int>(0, (a, b) => a + b)
              : counts[_statusFromLabel(label)] ?? 0;
          final color = _statusFilterColor(label);
          return ChoiceChip(
            avatar: Icon(
              _statusFilterIcon(label),
              size: 16,
              color: selected ? color : _slate,
            ),
            label: Text('$label ($count)'),
            selected: selected,
            onSelected: (_) => onSelected(label),
            labelStyle: TextStyle(
              color: selected ? color : _ink,
              fontWeight: FontWeight.w800,
            ),
            selectedColor: color.withValues(alpha: 0.10),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? color.withValues(alpha: 0.30) : AppTheme.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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
    final items = <String>['All', ...categories.where((item) => item != 'All')];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = items[index];
          final selected = category == selectedCategory;
          return ChoiceChip(
            avatar: Icon(
              category == 'All' ? Icons.apps_rounded : Icons.category_outlined,
              size: 16,
              color: selected ? _servicesRose : _slate,
            ),
            label: Text(_displayCategoryLabel(category)),
            selected: selected,
            onSelected: (_) => onSelected(category),
            labelStyle: TextStyle(
              color: selected ? _servicesRose : _ink,
              fontWeight: FontWeight.w800,
            ),
            selectedColor: _roseSoft,
            backgroundColor: Colors.white,
            side: BorderSide(color: selected ? _roseBorder : AppTheme.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          );
        },
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
        children: const [
          Icon(Icons.track_changes_rounded, color: _success),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Track my services',
              style: TextStyle(
                color: _ink,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: _slate),
        ],
      ),
    );
  }
}

class _ServiceDashboardCard extends StatelessWidget {
  const _ServiceDashboardCard({
    required this.service,
    required this.status,
    required this.requestLabel,
    required this.onTap,
    required this.onRequest,
    required this.onWhatsApp,
  });

  final ServiceItem service;
  final _ServiceStatus status;
  final String requestLabel;
  final VoidCallback onTap;
  final VoidCallback onRequest;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final tone = _serviceCatalogueTone(service);
    final statusLabel = _serviceCatalogueStatusLabelFor(status);
    final wizardLabel = serviceCatalogueWizardBadgeLabel(service);

    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tone.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(tone.icon, color: tone.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      service.category,
                      style: const TextStyle(
                        color: _slate,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(
                label: statusLabel,
                color: _serviceCatalogueStatusColor(status),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
              if (wizardLabel != null)
                PremiumInfoChip(
                  icon: Icons.auto_awesome_rounded,
                  label: wizardLabel,
                  color: _success,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            service.shortDescription ??
                service.description ??
                'OMC will share the service brief after review.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _slate,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onRequest,
                  child: Text(requestLabel),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: onWhatsApp,
                style: IconButton.styleFrom(
                  backgroundColor: _primary.withValues(alpha: 0.08),
                  foregroundColor: _primary,
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.support_agent_rounded),
              ),
            ],
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
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Icon(icon, size: 28, color: _primary),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _slate,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
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
    this.icon,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: icon == null
          ? null
          : Icon(icon, size: 16, color: selected ? selectedColor : _slate),
      label: Text(label),
      selected: selected,
      selectedColor: selectedColor.withValues(alpha: 0.10),
      labelStyle: TextStyle(
        color: selected ? selectedColor : _ink,
        fontWeight: FontWeight.w800,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected
            ? selectedColor.withValues(alpha: 0.30)
            : AppTheme.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (_) => onTap(),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
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

class _BannerData {
  const _BannerData({
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

enum _ServiceStatus { open, underReview, actionNeeded, completed }

_BannerData _bannerFor(AuthState authState) {
  if (authState.capabilities.isGuest) {
    return const _BannerData(
      title: 'Guest access',
      message:
          'Create an account to request services, track progress and receive updates.',
      actionLabel: 'Sign up',
      background: _surface,
      border: _border,
      iconBackground: _primarySoft,
      iconColor: _primary,
      icon: Icons.person_add_alt_1_rounded,
    );
  }
  if (authState.capabilities.isPending) {
    return const _BannerData(
      title: 'Profile under review',
      message:
          'Your account is being verified. Service access unlocks after approval.',
      actionLabel: 'View profile',
      background: Color(0xFFEEF2FF),
      border: Color(0xFFD6DBFF),
      iconBackground: Color(0xFFE0E7FF),
      iconColor: Color(0xFF4338CA),
      icon: Icons.hourglass_bottom_rounded,
    );
  }
  if (authState.capabilities.isRejected) {
    return const _BannerData(
      title: 'Access restricted',
      message:
          'This account is not approved for service access. Contact OMC support.',
      actionLabel: 'Support',
      background: _roseSoft,
      border: _roseBorder,
      iconBackground: Color(0xFFFFD8E0),
      iconColor: Color(0xFFBE123C),
      icon: Icons.block_rounded,
    );
  }
  if (authState.capabilities.isInternal) {
    return const _BannerData(
      title: 'Internal workspace',
      message:
          'Track requests, review documents and handle service operations.',
      actionLabel: 'Open workspace',
      background: _surface,
      border: _border,
      iconBackground: _primarySoft,
      iconColor: _primary,
      icon: Icons.admin_panel_settings_outlined,
    );
  }
  return const _BannerData(
    title: 'Service dashboard ready',
    message:
        'Track requests, upload documents and review progress without leaving this page.',
    actionLabel: 'Open My Services',
    background: _surface,
    border: _border,
    iconBackground: _primarySoft,
    iconColor: _primary,
    icon: Icons.workspace_premium_outlined,
  );
}

String bannerRouteFor(AuthState authState) {
  if (authState.capabilities.isGuest) return '/signup';
  if (authState.capabilities.isPending) return '/profile';
  if (authState.capabilities.isRejected) return '/support';
  if (authState.capabilities.isInternal) return '/internal-workspace';
  return '/my-services';
}

String lockedAccessMessage(AuthCapabilities capabilities) {
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

String _requestLabelFor(AuthCapabilities capabilities) {
  if (capabilities.canCreateServiceRequest) return 'Start request';
  if (capabilities.isGuest) return 'Sign up';
  if (capabilities.isPending) return 'View status';
  return 'Locked';
}

bool _canTrackServices(AuthCapabilities capabilities) {
  return capabilities.canTrackRequests ||
      capabilities.canViewCustomerDashboard ||
      capabilities.canAccessCustomerDashboard ||
      capabilities.isApproved ||
      capabilities.canAccessInternalWorkspace;
}

String greetingLabel() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning,';
  if (hour < 17) return 'Good afternoon,';
  return 'Good evening,';
}

String initials(String value) {
  final cleaned = value.trim();
  if (cleaned.isEmpty) return 'A';
  final parts = cleaned
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    final firstRune = cleaned.runes.isNotEmpty ? cleaned.runes.first : 65;
    return String.fromCharCode(firstRune).toUpperCase();
  }
  final buffer = StringBuffer();
  buffer.write(parts.first[0]);
  if (parts.length > 1) buffer.write(parts.last[0]);
  return buffer.toString().toUpperCase();
}

String serviceCatalogueDisplayName(AuthState authState) {
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

String _initials(String value) {
  final cleaned = value.trim();
  if (cleaned.isEmpty) return 'A';

  final parts = cleaned
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    final firstRune = cleaned.runes.isNotEmpty ? cleaned.runes.first : 65;
    return String.fromCharCode(firstRune).toUpperCase();
  }

  final buffer = StringBuffer();
  buffer.write(parts.first[0]);
  if (parts.length > 1) buffer.write(parts.last[0]);
  return buffer.toString().toUpperCase();
}

String serviceCatalogueErrorMessage(Object error) {
  final message = error.toString();
  if (message.contains('SocketException')) {
    return 'Check your connection and try again.';
  }
  if (message.contains('404')) {
    return 'The catalogue endpoint was not found.';
  }
  if (message.contains('500')) {
    return 'The server returned an error while loading services.';
  }
  return 'Unable to load the service catalogue right now.';
}

_ServiceStatus _serviceStatusForIndex(int index) {
  if (index == 1) return _ServiceStatus.underReview;
  if (index == 2) return _ServiceStatus.actionNeeded;
  if (index >= 3) return _ServiceStatus.completed;
  return _ServiceStatus.open;
}

Color _statusFilterColor(String label) {
  if (label == 'All Services') return const Color(0xFF2563EB);
  return _serviceCatalogueStatusColor(_statusFromLabel(label));
}

IconData _statusFilterIcon(String label) {
  if (label == 'All Services') return Icons.layers_outlined;
  switch (_statusFromLabel(label)) {
    case _ServiceStatus.open:
      return Icons.radio_button_checked_rounded;
    case _ServiceStatus.underReview:
      return Icons.fact_check_outlined;
    case _ServiceStatus.actionNeeded:
      return Icons.priority_high_rounded;
    case _ServiceStatus.completed:
      return Icons.check_circle_outline_rounded;
  }
}

String _displayCategoryLabel(String value) {
  if (value == 'All') return value;
  return _titleCase(value.replaceAll('_', ' ').replaceAll('-', ' '));
}

_ServiceStatus _statusFromLabel(String label) {
  switch (label.toLowerCase()) {
    case 'open':
      return _ServiceStatus.open;
    case 'under review':
      return _ServiceStatus.underReview;
    case 'action needed':
      return _ServiceStatus.actionNeeded;
    case 'completed':
      return _ServiceStatus.completed;
    default:
      return _ServiceStatus.open;
  }
}

String _serviceCatalogueStatusLabelFor(_ServiceStatus status) {
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

Color _serviceCatalogueStatusColor(_ServiceStatus status) {
  switch (status) {
    case _ServiceStatus.open:
      return const Color(0xFF2563EB);
    case _ServiceStatus.underReview:
      return _review;
    case _ServiceStatus.actionNeeded:
      return _attention;
    case _ServiceStatus.completed:
      return _done;
  }
}

_ServiceTone _serviceCatalogueTone(ServiceItem service) {
  final source =
      '${service.category} ${service.title} ${service.wizardType ?? ''}'
          .toLowerCase();
  if (source.contains('visa')) {
    return const _ServiceTone(
      icon: Icons.flight_takeoff_rounded,
      color: Color(0xFF0F766E),
    );
  }
  if (source.contains('tax') ||
      source.contains('ntn') ||
      source.contains('gst')) {
    return const _ServiceTone(
      icon: Icons.receipt_long_outlined,
      color: Color(0xFF8B5CF6),
    );
  }
  if (source.contains('business') || source.contains('setup')) {
    return const _ServiceTone(
      icon: Icons.apartment_outlined,
      color: Color(0xFFDB2777),
    );
  }
  if (source.contains('document')) {
    return const _ServiceTone(
      icon: Icons.description_outlined,
      color: Color(0xFF0F9D8E),
    );
  }
  if (source.contains('payment') ||
      source.contains('receipt') ||
      source.contains('invoice')) {
    return const _ServiceTone(
      icon: Icons.payments_outlined,
      color: Color(0xFFF97316),
    );
  }
  if (source.contains('hr') || source.contains('employee')) {
    return const _ServiceTone(
      icon: Icons.groups_rounded,
      color: Color(0xFF14B8A6),
    );
  }
  if (source.contains('lead')) {
    return const _ServiceTone(
      icon: Icons.record_voice_over_rounded,
      color: Color(0xFF7C3AED),
    );
  }
  if (source.contains('task') || source.contains('todo')) {
    return const _ServiceTone(
      icon: Icons.task_alt_rounded,
      color: Color(0xFFF59E0B),
    );
  }
  if (source.contains('support') ||
      source.contains('case') ||
      source.contains('request')) {
    return const _ServiceTone(
      icon: Icons.support_agent_rounded,
      color: Color(0xFF334155),
    );
  }
  return const _ServiceTone(
    icon: Icons.workspace_premium_outlined,
    color: _ink,
  );
}

String? serviceCatalogueWizardBadgeLabel(ServiceItem service) {
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

String _titleCase(String value) {
  return value
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}

class _ServiceTone {
  const _ServiceTone({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}
