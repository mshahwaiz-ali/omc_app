import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
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
  static const int _pageSize = 50;

  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = _allCategory;
  String _query = '';
  int _start = 0;
  Timer? _debounce;

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _query = value.trim();
          _start = 0;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final initialQuery = widget.initialQuery.trim();
    _query = initialQuery.toLowerCase();
    _searchController.text = initialQuery;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageProvider = serviceCataloguePageProvider((
      start: _start,
      search: _query,
      category: _selectedCategory == _allCategory ? '' : _selectedCategory,
    ));
    final pageAsync = ref.watch(pageProvider);
    final servicesAsync = pageAsync.whenData((page) => page.items);
    ref.watch(authControllerProvider);

    return SafeArea(
      key: OmcWidgetKeys.servicesScreen,
      child: servicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: PremiumEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Services unavailable',
            message: serviceCatalogueErrorMessage(error),
            actionLabel: _query.isNotEmpty || _selectedCategory != _allCategory
                ? 'Clear filters'
                : 'Retry',
            onAction: () {
              if (_query.isNotEmpty || _selectedCategory != _allCategory) {
                _clearFilters();
              } else {
                ref.invalidate(pageProvider);
              }
            },
          ),
        ),
        data: (services) {
          final categories = <String>[
            _allCategory,
            ...{
              if (_selectedCategory != _allCategory) _selectedCategory,
              for (final service in services)
                if (service.category.trim().isNotEmpty) service.category.trim(),
            }.toList()..sort(),
          ];
          final filteredServices = services;
          final screenWidth = MediaQuery.sizeOf(context).width;
          final pageInset = AppLayout.pageInsetFor(screenWidth);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(pageProvider);
              await ref.read(pageProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                pageInset,
                AppSpacing.md,
                pageInset,
                122,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                const _PageHeading(),
                if (widget.assisted) ...[
                  const SizedBox(height: AppSpacing.md),
                  _AssistedContextBanner(customerName: widget.customerName),
                ],
                const SizedBox(height: AppSpacing.xl),
                _SearchField(
                  controller: _searchController,
                  query: _query,
                  hasActiveCategory: _selectedCategory != _allCategory,
                  onChanged: _search,
                  onClear: () {
                    _searchController.clear();
                    _search('');
                  },
                  onFilterTap: () => _openFilterSheet(context, categories),
                ),
                const SizedBox(height: AppSpacing.sm),
                _CategoryStrip(
                  categories: categories,
                  selectedCategory: _selectedCategory,
                  onSelected: (category) => setState(() {
                    _selectedCategory = category;
                    _start = 0;
                  }),
                ),
                const SizedBox(height: AppSpacing.xl),
                _SectionHeader(
                  resultCount: filteredServices.length,
                  isFiltered:
                      _query.isNotEmpty || _selectedCategory != _allCategory,
                ),
                const SizedBox(height: AppSpacing.sm),
                _Pager(
                  page: _start ~/ _pageSize + 1,
                  canGoPrevious: _start > 0,
                  canGoNext: pageAsync.value?.nextStart != null,
                  onPrevious: () => setState(
                    () => _start = (_start - _pageSize).clamp(0, _start),
                  ),
                  onNext: () => setState(
                    () => _start = pageAsync.value!.nextStart!,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (services.isEmpty &&
                    _query.isEmpty &&
                    _selectedCategory == _allCategory)
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
                  _ServiceResults(
                    services: filteredServices,
                    onOpen: _openService,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _clearFilters() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _query = '';
      _start = 0;
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
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.90,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Filter services',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Choose a service category.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final category in categories)
                      _FilterPill(
                        label: category == _allCategory
                            ? 'All services'
                            : _displayCategoryLabel(category),
                        selected: _selectedCategory == category,
                        onTap: () {
                          setState(() {
                            _selectedCategory = category;
                            _start = 0;
                          });
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                  ],
                ),
                if (_selectedCategory != _allCategory) ...[
                  const SizedBox(height: AppSpacing.xl),
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Services',
            style: theme.textTheme.headlineMedium?.copyWith(color: _ink),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Find the right service for your business.',
          style: theme.textTheme.bodyMedium?.copyWith(color: _slate),
        ),
      ],
    );
  }
}

class _AssistedContextBanner extends StatelessWidget {
  const _AssistedContextBanner({this.customerName});

  final String? customerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = customerName?.trim();
    final identity = name == null || name.isEmpty ? 'Selected customer' : name;

    return Semantics(
      container: true,
      label: 'Assisted service selection for $identity',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppTheme.infoSoft,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppTheme.info.withValues(alpha: 0.20)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.person_search_outlined,
              color: AppTheme.info,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assisted service selection',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.info,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    identity,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: 'Search services',
        prefixIcon: const Icon(Icons.search_rounded, size: 24),
        suffixIconConstraints: const BoxConstraints(minHeight: 56),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (query.isNotEmpty)
              IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 24),
              ),
            IconButton(
              tooltip: hasActiveCategory
                  ? 'Filter services, category filter active'
                  : 'Filter services',
              onPressed: onFilterTap,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 24,
                    color: hasActiveCategory
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  if (hasActiveCategory)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onPrimaryContainer,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final stripHeight = textScale >= 1.5 ? 64.0 : AppTouchTarget.minimum;

    return SizedBox(
      height: stripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadius.pill);
    final foreground = selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppTouchTarget.minimum),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? foreground.withValues(alpha: 0.32)
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check_rounded, size: 18, color: foreground),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w500,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.resultCount, required this.isFiltered});

  final int resultCount;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countLabel = resultCount == 1
        ? '1 ${isFiltered ? 'result' : 'service'}'
        : '$resultCount ${isFiltered ? 'results' : 'services'}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stacked = constraints.maxWidth < 320 || textScale >= 1.5;
        final title = Semantics(
          header: true,
          child: Text(
            'Available services',
            style: theme.textTheme.titleLarge?.copyWith(color: _ink),
          ),
        );
        final count = Text(
          countLabel,
          style: theme.textTheme.bodyMedium?.copyWith(color: _slate),
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: AppSpacing.xxs),
              count,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: title),
            const SizedBox(width: AppSpacing.sm),
            count,
          ],
        );
      },
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      children: [
        TextButton(
          onPressed: canGoPrevious ? onPrevious : null,
          child: const Text('Previous'),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTouchTarget.minimum),
          child: Center(
            widthFactor: 1,
            child: Text('Page $page', style: theme.textTheme.bodyMedium),
          ),
        ),
        TextButton(onPressed: canGoNext ? onNext : null, child: const Text('Next')),
      ],
    );
  }
}

