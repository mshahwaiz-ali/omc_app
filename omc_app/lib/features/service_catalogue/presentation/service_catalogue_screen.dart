import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/premium_card.dart';
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

  final _searchController = TextEditingController();

  String _selectedCategory = _allCategory;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSoonMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(serviceCatalogueProvider);

    return SafeArea(
      child: servicesAsync.when(
        loading: () => const LoadingView(message: 'Loading services...'),
        error: (error, stackTrace) => EmptyState(
          title: 'Services unavailable',
          message: error.toString(),
          icon: Icons.cloud_off_outlined,
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(serviceCatalogueProvider),
        ),
        data: (services) {
          final categories = [
            _allCategory,
            ...services
                .map((service) => service.category)
                .where((category) => category.trim().isNotEmpty)
                .toSet(),
          ];
          final filteredServices = _filterServices(services);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _CatalogueHeader(
                    controller: _searchController,
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
                          onRequest: () => _showSoonMessage(
                            'Request wizard will be connected in the service request phase.',
                          ),
                          onWhatsApp: () => _showSoonMessage(
                            'WhatsApp support will be connected in the support phase.',
                          ),
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
  const _CatalogueHeader({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Services',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tax, registration and compliance services from OMC.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
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
      ],
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

class _ServiceCatalogueCard extends StatelessWidget {
  const _ServiceCatalogueCard({
    required this.service,
    required this.onRequest,
    required this.onWhatsApp,
  });

  final ServiceItem service;
  final VoidCallback onRequest;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final visibleRequirements = service.requirements.take(3).toList();
    final remainingRequirements =
        service.requirements.length - visibleRequirements.length;

    return PremiumCard(
      padding: const EdgeInsets.all(18),
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
                    const SizedBox(height: 5),
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
              _InfoPill(icon: Icons.payments_outlined, label: service.feeLabel),
              _InfoPill(
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
                  label: 'Request',
                  icon: Icons.add_rounded,
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryRed),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
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
