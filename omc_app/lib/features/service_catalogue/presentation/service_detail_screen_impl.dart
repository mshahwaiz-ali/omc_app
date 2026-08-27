import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../app_config/data/mobile_app_config.dart';
import '../../app_config/data/mobile_app_config_repository.dart';
import '../../app_config/presentation/app_brand_registry.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../service_requests/data/service_case.dart';
import '../../service_requests/data/service_case_repository.dart';
import '../../support/application/support_launcher.dart';
import '../application/service_catalogue_controller.dart';
import '../data/service_item.dart';
import 'service_visual_registry.dart';

const Color _ink = Color(0xFF111827);
const Color _slate = Color(0xFF64748B);
const Color _primary = Color(0xFF111827);
const Color _primarySoft = Color(0xFFF3F4F6);
const Color _surface = Color(0xFFF8FAFC);
const Color _border = Color(0xFFE5E7EB);

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
    final servicesAsync = ref.watch(serviceCatalogueProvider);
    final capabilities = ref.watch(authControllerProvider).capabilities;
    final mobileConfig =
        ref.watch(mobileAppConfigProvider).value ?? MobileAppConfig.fallback;
    final primaryColor = appPrimaryColorFor(
      mobileConfig.branding.primaryColorFamily,
    );
    final primaryForeground = appPrimaryForegroundFor(
      mobileConfig.branding.primaryColorFamily,
    );

    return servicesAsync.when(
      loading: () => const Scaffold(
        appBar: AppBackHeader(title: 'Service Details'),
        body: _ServiceDetailLoadingView(),
      ),
      error: (error, _) => Scaffold(
        appBar: const AppBackHeader(title: 'Service Details'),
        body: PremiumEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Service unavailable',
          message: serviceCatalogueErrorMessage(error),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(serviceCatalogueProvider),
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
            body: PremiumEmptyState(
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
          );
        }

        final service = matchedService;
        final tone = _serviceDetailTone(service);
        final String? wizardLabel = null;
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
                actionIcon: Icons.support_agent_rounded,
                actionTooltip: 'WhatsApp support',
                onAction: () => SupportLauncher.openWhatsApp(context),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 122),
                    children: [
                      _HeroCard(
                        service: service,
                        tone: tone,
                        wizardLabel: wizardLabel,
                      ),
                      if (showOverview) ...[
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'Overview',
                          icon: Icons.notes_rounded,
                          child: Text(
                            overview,
                            style: const TextStyle(
                              color: _slate,
                              fontSize: 13.5,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (service.requirements.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ChecklistCard(
                          title: 'Requirements',
                          subtitle:
                              'Basic information OMC needs for this service.',
                          emptyMessage: '',
                          items: service.requirements,
                          icon: Icons.fact_check_outlined,
                          itemIcon: Icons.check_rounded,
                          accent: _ink,
                        ),
                        const SizedBox(height: 12),
                      ] else
                        const SizedBox(height: 12),
                      _ChecklistCard(
                        title: 'Required documents',
                        subtitle:
                            'Keep these documents ready before submitting.',
                        emptyMessage:
                            'OMC will confirm required documents after reviewing your case.',
                        items: service.requiredDocuments,
                        icon: Icons.description_outlined,
                        itemIcon: Icons.description_outlined,
                        accent: _ink,
                      ),
                      const SizedBox(height: 12),
                      _ProcessCard(
                        steps: service.processSteps,
                        accent: _ink,
                        isInternal: false,
                      ),
                      const SizedBox(height: 12),
                      _SupportCard(service: service, tone: tone),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          key: OmcWidgetKeys.serviceStartRequest,
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: primaryForeground,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.1,
                            ),
                          ),
                          onPressed: () => _startService(
                            context,
                            ref,
                            service,
                            capabilities,
                          ),
                          icon: Icon(
                            capabilities.isGuest
                                ? Icons.person_add_alt_1_rounded
                                : wizardLabel != null
                                ? Icons.arrow_forward_rounded
                                : Icons.add_rounded,
                            size: 19,
                          ),
                          label: Text(_startRequestLabel(capabilities)),
                        ),
                      ),
                    ],
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
      backgroundColor: Colors.transparent,
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
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 18 + bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Service already in progress',
            style: TextStyle(
              color: _ink,
              fontSize: 20,
              height: 1.15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            cases.length == 1
                ? 'An active ${service.title} request already exists. Resume it or start a separate request.'
                : '${cases.length} active ${service.title} requests already exist. Resume one or start a separate request.',
            style: const TextStyle(
              color: _slate,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: cases.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final serviceCase = cases[index];
                return Material(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onResume(serviceCase),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: _border),
                            ),
                            child: const Icon(
                              Icons.description_outlined,
                              color: _slate,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isInternal
                                      ? serviceCase.displayCustomerName
                                      : serviceCase.displayReference,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isInternal
                                      ? '${serviceCase.displayReference} · ${serviceCase.status}'
                                      : serviceCase.status,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _slate,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: _ink,
                            size: 19,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: onStartNew,
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Start a new request'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceDetailLoadingView extends StatelessWidget {
  const _ServiceDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return SafeArea(
      top: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 122),
        children: [
          PremiumCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LoadingBlock(
                  width: 56,
                  height: 56,
                  borderRadius: 18,
                  color: color,
                ),
                const SizedBox(height: 18),
                _LoadingBlock(
                  width: 120,
                  height: 12,
                  borderRadius: 999,
                  color: color,
                ),
                const SizedBox(height: 10),
                _LoadingBlock(
                  width: double.infinity,
                  height: 24,
                  borderRadius: 999,
                  color: color,
                ),
                const SizedBox(height: 10),
                _LoadingBlock(
                  width: 220,
                  height: 14,
                  borderRadius: 999,
                  color: color,
                ),
              ],
            ),
          ),
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
          const _LoadingSection(),
          const SizedBox(height: 14),
          const _LoadingSection(),
        ],
      ),
    );
  }
}

