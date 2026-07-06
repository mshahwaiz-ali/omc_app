import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../support/application/support_launcher.dart';
import '../application/service_catalogue_controller.dart';
import '../data/service_item.dart';

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(serviceCatalogueProvider);

    return servicesAsync.when(
      loading: () => const Scaffold(
        appBar: AppBackHeader(title: 'Service Details'),
        body: _ServiceDetailLoadingView(),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: const AppBackHeader(title: 'Service Details'),
        body: PremiumEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Service unavailable',
          message: _serviceCatalogueErrorMessage(error),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(serviceCatalogueProvider),
        ),
      ),
      data: (services) {
        final service = _findService(services);
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
                      _ServiceHero(service: service),
                      const SizedBox(height: 16),
                      _ServiceStatsGrid(service: service),
                      const SizedBox(height: 16),
                      _ServiceFacts(service: service),
                      const SizedBox(height: 16),
                      _OverviewCard(service: service),
                      _GuidedWizardCard(service: service),
                      const SizedBox(height: 16),
                      _ChecklistCard(
                        title: 'Requirements',
                        subtitle:
                            'Basic information OMC needs for this service.',
                        emptyMessage:
                            'OMC will confirm requirements after reviewing your case.',
                        items: service.requirements,
                        icon: Icons.check_circle_rounded,
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
                      ),
                      const SizedBox(height: 16),
                      _ProcessCard(steps: service.processSteps),
                      const SizedBox(height: 18),
                      AppButton(
                        label: _startRequestLabel(service),
                        icon: _hasGuidedWizard(service)
                            ? Icons.auto_awesome_rounded
                            : Icons.add_rounded,
                        onPressed: () => context.push(
                          '/services/${Uri.encodeComponent(service.id)}/request',
                        ),
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

  ServiceItem? _findService(List<ServiceItem> services) {
    for (final service in services) {
      if (service.id == serviceId) return service;
    }

    return null;
  }
}


class _ServiceDetailLoadingView extends StatelessWidget {
  const _ServiceDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
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
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 18),
                  _LoadingBlock(
                    width: 120,
                    height: 12,
                    borderRadius: 999,
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 10),
                  _LoadingBlock(
                    width: double.infinity,
                    height: 24,
                    borderRadius: 999,
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 10),
                  _LoadingBlock(
                    width: 220,
                    height: 14,
                    borderRadius: 999,
                    color: theme.colorScheme.surfaceContainerHighest,
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
            const Expanded(
              child: PremiumCard(
                padding: EdgeInsets.all(22),
                child: Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 2.6),
                  ),
                ),
              ),
            ),
          ],
        ),
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
          _LoadingBlock(
            width: 28,
            height: 28,
            borderRadius: 12,
            color: color,
          ),
          const SizedBox(height: 12),
          _LoadingBlock(
            width: 42,
            height: 10,
            borderRadius: 999,
            color: color,
          ),
          const SizedBox(height: 8),
          _LoadingBlock(
            width: 58,
            height: 12,
            borderRadius: 999,
            color: color,
          ),
        ],
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

class _ServiceHero extends StatelessWidget {
  const _ServiceHero({required this.service});

  final ServiceItem service;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryRed, AppTheme.darkRed],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.workspace_premium_outlined,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              service.category,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              service.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                height: 1.12,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (_clean(service.shortDescription).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _clean(service.shortDescription),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceStatsGrid extends StatelessWidget {
  const _ServiceStatsGrid({required this.service});

  final ServiceItem service;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ServiceStatTile(
            icon: Icons.payments_outlined,
            label: 'Fee',
            value: service.feeLabel,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ServiceStatTile(
            icon: Icons.schedule_rounded,
            label: 'Time',
            value: service.completionTime,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ServiceStatTile(
            icon: Icons.description_outlined,
            label: 'Docs',
            value: service.requiredDocuments.length.toString(),
          ),
        ),
      ],
    );
  }
}

