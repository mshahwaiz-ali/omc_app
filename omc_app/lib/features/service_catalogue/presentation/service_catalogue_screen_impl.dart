import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../application/service_catalogue_controller.dart';
import '../data/service_item.dart';
import 'service_visual_registry.dart';

const Color _ink = AppTheme.textPrimary;
const Color _slate = AppTheme.textSecondary;
const Color _border = AppTheme.border;
const Color _primary = AppTheme.primary;

class ServiceCatalogueScreen extends ConsumerStatefulWidget {
  const ServiceCatalogueScreen({
    this.initialQuery = '',
    this.assisted = false,
    this.customerProfile,
    this.customerName,
    super.key,
  });

  final String initialQuery;
  final bool assisted;
  final String? customerProfile;
  final String? customerName;

  @override
  ConsumerState<ServiceCatalogueScreen> createState() =>
      _ServiceCatalogueScreenState();
}

class _ServiceCatalogueScreenState
    extends ConsumerState<ServiceCatalogueScreen> {
  static const String _allCategory = 'All';

  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = _allCategory;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final initialQuery = widget.initialQuery.trim();
    _query = initialQuery.toLowerCase();
    _searchController.text = initialQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(serviceCatalogueProvider);
    ref.watch(authControllerProvider);

    return SafeArea(
      key: OmcWidgetKeys.servicesScreen,
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
          final categories = <String>[
            _allCategory,
            ...{
              for (final service in services)
                if (service.category.trim().isNotEmpty) service.category.trim(),
            }.toList()..sort(),
          ];
          final filteredServices = _filterServices(services);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(serviceCatalogueProvider);
              await ref.read(serviceCatalogueProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 122),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                const _PageHeading(),
                const SizedBox(height: 12),
                _SearchField(
                  controller: _searchController,
                  query: _query,
                  hasActiveCategory: _selectedCategory != _allCategory,
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  onFilterTap: () => _openFilterSheet(context, categories),
                ),
                const SizedBox(height: 10),
                _CategoryStrip(
                  categories: categories,
                  selectedCategory: _selectedCategory,
                  onSelected: (category) =>
                      setState(() => _selectedCategory = category),
                ),
                const SizedBox(height: 14),
                _SectionHeader(
                  resultCount: filteredServices.length,
                  isFiltered:
                      _query.isNotEmpty || _selectedCategory != _allCategory,
                ),
                const SizedBox(height: 9),
                if (services.isEmpty)
                  const _ServiceListEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No services available',
                    message:
                        'OMC has not published any mobile services yet. Please check again later.',
                  )
                else if (filteredServices.isEmpty)
                  _ServiceListEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matching services',
                    message:
                        'Try another search term or select a different category.',
                    actionLabel: 'Clear filters',
                    onAction: _clearFilters,
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount = width >= 900
                          ? 6
                          : width >= 650
                          ? 5
                          : width >= 480
                          ? 4
                          : 3;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredServices.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: 114,
                        ),
                        itemBuilder: (context, index) {
                          final service = filteredServices[index];

                          return _ServiceIconTile(
                            service: service,
                            onOpen: () => _openService(service),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<ServiceItem> _filterServices(List<ServiceItem> services) {
    return services
        .where((service) {
          if (_selectedCategory != _allCategory &&
              service.category.trim() != _selectedCategory) {
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
          ].join(' ').toLowerCase();

          return haystack.contains(_query);
        })
        .toList(growable: false);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _selectedCategory = _allCategory;
    });
  }

  void _openService(ServiceItem service) {
    final base = '/services/${Uri.encodeComponent(service.id)}';

    if (!widget.assisted) {
      context.push(base);
      return;
    }

    final path =
        '$base'
        '?assisted=1'
        '&customer_profile=${Uri.encodeQueryComponent(widget.customerProfile ?? '')}'
        '&customer_name=${Uri.encodeQueryComponent(widget.customerName ?? '')}';

    context.push(path);
  }

  void _openFilterSheet(BuildContext context, List<String> categories) {
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
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
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
              const SizedBox(height: 5),
              const Text(
                'Choose a service category.',
                style: TextStyle(
                  color: _slate,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      for (final category in categories)
                        _FilterPill(
                          label: category == _allCategory
                              ? 'All services'
                              : _displayCategoryLabel(category),
                          selected: _selectedCategory == category,
                          onTap: () {
                            setState(() => _selectedCategory = category);
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                    ],
                  ),
                ),
              ),
              if (_selectedCategory != _allCategory) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _selectedCategory = _allCategory);
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Clear category filter'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Services',
          style: TextStyle(
            color: _ink,
            fontSize: 27,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.55,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Find the right service for your business.',
          style: TextStyle(
            color: _slate,
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.query,
    required this.hasActiveCategory,
    required this.onChanged,
    required this.onClear,
    required this.onFilterTap,
  });

  final TextEditingController controller;
  final String query;
  final bool hasActiveCategory;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search services',
        prefixIcon: const Icon(Icons.search_rounded, size: 21),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (query.isNotEmpty)
              IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 19),
              ),
            IconButton(
              tooltip: 'Filter services',
              onPressed: onFilterTap,
              visualDensity: VisualDensity.compact,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: hasActiveCategory ? AppTheme.primary : _slate,
                  ),
                  if (hasActiveCategory)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primary, width: 1.4),
        ),
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
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
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final category = categories[index];

          return _ServiceFilterChip(
            label: category == 'All'
                ? 'All services'
                : _displayCategoryLabel(category),
            selected: selectedCategory == category,
            onTap: () => onSelected(category),
          );
        },
      ),
    );
  }
}

class _ServiceFilterChip extends StatelessWidget {
  const _ServiceFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(11);

    return Material(
      color: selected ? AppTheme.primary.withValues(alpha: 0.10) : Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          alignment: Alignment.center,
          constraints: BoxConstraints(minHeight: compact ? 34 : 40),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 11 : 14,
            vertical: compact ? 7 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.32)
                  : _border,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? AppTheme.primary : const Color(0xFF686D76),
              fontSize: compact ? 11 : 11.5,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.resultCount, required this.isFiltered});

  final int resultCount;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final countLabel = resultCount == 1
        ? '1 ${isFiltered ? 'result' : 'service'}'
        : '$resultCount ${isFiltered ? 'results' : 'services'}';

    return Row(
      children: [
        const Expanded(
          child: Text(
            'Available services',
            style: TextStyle(
              color: _ink,
              fontSize: 16.5,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.15,
            ),
          ),
        ),
        Text(
          countLabel,
          style: const TextStyle(
            color: _slate,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ServiceIconTile extends StatelessWidget {
  const _ServiceIconTile({required this.service, required this.onOpen});

  final ServiceItem service;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final visual = serviceVisualFor(service);

    return Semantics(
      button: true,
      label: service.title,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          splashColor: visual.color.withValues(alpha: 0.07),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: visual.color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: visual.color.withValues(alpha: 0.16),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(visual.icon, color: visual.color, size: 30),
                ),
                const SizedBox(height: 7),
                Text(
                  service.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12.25,
                    height: 1.18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: _slate),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _slate,
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
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
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ServiceFilterChip(
      label: label,
      selected: selected,
      onTap: onTap,
      compact: false,
    );
  }
}

String _displayCategoryLabel(String value) {
  if (value == 'All') return value;
  return _titleCase(value.replaceAll('_', ' ').replaceAll('-', ' '));
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

String _titleCase(String value) {
  return value
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}
