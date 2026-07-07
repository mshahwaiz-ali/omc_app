import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../../core/widgets/premium_list_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
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
    final capabilities = ref.watch(authControllerProvider).capabilities;

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
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _MyServicesShortcutCard(
                    onTap: () {
                      if (capabilities.canViewCustomerDashboard ||
                          capabilities.canAccessInternalWorkspace) {
                        context.go('/my-services');
                        return;
                      }
                      _showLockedSnack(context, capabilities);
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (services.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: PremiumEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No services configured',
                    message:
                        'OMC has not published mobile services from the backend yet. Please retry after services are configured or contact support.',
                    actionLabel: 'Retry',
                    onAction: () => ref.invalidate(serviceCatalogueProvider),
                  ),
                )
              else if (filteredServices.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: PremiumEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matching services',
                    message: 'Try another search term or category.',
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
                          onRequest: () {
                            if (capabilities.canCreateServiceRequest) {
                              context.push(
                                '/services/${Uri.encodeComponent(service.id)}/request',
                              );
                              return;
                            }
                            _showLockedSnack(context, capabilities);
                          },
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

  String _lockedAccessMessage(AuthCapabilities capabilities) {
    if (capabilities.isGuest) {
      return 'Please sign in or create an account to request this service.';
    }
    if (capabilities.isPending) {
      return 'Your account is under review. OMC will enable service requests after approval.';
    }
    if (capabilities.isRejected) {
      return 'This account is not approved for service requests. Please contact OMC support.';
    }
    return 'This account does not have access to service requests.';
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

class _CatalogueLoadingView extends StatelessWidget {
  const _CatalogueLoadingView();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CatalogueLoadingBlock(
                width: 150,
                height: 26,
                radius: 999,
                color: color,
              ),
              const SizedBox(height: 12),
              _CatalogueLoadingBlock(
                width: double.infinity,
                height: 48,
                radius: 18,
                color: color,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(child: _CatalogueLoadingChip()),
            SizedBox(width: 10),
            Expanded(child: _CatalogueLoadingChip()),
            SizedBox(width: 10),
            Expanded(child: _CatalogueLoadingChip()),
          ],
        ),
        const SizedBox(height: 18),
        for (var index = 0; index < 4; index++) ...[
          _CatalogueLoadingCard(color: color),
          if (index != 3) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _CatalogueLoadingChip extends StatelessWidget {
  const _CatalogueLoadingChip();

  @override
  Widget build(BuildContext context) {
    return _CatalogueLoadingBlock(
      width: double.infinity,
      height: 40,
      radius: 999,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}

class _CatalogueLoadingCard extends StatelessWidget {
  const _CatalogueLoadingCard({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _CatalogueLoadingBlock(
            width: 52,
            height: 52,
            radius: 18,
            color: color,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CatalogueLoadingBlock(
                  width: double.infinity,
                  height: 16,
                  radius: 999,
                  color: color,
                ),
                const SizedBox(height: 10),
                _CatalogueLoadingBlock(
                  width: 180,
                  height: 12,
                  radius: 999,
                  color: color,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogueLoadingBlock extends StatelessWidget {
  const _CatalogueLoadingBlock({
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
          metaLabel: '$filteredCount showing',
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
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.065),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryRed.withValues(alpha: 0.07),
              ),
            ),
            child: Icon(icon, color: AppTheme.primaryRed, size: 17),
          ),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              height: 1.05,
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
              height: 1.15,
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
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == selectedCategory;

          return ChoiceChip(
            label: Text(category),
            selected: selected,
            onSelected: (_) => onSelected(category),
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.1,
            ),
            selectedColor: AppTheme.primaryRed,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected
                  ? AppTheme.primaryRed
                  : Colors.black.withValues(alpha: 0.06),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

class _MyServicesShortcutCard extends StatelessWidget {
  const _MyServicesShortcutCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: AppTheme.primaryRed,
            ),
          ),
          const SizedBox(width: 15),
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
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
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
      padding: const EdgeInsets.all(19),
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
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  ),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: AppTheme.primaryRed,
                  size: 23,
                ),
              ),
              const SizedBox(width: 15),
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

String _serviceCatalogueErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final message = error.toString().replaceFirst('ApiError:', '').trim();
  if (message.isNotEmpty) return message;

  return 'Service catalogue is unavailable right now. Please try again.';
}
