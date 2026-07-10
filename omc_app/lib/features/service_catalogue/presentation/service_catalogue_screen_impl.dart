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
const Color _border = Color(0xFFE5E7EB);
const Color _primary = Color(0xFF111827);
const Color _primarySoft = Color(0xFFF3F4F6);
const Color _review = Color(0xFF6D28D9);
const Color _attention = Color(0xFFF59E0B);
const Color _done = Color(0xFF16A34A);
const Color _teal = Color(0xFF0F9D8E);

class ServiceCatalogueScreen extends ConsumerStatefulWidget {
  const ServiceCatalogueScreen({super.key});

  @override
  ConsumerState<ServiceCatalogueScreen> createState() => _ServiceCatalogueScreenState();
}

class _ServiceCatalogueScreenState extends ConsumerState<ServiceCatalogueScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedCategory = 'All';

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
    final unreadNotifications = ref.watch(homeDashboardSummaryProvider).value?.unreadNotifications ?? 0;
    final displayName = serviceCatalogueDisplayName(authState);

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
          final categories = <String>['All', ...{
            for (final service in services)
              if (service.category.trim().isNotEmpty) service.category.trim(),
          }.toList()..sort()];
          final filtered = _filterServices(services);
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
                const SizedBox(height: 16),
                const Text(
                  'Services',
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
                        onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
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
                      onPressed: () => _openCategorySheet(context, categories),
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
                  selectedStatus: _selectedCategory == 'All' ? 'All Services' : _selectedCategory,
                  onSelected: (status) {
                    setState(() {
                      _selectedCategory = status == 'All Services' ? 'All' : _selectedCategory;
                    });
                  },
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
                      '(${filtered.length})',
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
                else if (filtered.isEmpty)
                  _ServiceListEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matching services',
                    message: 'Try another search term, status filter or category.',
                    actionLabel: 'Clear filters',
                    onAction: () {
                      _searchController.clear();
                      setState(() {
                        _query = '';
                        _selectedCategory = 'All';
                      });
                    },
                  )
                else
                  ...filtered.asMap().entries.map((entry) {
                    final index = entry.key;
                    final service = entry.value;
                    final status = serviceStatusForIndex(index);
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == filtered.length - 1 ? 0 : 14),
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

  List<ServiceItem> _filterServices(List<ServiceItem> services) {
    return services.where((service) {
      if (_selectedCategory != 'All' && service.category.trim() != _selectedCategory) {
        return false;
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
      final status = serviceStatusForIndex(i);
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  void _openCategorySheet(BuildContext context, List<String> categories) {
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
                'Narrow by category.',
                style: TextStyle(
                  color: _slate,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
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
                      _selectedCategory = 'All';
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
        _HeaderActionButton(icon: Icons.notifications_none_rounded, badgeCount: unreadCount, onTap: onNotificationsTap),
        const SizedBox(width: 10),
        _ProfileAvatar(name: displayName, onTap: onProfileTap),
      ],
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({required this.icon, required this.badgeCount, required this.onTap});

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
  const _ProfileAvatar({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return Material(
      color: _primary,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
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
    final banner = bannerFor(authState);
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
        _MetricCard(label: 'Total', value: totalServices.toString(), color: _primary),
        _MetricCard(label: 'Open', value: openServices.toString(), color: const Color(0xFF2563EB)),
        _MetricCard(label: 'Review', value: underReviewServices.toString(), color: _review),
        _MetricCard(label: 'Action', value: actionNeededServices.toString(), color: _attention),
        _MetricCard(label: 'Done', value: completedServices.toString(), color: _done),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.color});

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
            Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(color: _slate, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _StatusChipsRow extends StatelessWidget {
  const _StatusChipsRow({required this.counts, required this.selectedStatus, required this.onSelected});

  final Map<_ServiceStatus, int> counts;
  final String selectedStatus;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final statuses = <String>['All Services', ..._ServiceStatus.values.map(serviceCatalogueStatusLabelFor)];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = statuses[index];
          final selected = label == selectedStatus;
          final count = label == 'All Services' ? counts.values.fold<int>(0, (a, b) => a + b) : counts[_statusFromLabel(label)] ?? 0;
          return ChoiceChip(
            label: Text('$label ($count)'),
            selected: selected,
            onSelected: (_) => onSelected(label),
            labelStyle: TextStyle(color: selected ? Colors.white : _ink, fontWeight: FontWeight.w800),
            selectedColor: _primary,
            backgroundColor: Colors.white,
            side: BorderSide(color: selected ? _primary : AppTheme.border),
          );
        },
      ),
    );
  }
}

class _CategoryChipsRow extends StatelessWidget {
  const _CategoryChipsRow({required this.categories, required this.selectedCategory, required this.onSelected});

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == selectedCategory;
          return ChoiceChip(
            label: Text(category),
            selected: selected,
            onSelected: (_) => onSelected(category),
            labelStyle: TextStyle(color: selected ? Colors.white : _ink, fontWeight: FontWeight.w800),
            selectedColor: _primary,
            backgroundColor: Colors.white,
            side: BorderSide(color: selected ? _primary : AppTheme.border),
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
          Icon(Icons.track_changes_rounded, color: _teal),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Track my services',
              style: TextStyle(color: _ink, fontSize: 14.5, fontWeight: FontWeight.w800),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: _slate),
        ],
      ),
    );
  }
}

