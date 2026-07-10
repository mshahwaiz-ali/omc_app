import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

        final service = matchedService!;
        final tone = _serviceDetailTone(service);
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
                              subtitle.isEmpty ? 'OMC will share the service brief after review.' : subtitle,
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
    if (capabilities.isGuest) return 'Please sign in or create an account to request this service.';
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
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 56, height: 56, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18))),
                const SizedBox(height: 14),
                Container(height: 18, width: 180, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999))),
                const SizedBox(height: 10),
                Container(height: 12, width: 130, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999))),
                const SizedBox(height: 18),
                Container(height: 86, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22))),
              ],
            ),
          ),
        ],
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
  final source = '\${service.category} \${service.title} \${service.wizardType ?? ''}'.toLowerCase();
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
      return '\${_titleCase(raw)} Wizard';
  }
}

String _startRequestLabel(ServiceItem service) {
  return serviceCatalogueWizardBadgeLabel(service) != null ? 'Start wizard' : 'Request service';
}

String _titleCase(String value) {
  return value
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}
