import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../../core/widgets/premium_list_header.dart';
import '../application/service_catalogue_controller.dart';
import '../../support/application/support_launcher.dart';
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

  final _searchController = TextEditingController();

  String _selectedCategory = _allCategory;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(serviceCatalogueProvider);

    return SafeArea(
      child: servicesAsync.when(
        loading: () => const LoadingView(message: 'Loading services...'),
        error: (error, stackTrace) => EmptyState(
          title: 'Services unavailable',
          message: _serviceCatalogueErrorMessage(error),
          icon: Icons.cloud_off_outlined,
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(serviceCatalogueProvider),
        ),
        data: (services) {
          final categoryValues =
              services
                  .map((service) => service.category.trim())
                  .where((category) => category.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();

          final categories = [_allCategory, ...categoryValues];
          final filteredServices = _filterServices(services);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _CatalogueHeader(
                    controller: _searchController,
                    services: services,
                    filteredCount: filteredServices.length,
                    selectedCategory: _selectedCategory,
                    onChanged: (value) {
                      setState(() {
                        _query = value.trim().toLowerCase();
                      });
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 0, 18),
                sliver: SliverToBoxAdapter(
                  child: _CategoryFilter(
                    categories: categories,
                    selectedCategory: _selectedCategory,
                    onSelected: (category) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                sliver: SliverToBoxAdapter(child: _MyServicesShortcutCard()),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (filteredServices.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    title: 'No matching services',
                    message: 'Try another search term or category.',
                    icon: Icons.search_off_rounded,
                    actionLabel: 'Clear filters',
                    onAction: () {
                      _searchController.clear();
                      setState(() {
                        _query = '';
                        _selectedCategory = _allCategory;
                      });
                    },
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverList.builder(
                    itemCount: filteredServices.length,
                    itemBuilder: (context, index) {
                      final service = filteredServices[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == filteredServices.length - 1 ? 0 : 14,
                        ),
                        child: _ServiceCatalogueCard(
                          service: service,
                          onOpenDetails: () => context.push(
                            '/services/${Uri.encodeComponent(service.id)}',
                          ),
                          onRequest: () => context.push(
                            '/services/${Uri.encodeComponent(service.id)}/request',
                          ),
                          onWhatsApp: () =>
                              SupportLauncher.openWhatsApp(context),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<ServiceItem> _filterServices(List<ServiceItem> services) {
    return services
        .where((service) {
          final matchesCategory =
              _selectedCategory == _allCategory ||
              service.category == _selectedCategory;
          final searchableText = [
            service.title,
            service.category,
            service.feeLabel,
            service.completionTime,
            ...service.requirements,
          ].join(' ').toLowerCase();
          final matchesQuery =
              _query.isEmpty || searchableText.contains(_query);

          return matchesCategory && matchesQuery;
        })
        .toList(growable: false);
  }
}

class _CatalogueHeader extends StatelessWidget {
  const _CatalogueHeader({
    required this.controller,
    required this.services,
    required this.filteredCount,
    required this.selectedCategory,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<ServiceItem> services;
  final int filteredCount;
  final String selectedCategory;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumListHeader(
          icon: Icons.workspace_premium_outlined,
          title: 'Services',
          subtitle: 'Tax, registration and compliance services from OMC.',
          metaLabel: '\$filteredCount showing',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search services',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 14),
        _CatalogueStatsRow(
          totalServices: services.length,
          filteredCount: filteredCount,
          selectedCategory: selectedCategory,
        ),
      ],
    );
  }
}

class _CatalogueStatsRow extends StatelessWidget {
  const _CatalogueStatsRow({
    required this.totalServices,
    required this.filteredCount,
    required this.selectedCategory,
  });

  final int totalServices;
  final int filteredCount;
  final String selectedCategory;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CatalogueStatTile(
            icon: Icons.workspace_premium_outlined,
            label: 'Services',
            value: totalServices.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CatalogueStatTile(
            icon: Icons.filter_alt_outlined,
            label: 'Showing',
            value: filteredCount.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CatalogueStatTile(
            icon: Icons.category_outlined,
            label: 'Category',
            value: selectedCategory,
          ),
        ),
      ],
    );
  }
}

class _CatalogueStatTile extends StatelessWidget {
  const _CatalogueStatTile({
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
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 18),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
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
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == selectedCategory;

          return ChoiceChip(
            label: Text(category),
            selected: selected,
            onSelected: (_) => onSelected(category),
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
            selectedColor: AppTheme.primaryRed,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected
                  ? AppTheme.primaryRed
                  : Colors.black.withValues(alpha: 0.06),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }
}

class _MyServicesShortcutCard extends StatelessWidget {
  const _MyServicesShortcutCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: () => context.go('/my-services'),
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
          SizedBox(width: 10),
          Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}

class _ServiceCatalogueCard extends StatelessWidget {
  const _ServiceCatalogueCard({
    required this.service,
    required this.onOpenDetails,
    required this.onRequest,
    required this.onWhatsApp,
  });

  final ServiceItem service;
  final VoidCallback onOpenDetails;
  final VoidCallback onRequest;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final visibleRequirements = service.requirements.take(3).toList();
    final remainingRequirements =
        service.requirements.length - visibleRequirements.length;
    final wizardLabel = _wizardBadgeLabel(service);

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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: AppTheme.primaryRed,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.category,
                      style: const TextStyle(
                        color: AppTheme.primaryRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (wizardLabel != null) ...[
                      const SizedBox(height: 7),
                      _WizardBadge(label: wizardLabel),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      service.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
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
                label: service.feeLabel,
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
            Text(
              service.governmentFeeLabel!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (visibleRequirements.isNotEmpty) ...[
            const SizedBox(height: 16),
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
              Text(
                '+$remainingRequirements more',
                style: const TextStyle(
                  color: AppTheme.primaryRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: _requestButtonLabel(service),
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
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.primaryRed,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
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

String _requestButtonLabel(ServiceItem service) {
  return _wizardBadgeLabel(service) == null ? 'Request' : 'Start wizard';
}

String _normalizedWizardType(ServiceItem service) {
  return service.wizardType?.trim().toLowerCase() ?? '';
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: AppTheme.primaryRed,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

String _serviceCatalogueErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final message = error.toString().replaceFirst('ApiError:', '').trim();
  if (message.isNotEmpty) return message;

  return 'Service catalogue is unavailable right now. Please try again.';
}