class _ServiceDashboardCard extends StatelessWidget {
  const _ServiceDashboardCard({required this.service, required this.status, required this.onTap, required this.onRequest, required this.onWhatsApp});

  final ServiceItem service;
  final _ServiceStatus status;
  final VoidCallback onTap;
  final VoidCallback onRequest;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final tone = serviceCatalogueTone(service);
    final statusLabel = serviceCatalogueStatusLabelFor(status);
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
                    Text(service.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(service.category, style: const TextStyle(color: _slate, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(label: statusLabel, color: serviceCatalogueStatusColor(status)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PremiumInfoChip(icon: Icons.payments_outlined, label: service.priceLabel, color: tone.color),
              PremiumInfoChip(icon: Icons.schedule_rounded, label: service.completionTime, color: _review),
              if (serviceCatalogueWizardBadgeLabel(service) != null)
                PremiumInfoChip(icon: Icons.auto_awesome_rounded, label: serviceCatalogueWizardBadgeLabel(service)!, color: _teal),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            service.shortDescription ?? service.description ?? 'OMC will share the service brief after review.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _slate, fontSize: 13, height: 1.45, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onRequest,
                  child: const Text('Start request'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
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

class _ServiceListEmptyState extends StatelessWidget {
  const _ServiceListEmptyState({required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});

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
          Text(title, style: const TextStyle(color: _ink, fontSize: 15.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _slate, fontSize: 13, height: 1.45, fontWeight: FontWeight.w600)),
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
  const _FilterPill({required this.label, required this.selected, required this.selectedColor, required this.onTap});

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: selectedColor,
      labelStyle: TextStyle(color: selected ? Colors.white : _ink, fontWeight: FontWeight.w800),
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? selectedColor : AppTheme.border),
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
      child: Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w900)),
    );
  }
}

class _ServiceStatusData {
  const _ServiceStatusData({required this.title, required this.message, required this.actionLabel, required this.background, required this.border, required this.iconBackground, required this.iconColor, required this.icon});

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

_ServiceStatus serviceStatusForIndex(int index) {
  if (index == 1) return _ServiceStatus.underReview;
  if (index == 2) return _ServiceStatus.actionNeeded;
  if (index >= 3) return _ServiceStatus.completed;
  return _ServiceStatus.open;
}

String serviceCatalogueStatusLabelFor(_ServiceStatus status) {
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

Color serviceCatalogueStatusColor(_ServiceStatus status) {
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

_Servic...