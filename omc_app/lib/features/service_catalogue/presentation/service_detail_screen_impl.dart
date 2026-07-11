import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../app_config/data/mobile_app_config.dart';
import '../../app_config/data/mobile_app_config_repository.dart';
import '../../app_config/presentation/app_brand_registry.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../support/application/support_launcher.dart';
import '../application/service_catalogue_controller.dart';
import '../data/service_item.dart';
import 'service_visual_registry.dart';

const Color _ink = Color(0xFF111827);
const Color _slate = Color(0xFF64748B);
const Color _primary = Color(0xFF111827);
const Color _primarySoft = Color(0xFFF3F4F6);
const Color _review = Color(0xFF6D28D9);
const Color _done = Color(0xFF16A34A);

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

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
          return Scaffold(
            appBar: const AppBackHeader(title: 'Service Details'),
            body: PremiumEmptyState(
              icon: Icons.search_off_rounded,
              title: 'Service not found',
              message: 'This service may have been removed from the catalogue.',
              actionLabel: 'Back to services',
              onAction: () => context.pop(),
            ),
          );
        }

        final service = matchedService;
        final tone = _serviceDetailTone(service);
        final wizardLabel = serviceCatalogueWizardBadgeLabel(service);
        final subtitle = (service.shortDescription ?? service.description ?? '')
            .trim();

        return Scaffold(
          body: Column(
            children: [
              AppBackHeader(
                title: 'Service Details',
                subtitle: 'Review requirements and start request',
                actionIcon: Icons.support_agent_rounded,
                actionTooltip: 'WhatsApp support',
                onAction: () => SupportLauncher.openWhatsApp(context),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      _HeroCard(
                        service: service,
                        tone: tone,
                        wizardLabel: wizardLabel,
                      ),
                      const SizedBox(height: 16),
                      _StatsGrid(service: service, tone: tone),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Overview',
                        icon: Icons.notes_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subtitle.isEmpty
                                  ? 'OMC will share the service brief after review.'
                                  : subtitle,
                              style: const TextStyle(
                                color: _slate,
                                fontSize: 13.5,
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MiniNote(
                                  label: 'Service-specific flow',
                                  color: tone.color,
                                ),
                                const _MiniNote(
                                  label: 'Support-assisted review',
                                  color: _primary,
                                ),
                                const _MiniNote(
                                  label: 'Progress tracked live',
                                  color: _review,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _WizardCard(
                        service: service,
                        tone: tone,
                        wizardLabel: wizardLabel,
                      ),
                      const SizedBox(height: 16),
                      _ChecklistCard(
                        title: 'Requirements',
                        subtitle:
                            'Basic information OMC needs for this service.',
                        emptyMessage:
                            'OMC will confirm requirements after reviewing your case.',
                        items: service.requirements,
                        icon: Icons.check_circle_rounded,
                        accent: tone.color,
                      ),
                      const SizedBox(height: 16),
                      _ChecklistCard(
                        title: 'Required documents',
                        subtitle:
                            'Keep these documents ready before submitting.',
                        emptyMessage:
                            'OMC will confirm required documents after reviewing your case.',
                        items: service.requiredDocuments,
                        icon: Icons.description_outlined,
                        accent: tone.color,
                      ),
                      const SizedBox(height: 16),
                      _ProcessCard(
                        steps: service.processSteps,
                        accent: tone.color,
                      ),
                      const SizedBox(height: 16),
                      _SupportCard(service: service, tone: tone),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
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
                          onPressed: () {
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
                          icon: Icon(
                            capabilities.isGuest
                                ? Icons.person_add_alt_1_rounded
                                : wizardLabel != null
                                ? Icons.arrow_forward_rounded
                                : Icons.add_rounded,
                            size: 19,
                          ),
                          label: Text(
                            _startRequestLabel(service, capabilities),
                          ),
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

class _ServiceDetailLoadingView extends StatelessWidget {
  const _ServiceDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return SafeArea(
      top: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: tone.soft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tone.border),
                ),
                child: Icon(tone.icon, color: tone.color, size: 26),
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
            const SizedBox(height: 14),
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
          const SizedBox(height: 14),
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

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.service, required this.tone});

  final ServiceItem service;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Price',
            value: service.priceLabel,
            icon: Icons.payments_outlined,
            color: tone.color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'Timeline',
            value: service.completionTime,
            icon: Icons.schedule_outlined,
            color: _review,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'Reqs',
            value: service.requirements.length.toString(),
            icon: Icons.fact_check_outlined,
            color: _done,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _slate,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
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
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 14),
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
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String emptyMessage;
  final List<String> items;
  final IconData icon;
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
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ChecklistRow(label: item, accent: accent),
              ),
        ],
      ),
    );
  }
}

class _WizardCard extends StatelessWidget {
  const _WizardCard({
    required this.service,
    required this.tone,
    required this.wizardLabel,
  });

  final ServiceItem service;
  final _Tone tone;
  final String? wizardLabel;

  @override
  Widget build(BuildContext context) {
    final hasWizard = wizardLabel != null;
    return _SectionCard(
      title: hasWizard ? 'Guided wizard' : 'How this works',
      icon: Icons.auto_awesome_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasWizard
                ? '$wizardLabel opens a step-by-step flow with the exact fields, uploads and review checkpoints for this service.'
                : 'OMC will guide you through the exact requirements for this service after request submission.',
            style: const TextStyle(
              color: _slate,
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniNote(label: 'Service-specific flow', color: tone.color),
              const _MiniNote(
                label: 'Support-assisted review',
                color: _primary,
              ),
              const _MiniNote(label: 'Progress tracked live', color: _review),
            ],
          ),
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
    return _SectionCard(
      title: 'Need help',
      icon: Icons.support_agent_rounded,
      child: Row(
        children: [
          Expanded(
            child: Text(
              service.supportMessage?.trim().isNotEmpty == true
                  ? service.supportMessage!.trim()
                  : 'Message the OMC team if any step is unclear or missing.',
              style: const TextStyle(
                color: _slate,
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: 'WhatsApp support',
            onPressed: () => SupportLauncher.openWhatsApp(context),
            style: IconButton.styleFrom(
              backgroundColor: _primary.withValues(alpha: 0.08),
              foregroundColor: _primary,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.support_agent_rounded),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: accent, size: 13),
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

class _ProcessCard extends StatelessWidget {
  const _ProcessCard({required this.steps, required this.accent});

  final List<String> steps;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Process',
      icon: Icons.route_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (steps.isEmpty)
            const _NoticePill(
              label: 'OMC will share the process after review.',
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
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

class _MiniNote extends StatelessWidget {
  const _MiniNote({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
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

String _startRequestLabel(ServiceItem service, AuthCapabilities capabilities) {
  if (capabilities.isGuest) return 'Sign up to request';
  if (capabilities.isPending) return 'View approval status';
  return serviceCatalogueWizardBadgeLabel(service) != null
      ? 'Start wizard'
      : 'Request service';
}

String _titleCase(String value) {
  return value
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}
