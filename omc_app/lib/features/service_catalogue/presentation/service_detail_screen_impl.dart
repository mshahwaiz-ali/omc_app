import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../service_requests/data/service_case.dart';
import '../../service_requests/data/service_case_repository.dart';
import '../../support/application/support_launcher.dart';
import '../application/service_catalogue_controller.dart';
import '../data/service_item.dart';
import 'service_visual_registry.dart';

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({
    super.key,
    required this.serviceId,
    this.assisted = false,
    this.customerProfile,
    this.customerName,
  });

  final String serviceId;
  final bool assisted;
  final String? customerProfile;
  final String? customerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(serviceDetailProvider(serviceId));
    final capabilities = ref.watch(authControllerProvider).capabilities;

    return servicesAsync.when(
      loading: () => const Scaffold(
        appBar: AppBackHeader(title: 'Service Details'),
        body: _ServiceDetailLoadingView(),
      ),
      error: (error, _) => Scaffold(
        appBar: const AppBackHeader(title: 'Service Details'),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: PremiumEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Service unavailable',
            message: serviceCatalogueErrorMessage(error),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(serviceDetailProvider(serviceId)),
          ),
        ),
      ),
      data: (services) {
        ServiceItem? matchedService;
        for (final item in services) {
          if (item.id == serviceId) {
            matchedService = item;
            break;
          }
        }

        if (matchedService == null) {
          final catalogueIsEmpty = services.isEmpty;
          return Scaffold(
            appBar: const AppBackHeader(title: 'Service Details'),
            body: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: PremiumEmptyState(
                icon: catalogueIsEmpty
                    ? Icons.inventory_2_outlined
                    : Icons.search_off_rounded,
                title: catalogueIsEmpty
                    ? 'No services available'
                    : 'Service unavailable',
                message: catalogueIsEmpty
                    ? 'OMC has not published any mobile services yet. Please check again later.'
                    : 'This service is no longer available in the current catalogue.',
                actionLabel: 'Back to services',
                onAction: () => context.go('/services'),
              ),
            ),
          );
        }

        final service = matchedService;
        final tone = _serviceDetailTone(service);
        final heroSubtitle =
            (service.shortDescription ?? service.description ?? '').trim();
        final overview = (service.description ?? '').trim();
        final showOverview =
            overview.isNotEmpty &&
            _normalizedServiceCopy(overview) !=
                _normalizedServiceCopy(heroSubtitle);

        return Scaffold(
          key: OmcWidgetKeys.serviceDetailScreen,
          body: Column(
            children: [
              AppBackHeader(
                title: 'Service Details',
                subtitle: 'Review requirements and start service',
                actionIcon: Icons.support_agent_outlined,
                actionTooltip: 'WhatsApp support',
                onAction: () => SupportLauncher.openWhatsApp(context),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final pageInset = AppLayout.pageInsetFor(
                        constraints.maxWidth,
                      );
                      return ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          pageInset,
                          AppSpacing.md,
                          pageInset,
                          122,
                        ),
                        children: [
                          Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: AppLayout.generalMaxWidth,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (assisted) ...[
                                    _AssistedServiceContext(
                                      customerName: customerName,
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                  ],
                                  _ServiceHero(service: service, tone: tone),
                                  if (showOverview) ...[
                                    const SizedBox(height: AppSpacing.xxl),
                                    _TextSection(
                                      title: 'Overview',
                                      child: Text(
                                        overview,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: AppTheme.textSecondary,
                                            ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.xxl),
                                  if (service.requirements.isNotEmpty) ...[
                                    _ChecklistSection(
                                      title: 'Requirements',
                                      subtitle:
                                          'Basic information OMC needs for this service.',
                                      emptyMessage: '',
                                      items: service.requirements,
                                      icon: Icons.check_rounded,
                                    ),
                                    const SizedBox(height: AppSpacing.xxl),
                                  ],
                                  _ChecklistSection(
                                    title: 'Required documents',
                                    subtitle:
                                        'Keep these documents ready for the request. Upload happens on the request/document surfaces when the system asks for them.',
                                    emptyMessage:
                                        'OMC will confirm required documents after reviewing your case.',
                                    items: service.requiredDocuments,
                                    icon: Icons.description_outlined,
                                  ),
                                  const SizedBox(height: AppSpacing.xxl),
                                  _ProcessSection(steps: service.processSteps),
                                  const SizedBox(height: AppSpacing.xxl),
                                  _SupportSection(service: service),
                                  const SizedBox(height: AppSpacing.xl),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      key: OmcWidgetKeys.serviceStartRequest,
                                      onPressed: () => _startService(
                                        context,
                                        ref,
                                        service,
                                        capabilities,
                                      ),
                                      icon: Icon(
                                        capabilities.isGuest
                                            ? Icons.person_add_alt_1_rounded
                                            : Icons.add_rounded,
                                      ),
                                      label: Text(
                                        _startRequestLabel(capabilities),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startService(
    BuildContext context,
    WidgetRef ref,
    ServiceItem service,
    AuthCapabilities capabilities,
  ) async {
    if (!_canStartService(capabilities)) {
      if (capabilities.isGuest) {
        context.push('/signup');
      } else if (capabilities.isPending) {
        context.go('/under-review');
      } else {
        _showLockedSnack(context, capabilities);
      }
      return;
    }

    List<ServiceCase> activeCases = const [];
    try {
      final cases = await ref.read(serviceCasesProvider.future);
      activeCases = cases
          .where((serviceCase) {
            if (serviceCase.isClosed) return false;

            final caseServiceId = serviceCase.serviceId?.trim().toLowerCase();
            final selectedServiceId = service.id.trim().toLowerCase();
            if (caseServiceId != null && caseServiceId.isNotEmpty) {
              return caseServiceId == selectedServiceId;
            }

            return serviceCase.title.trim().toLowerCase() ==
                service.title.trim().toLowerCase();
          })
          .toList(growable: false);
    } catch (_) {
      // Duplicate checking must never prevent a valid new request.
    }

    if (!context.mounted) return;
    if (activeCases.isEmpty) {
      _openNewRequest(context, service);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _ExistingServiceRequestsSheet(
        service: service,
        cases: activeCases,
        isInternal: capabilities.isInternal,
        onResume: (serviceCase) {
          Navigator.of(sheetContext).pop();
          _openExistingRequest(context, serviceCase, capabilities);
        },
        onStartNew: () {
          Navigator.of(sheetContext).pop();
          _openNewRequest(context, service);
        },
      ),
    );
  }

  String _startRequestLabel(AuthCapabilities capabilities) {
    if (capabilities.isGuest) return 'Create account to start';
    if (capabilities.canCreateServiceForCustomer) {
      return 'Start for customer';
    }
    return 'Start request';
  }

  bool _canStartService(AuthCapabilities capabilities) {
    return capabilities.canCreateServiceRequest ||
        capabilities.canCreateServiceForCustomer;
  }

  void _openNewRequest(BuildContext context, ServiceItem service) {
    final base = '/services/${Uri.encodeComponent(service.id)}/request';

    if (!assisted) {
      context.push(base);
      return;
    }

    final path =
        '$base'
        '?assisted=1'
        '&customer_profile=${Uri.encodeQueryComponent(customerProfile ?? '')}'
        '&customer_name=${Uri.encodeQueryComponent(customerName ?? '')}';

    context.push(path);
  }

  void _openExistingRequest(
    BuildContext context,
    ServiceCase serviceCase,
    AuthCapabilities capabilities,
  ) {
    final caseId = Uri.encodeComponent(serviceCase.id);
    if (capabilities.isInternal) {
      context.push('/internal-workspace/service-cases/$caseId');
      return;
    }
    context.push('/my-services/$caseId');
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
      return 'Your account is under review. OMC team will verify your profile before enabling service access.';
    }
    if (capabilities.isRejected) {
      return 'This account is not approved for service requests. Please contact OMC support.';
    }
    return 'This account does not have access to service requests.';
  }
}

class _ExistingServiceRequestsSheet extends StatelessWidget {
  const _ExistingServiceRequestsSheet({
    required this.service,
    required this.cases,
    required this.isInternal,
    required this.onResume,
    required this.onStartNew,
  });

  final ServiceItem service;
  final List<ServiceCase> cases;
  final bool isInternal;
  final ValueChanged<ServiceCase> onResume;
  final VoidCallback onStartNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.90,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md + bottomPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Service already in progress',
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              cases.length == 1
                  ? 'An active ${service.title} request already exists. Resume it or start a separate request.'
                  : '${cases.length} active ${service.title} requests already exist. Resume one or start a separate request.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: cases.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final serviceCase = cases[index];
                  final primary = isInternal
                      ? serviceCase.displayCustomerName
                      : serviceCase.displayReference;
                  final supporting = isInternal
                      ? '${serviceCase.displayReference} · ${serviceCase.status}'
                      : serviceCase.status;

                  return Semantics(
                    button: true,
                    label: '$primary. $supporting. Resume request',
                    excludeSemantics: true,
                    child: Material(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        onTap: () => onResume(serviceCase),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 64),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ExcludeSemantics(
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.control,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.description_outlined,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      primary,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: AppSpacing.xxs),
                                    Text(
                                      supporting,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onStartNew,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Start a new request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceDetailLoadingView extends StatelessWidget {
  const _ServiceDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = AppLayout.pageInsetFor(width);

    return Semantics(
      liveRegion: true,
      label: 'Loading service details',
      child: ExcludeSemantics(
        child: SafeArea(
          top: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(inset, AppSpacing.md, inset, 122),
            children: const [
              AppSkeleton(height: 180, radius: AppRadius.card),
              SizedBox(height: AppSpacing.xxl),
              AppSkeleton(height: 120, radius: AppRadius.card),
              SizedBox(height: AppSpacing.xxl),
              AppSkeleton(height: 180, radius: AppRadius.card),
              SizedBox(height: AppSpacing.xxl),
              AppSkeleton(height: 150, radius: AppRadius.card),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistedServiceContext extends StatelessWidget {
  const _AssistedServiceContext({this.customerName});

  final String? customerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleanName = customerName?.trim();
    final identity = cleanName == null || cleanName.isEmpty
        ? 'Selected customer'
        : cleanName;

    return Semantics(
      container: true,
      label: 'Assisted request context for $identity',
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
            const Icon(Icons.person_search_outlined, color: AppTheme.info, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Creating for customer',
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

class _ServiceHero extends StatelessWidget {
  const _ServiceHero({required this.service, required this.tone});

  final ServiceItem service;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = (service.shortDescription ?? service.description ?? '')
        .trim();
    final governmentFee = service.governmentFeeLabel?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tone.soft,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(tone.icon, color: tone.color, size: 28),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (service.category.trim().isNotEmpty) ...[
                    Text(
                      service.category,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tone.color,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                  ],
                  Semantics(
                    header: true,
                    child: Text(
                      service.title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final stack = constraints.maxWidth < 360 || textScale >= 1.5;
            final children = [
              _ServiceMetaItem(
                label: 'Service fee',
                value: service.priceLabel,
                icon: Icons.payments_outlined,
              ),
              _ServiceMetaItem(
                label: 'Typical time',
                value: service.completionTime,
                icon: Icons.schedule_outlined,
              ),
            ];

            if (stack) {
              return Column(
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    children[index],
                    if (index != children.length - 1)
                      const SizedBox(height: AppSpacing.xs),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[0]),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: children[1]),
              ],
            );
          },
        ),
        if (governmentFee != null && governmentFee.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _ServiceMetaItem(
            label: 'Government fee',
            value: governmentFee,
            icon: Icons.account_balance_outlined,
          ),
        ],
      ],
    );
  }
}

class _ServiceMetaItem extends StatelessWidget {
  const _ServiceMetaItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(value, style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _ChecklistSection extends StatelessWidget {
  const _ChecklistSection({
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    required this.items,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String emptyMessage;
  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _Notice(message: emptyMessage),
                )
              : Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              icon,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                items[index],
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (index != items.length - 1)
                        const Divider(height: 1, indent: 56),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _ProcessSection extends StatelessWidget {
  const _ProcessSection({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Process', style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (steps.isEmpty)
          const _Notice(message: 'OMC will share the process after review.')
        else
          for (var index = 0; index < steps.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == steps.length - 1 ? 0 : AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Text(
                        steps[index],
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _SupportSection extends StatelessWidget {
  const _SupportSection({required this.service});

  final ServiceItem service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = service.supportMessage?.trim().isNotEmpty == true
        ? service.supportMessage!.trim()
        : 'Message the OMC team if any step is unclear or missing.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final stack = constraints.maxWidth < 360 || textScale >= 1.5;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Need help?', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
          final action = TextButton.icon(
            onPressed: () => SupportLauncher.openWhatsApp(context),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('WhatsApp support'),
          );

          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: AppSpacing.sm), action],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: copy),
              const SizedBox(width: AppSpacing.sm),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _Tone {
  const _Tone({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  Color get soft => color.withValues(alpha: 0.08);
}

String _normalizedServiceCopy(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

_Tone _serviceDetailTone(ServiceItem service) {
  final visual = serviceVisualFor(service);
  return _Tone(icon: visual.icon, color: visual.color);
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
