import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
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
const Color _done = Color(0xFF16A34A);
const Color _attention = Color(0xFFF59E0B);
const Color _roseSoft = Color(0xFFFFF1F3);
const Color _roseBorder = Color(0xFFF6CDD6);

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(serviceCatalogueProvider);
    final capabilities = ref.watch(authControllerProvider).capabilities;

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
        final service = services.where((item) => item.id == serviceId).cast<ServiceItem?>().firstOrNull;
        if (service == null) {
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

        final tone = serviceDetailTone(service);
        final wizardLabel = serviceCatalogueWizardBadgeLabel(service);
        final subtitle = (service.shortDescription ?? service.description ?? '').trim();

        return Scaffold(
          body: Column(
            children: [
              AppBackHeader(
                title: 'Service Details',
                subtitle: 'Review requirements and start request',
                actionIcon: Icons.chat_bubble_outline_rounded,
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
                      _HeroCard(service: service, tone: tone, wizardLabel: wizardLabel),
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
                                _MiniNote(label: 'Service-specific flow', color: tone.color),
                                const _MiniNote(label: 'Support-assisted review', color: _primary),
                                const _MiniNote(label: 'Progress tracked live', color: _review),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _WizardCard(service: service, tone: tone, wizardLabel: wizardLabel),
                      const SizedBox(height: 16),
                      _ChecklistCard(
                        title: 'Requirements',
                        subtitle: 'Basic information OMC needs for this service.',
                        emptyMessage: 'OMC will confirm requirements after reviewing your case.',
                        items: service.requirements,
                        icon: Icons.check_circle_rounded,
                        accent: tone.color,
                      ),
                      const SizedBox(height: 16),
                      _ChecklistCard(
                        title: 'Required documents',
                        subtitle: 'Keep these documents ready before submitting.',
                        emptyMessage: 'OMC will confirm required documents after reviewing your case.',
                        items: service.requiredDocuments,
                        icon: Icons.description_outlined,
                        accent: tone.color,
                      ),
                      const SizedBox(height: 16),
                      _ProcessCard(steps: service.processSteps, accent: tone.color),
                      const SizedBox(height: 16),
                      _SupportCard(service: service, tone: tone),
                      const SizedBox(height: 18),
                      AppButton(
                        label: _startRequestLabel(service),
                        icon: wizardLabel != null ? Icons.auto_awesome_rounded : Icons.add_rounded,
                        onPressed: () {
                          if (capabilities.canCreateServiceRequest) {
                            context.push('/services/${Uri.encodeComponent(service.id)}/request');
                          } else {
                            _showLockedSnack(context, capabilities);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => SupportLauncher.openWhatsApp(context),
                        icon: const Icon(Icons.support_agent_rounded),
                        label: const Text('Ask OMC support'),
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
                _LoadingBlock(width: 56, height: 56, borderRadius: 18, color: color),
                const SizedBox(height: 18),
                _LoadingBlock(width: 120, height: 12, borderRadius: 999, color: color),
                const SizedBox(height: 10),
                _LoadingBlock(width: double.infinity, height: 24, borderRadius: 999, color: color),
                const SizedBox(height: 10),
                _LoadingBlock(width: 220, height: 14, borderRadius: 999, color: color),
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
          _LoadingBlock(width: 140, height: 14, borderRadius: 999, color: color),
          const SizedBox(height: 12),
          _LoadingBlock(width: double.infinity, height: 12, borderRadius: 999, color: color),
          const SizedBox(height: 10),
          _LoadingBlock(width: double.infinity, height: 12, borderRadius: 999, color: color),
          const SizedBox(height: 10),
          _LoadingBlock(width: 220, height: 12, borderRadius: 999, color: color),
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
  const _HeroCard({required this.service, required this.tone, required this.wizardLabel});

  final ServiceItem service;
  final _Tone tone;
  final String? wizardLabel;

  @override
  Widget build(BuildContext context) {
    final subtitle = (service.shortDescription ?? service.description ?? '').trim();

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
                    if (wizardLabel != null) ...[
                      const SizedBox(height: 7),
                      _WizardBadge(label: wizardLabel!, color: tone.color),
                    ],
                    const SizedBox(height: 8),
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
              PremiumInfoChip(icon: Icons.payments_outlined, label: service.priceLabel, color: tone.color),
              PremiumInfoChip(icon: Icons.schedule_rounded, label: service.completionTime, color: _review),
              if (service.governmentFeeLabel != null && service.governmentFeeLabel!.trim().isNotEmpty)
                const PremiumInfoChip(icon: Icons.account_balance_outlined, label: 'Government fee', color: _primary),
            ],
          ),
          if (service.governmentFeeLabel != null && service.governmentFeeLabel!.trim().isNotEmpty) ...[
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
                  Icon(Icons.account_balance_outlined, color: tone.color, size: 16),
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
        Expanded(child: _StatTile(label: 'Price', value: service.priceLabel, icon: Icons.payments_outlined, color: tone.color)),
        const SizedBox(width: 10),
        Expanded(child: _StatTile(label: 'Timeline', value: service.completionTime, icon: Icons.schedule_outlined, color: _review)),
        const SizedBox(width: 10),
        Expanded(child: _StatTile(label: 'Reqs', value: service.requirements.length.toString(), icon: Icons.fact_check_outlined, color: _done)),
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
  const _SectionCard({required this.title, required this.icon, required this.child});

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
  const _WizardCard({required this.service, required this.tone, required this.wizardLabel});

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
              const _MiniNote(label: 'Support-assisted review', color: _primary),
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
            icon: const Icon(Icons.chat_bubble_outline_rounded),
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
            const _NoticePill(label: 'OMC will share the process after review.', accent: _primary)
          else
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 10),
                child: _ProcessRow(index: i + 1, label: steps[i], accent: accent),
              ),
        ],
      ),
    );
  }
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({required this.index, required this.label, required this.accent});

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
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

_Tone serviceDetailTone(ServiceItem service) {
  final source = '${service.category} ${service.title} ${service.wizardType ?? ''}'.toLowerCase();
  if (source.contains('visa')) return const _Tone(icon: Icons.flight_takeoff_rounded, color: Color(0xFF0F766E));
  if (source.contains('tax') || source.contains('ntn') || source.contains('gst')) return const _Tone(icon: Icons.receipt_long_outlined, color: Color(0xFF8B5CF6));
  if (source.contains('business') || source.contains('setup')) return const _Tone(icon: Icons.apartment_outlined, color: Color(0xFFDB2777));
  if (source.contains('document')) return const _Tone(icon: Icons.description_outlined, color: Color(0xFF0F9D8E));
  if (source.contains('payment') || source.contains('receipt') || source.contains('invoice')) return const _Tone(icon: Icons.payments_outlined, color: Color(0xFFF97316));
  if (source.contains('hr') || source.contains('employee')) return const _Tone(icon: Icons.groups_rounded, color: Color(0xFF14B8A6));
  if (source.contains('lead')) return const _Tone(icon: Icons.record_voice_over_rounded, color: Color(0xFF7C3AED));
  if (source.contains('task') || source.contains('todo')) return const _Tone(icon: Icons.task_alt_rounded, color: Color(0xFFF59E0B));
  if (source.contains('support') || source.contains('case') || source.contains('request')) return const _Tone(icon: Icons.support_agent_rounded, color: Color(0xFF334155));
  return const _Tone(icon: Icons.workspace_premium_outlined, color: _ink);
}

String _startRequestLabel(ServiceItem service) {
  return serviceCatalogueWizardBadgeLabel(service) != null ? 'Start wizard' : 'Request service';
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

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