class _ServiceResults extends StatelessWidget {
  const _ServiceResults({required this.services, required this.onOpen});

  final List<ServiceItem> services;
  final ValueChanged<ServiceItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final width = constraints.maxWidth;
        final oneColumn = width < 300 || textScale >= 1.5;
        var columns = 2;
        if (oneColumn) {
          columns = 1;
        } else if (width >= 600 && textScale < 1.3) {
          final candidateWidth = (width - (AppSpacing.sm * 2)) / 3;
          if (candidateWidth >= 176) columns = 3;
        }
        final gap = AppSpacing.sm;
        final itemWidth = (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final service in services)
              SizedBox(
                width: itemWidth,
                child: _ServiceResultCard(
                  service: service,
                  listMode: columns == 1,
                  onOpen: () => onOpen(service),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ServiceResultCard extends StatelessWidget {
  const _ServiceResultCard({
    required this.service,
    required this.listMode,
    required this.onOpen,
  });

  final ServiceItem service;
  final bool listMode;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = serviceVisualFor(service);
    final radius = BorderRadius.circular(AppRadius.card);

    final icon = ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: visual.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        alignment: Alignment.center,
        child: Icon(visual.icon, color: visual.color, size: 24),
      ),
    );

    return Semantics(
      button: true,
      label: service.title,
      excludeSemantics: true,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onOpen,
          borderRadius: radius,
          child: Container(
            constraints: BoxConstraints(minHeight: listMode ? 72 : 112),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: listMode
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      icon,
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          service.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: _ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      icon,
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        service.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: _ink,
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
    return PremiumEmptyState(
      icon: icon,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
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