class _ServiceStatTile extends StatelessWidget {
  const _ServiceStatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.trim().isEmpty ? 'TBC' : value.trim();

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 22),
          const SizedBox(height: 10),
          Text(
            safeValue,
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

class _ServiceFacts extends StatelessWidget {
  const _ServiceFacts({required this.service});

  final ServiceItem service;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        children: [
          _FactRow(
            icon: Icons.payments_outlined,
            label: 'Fee',
            value: service.feeLabel,
          ),
          const Divider(height: 24),
          _FactRow(
            icon: Icons.schedule_rounded,
            label: 'Completion time',
            value: service.completionTime,
          ),
          if (_clean(service.governmentFeeLabel).isNotEmpty) ...[
            const Divider(height: 24),
            _FactRow(
              icon: Icons.account_balance_outlined,
              label: 'Government fee',
              value: _clean(service.governmentFeeLabel),
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.service});

  final ServiceItem service;

  @override
  Widget build(BuildContext context) {
    final text = _clean(service.description).isNotEmpty
        ? _clean(service.description)
        : _clean(service.shortDescription);

    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.trim().isEmpty ? 'To be confirmed' : value.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primaryRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: AppTheme.primaryRed, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                safeValue,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuidedWizardCard extends StatelessWidget {
  const _GuidedWizardCard({required this.service});

  final ServiceItem service;

  @override
  Widget build(BuildContext context) {
    if (!_hasGuidedWizard(service)) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: PremiumCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppTheme.primaryRed,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _wizardTitle(service),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _wizardSubtitle(service),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
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

String _startRequestLabel(ServiceItem service) {
  switch (_normalizedWizardType(service)) {
    case 'ntn':
      return 'Start NTN wizard';
    case 'iris':
      return 'Start IRIS wizard';
    case 'gst':
      return 'Start GST wizard';
    case 'business':
      return 'Start business wizard';
    default:
      return 'Start request';
  }
}

bool _hasGuidedWizard(ServiceItem service) {
  return _normalizedWizardType(service).isNotEmpty;
}

String _normalizedWizardType(ServiceItem service) {
  return service.wizardType?.trim().toLowerCase() ?? '';
}

String _wizardTitle(ServiceItem service) {
  switch (_normalizedWizardType(service)) {
    case 'ntn':
      return 'Guided NTN request';
    case 'iris':
      return 'Guided IRIS profile request';
    case 'gst':
      return 'Guided GST registration request';
    case 'business':
      return 'Guided business request';
    default:
      return 'Guided request';
  }
}

String _wizardSubtitle(ServiceItem service) {
  switch (_normalizedWizardType(service)) {
    case 'ntn':
      return 'Collect CNIC, occupation, income source, documents and contact details in one flow.';
    case 'iris':
      return 'Collect income-source and profile update details before submitting to OMC.';
    case 'gst':
      return 'Collect business type, business nature, consumer number and required documents.';
    case 'business':
      return 'Collect business structure, setup context, documents and contact details.';
    default:
      return 'Use a structured request flow for faster OMC review.';
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
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
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(
              emptyMessage,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _ChecklistRow(label: item, icon: icon),
              ),
        ],
      ),
    );
  }
}

class _ProcessCard extends StatelessWidget {
  const _ProcessCard({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Process',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'How this request usually moves with OMC.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (steps.isEmpty)
            const Text(
              'OMC will confirm the process after reviewing your request.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            for (var index = 0; index < steps.length; index++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == steps.length - 1 ? 0 : 12,
                ),
                child: _ProcessStep(number: index + 1, label: steps[index]),
              ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
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

class _ProcessStep extends StatelessWidget {
  const _ProcessStep({required this.number, required this.label});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 27,
          height: 27,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primaryRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            number.toString(),
            style: const TextStyle(
              color: AppTheme.primaryRed,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

String _clean(String? value) {
  return value?.trim() ?? '';
}

String _serviceCatalogueErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final message = error.toString().replaceFirst('ApiError:', '').trim();
  if (message.isNotEmpty) return message;

  return 'Service catalogue is unavailable right now. Please try again.';
}