class _LoadingSection extends StatelessWidget {
  const _LoadingSection();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LoadingBlock(
            width: 140,
            height: 14,
            borderRadius: 999,
            color: color,
          ),
          const SizedBox(height: 12),
          _LoadingBlock(
            width: double.infinity,
            height: 12,
            borderRadius: 999,
            color: color,
          ),
          const SizedBox(height: 10),
          _LoadingBlock(
            width: double.infinity,
            height: 12,
            borderRadius: 999,
            color: color,
          ),
          const SizedBox(height: 10),
          _LoadingBlock(
            width: 220,
            height: 12,
            borderRadius: 999,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _LoadingStatCard extends StatelessWidget {
  const _LoadingStatCard();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _LoadingBlock(width: 28, height: 28, borderRadius: 12, color: color),
          const SizedBox(height: 10),
          _LoadingBlock(width: 48, height: 12, borderRadius: 999, color: color),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.service,
    required this.tone,
    required this.wizardLabel,
  });

  final ServiceItem service;
  final _Tone tone;
  final String? wizardLabel;

  @override
  Widget build(BuildContext context) {
    final subtitle = (service.shortDescription ?? service.description ?? '')
        .trim();

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: tone.soft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tone.border),
                ),
                child: Icon(tone.icon, color: tone.color, size: 26),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 7),
                    Text(
                      service.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 22,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (wizardLabel != null) ...[
                      const SizedBox(height: 9),
                      _WizardBadge(label: wizardLabel!, color: tone.color),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: const TextStyle(
                color: _slate,
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
                color: _slate,
              ),
              if (service.governmentFeeLabel != null &&
                  service.governmentFeeLabel!.trim().isNotEmpty)
                const PremiumInfoChip(
                  icon: Icons.account_balance_outlined,
                  label: 'Government fee',
                  color: _primary,
                ),
            ],
          ),
          if (service.governmentFeeLabel != null &&
              service.governmentFeeLabel!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    color: tone.color,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      service.governmentFeeLabel!,
                      style: const TextStyle(
                        color: _slate,
                        fontSize: 12,
                        height: 1.32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _ink, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    required this.items,
    required this.icon,
    required this.itemIcon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String emptyMessage;
  final List<String> items;
  final IconData icon;
  final IconData itemIcon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: const TextStyle(
              color: _slate,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            _NoticePill(label: emptyMessage, accent: accent)
          else
            for (var i = 0; i < items.length; i++) ...[
              _ChecklistRow(label: items[i], accent: accent, icon: itemIcon),
              if (i != items.length - 1)
                const Divider(height: 17, color: _border),
            ],
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.service, required this.tone});

  final ServiceItem service;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final message = service.supportMessage?.trim().isNotEmpty == true
        ? service.supportMessage!.trim()
        : 'Message the OMC team if any step is unclear or missing.';

    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.soft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tone.border),
            ),
            child: Icon(
              Icons.support_agent_rounded,
              color: tone.color,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need help?',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
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
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'WhatsApp support',
            onPressed: () => SupportLauncher.openWhatsApp(context),
            style: IconButton.styleFrom(
              backgroundColor: _primary.withValues(alpha: 0.06),
              foregroundColor: _primary,
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.label,
    required this.accent,
    required this.icon,
  });

  final String label;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accent, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: const TextStyle(
                  color: _slate,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessCard extends StatelessWidget {
  const _ProcessCard({
    required this.steps,
    required this.accent,
    required this.isInternal,
  });

  final List<String> steps;
  final Color accent;
  final bool isInternal;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Process',
      icon: Icons.route_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (steps.isEmpty)
            _NoticePill(
              label: isInternal
                  ? 'No delivery process is configured.'
                  : 'OMC will share the process after review.',
              accent: _primary,
            )
          else
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == steps.length - 1 ? 0 : 10,
                ),
                child: _ProcessRow(
                  index: i + 1,
                  label: steps[i],
                  accent: accent,
                ),
              ),
        ],
      ),
    );
  }
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({
    required this.index,
    required this.label,
    required this.accent,
  });

  final int index;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.10)),
          ),
          alignment: Alignment.center,
          child: Text(
            index.toString(),
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              label,
              style: const TextStyle(
                color: _slate,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoticePill extends StatelessWidget {
  const _NoticePill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.color,
  });

  final double width;
  final double height;
  final double borderRadius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
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
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.05,
        ),
      ),
    );
  }
}

class _Tone {
  const _Tone({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  Color get soft => color.withValues(alpha: 0.09);
  Color get border => color.withValues(alpha: 0.16);
}

String _normalizedServiceCopy(String value) {
  return value.trim().replaceAll(RegExp(r'\\s+'), ' ').toLowerCase();
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
