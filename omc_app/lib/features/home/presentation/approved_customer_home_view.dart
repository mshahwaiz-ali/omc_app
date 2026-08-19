import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/providers/effective_capabilities_provider.dart';
import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../profile/data/profile_repository.dart';
import '../data/home_dashboard_repository.dart';

part 'approved_customer_home_actions.dart';
part 'approved_customer_home_service_widgets.dart';
part 'approved_customer_home_support.dart';

class ApprovedCustomerHomeView extends ConsumerWidget {
  const ApprovedCustomerHomeView({
    super.key,
    this.onOpenServices,
    this.onOpenCalculator,
    this.onOpenSupport,
    this.onOpenNotifications,
  });

  final VoidCallback? onOpenServices;
  final VoidCallback? onOpenCalculator;
  final VoidCallback? onOpenSupport;
  final VoidCallback? onOpenNotifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(homeDashboardSummaryProvider);
    final capabilities = ref.watch(effectiveCapabilitiesProvider);
    final profileAsync = ref.watch(profileSummaryProvider);
    final profileName = profileAsync.maybeWhen(
      data: (profile) => profile?.displayName.trim() ?? '',
      orElse: () => '',
    );

    Future<void> refresh() async {
      ref.invalidate(homeDashboardSummaryProvider);
      ref.invalidate(profileSummaryProvider);
      await ref.read(homeDashboardSummaryProvider.future);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: dashboardAsync.when(
          loading: () => const _CustomerHomeLoading(),
          error: (error, _) => RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 150),
              children: [
                _HomeHeader(
                  name: profileName,
                  unreadNotifications: 0,
                  onNotifications: capabilities.canViewCustomerNotifications
                      ? () => _openNotifications(context)
                      : null,
                  onProfile: () => context.push('/profile'),
                ),
                const SizedBox(height: 18),
                AppErrorState(
                  title: 'Latest status unavailable',
                  message: AppFailureClassifier.classify(
                    error,
                    fallbackTitle: 'Home unavailable',
                    fallbackMessage:
                        'Your latest OMC service status could not be loaded.',
                  ).message,
                  onRetry: () => ref.invalidate(homeDashboardSummaryProvider),
                  compact: true,
                ),
              ],
            ),
          ),
          data: (summary) => RefreshIndicator(
            onRefresh: refresh,
            child: _CustomerHomeContent(
              summary: summary,
              customerName: profileName,
              onNotifications: capabilities.canViewCustomerNotifications
                  ? () => _openNotifications(context)
                  : null,
              onProfile: () => context.push('/profile'),
              onOpenServices: onOpenServices ?? () => context.go('/services'),
              onOpenCalculator:
                  onOpenCalculator ?? () => context.push('/tax-calculator'),
              onOpenSupport: capabilities.canCreateSupportTicket
                  ? onOpenSupport ?? () => context.push('/support')
                  : null,
              onOpenDocuments: capabilities.canViewDocuments
                  ? () => context.push('/documents')
                  : null,
              onOpenPayments: capabilities.canViewPayments
                  ? () => context.push('/payments')
                  : null,
              onTrackServices: capabilities.canTrackRequests
                  ? () => context.go('/my-services')
                  : null,
              canStartService: capabilities.canCreateServiceRequest,
            ),
          ),
        ),
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    if (onOpenNotifications != null) {
      onOpenNotifications!();
      return;
    }
    context.push('/notifications');
  }
}

class _CustomerHomeContent extends StatelessWidget {
  const _CustomerHomeContent({
    required this.summary,
    required this.customerName,
    required this.onNotifications,
    required this.onProfile,
    required this.onOpenServices,
    required this.onOpenCalculator,
    required this.onOpenSupport,
    required this.onOpenDocuments,
    required this.onOpenPayments,
    required this.onTrackServices,
    required this.canStartService,
  });

  final HomeDashboardSummary summary;
  final String customerName;
  final VoidCallback? onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onOpenServices;
  final VoidCallback onOpenCalculator;
  final VoidCallback? onOpenSupport;
  final VoidCallback? onOpenDocuments;
  final VoidCallback? onOpenPayments;
  final VoidCallback? onTrackServices;
  final bool canStartService;

  @override
  Widget build(BuildContext context) {
    final current = summary.serviceSnapshots.isEmpty
        ? null
        : summary.serviceSnapshots.first;
    final otherServices = summary.serviceSnapshots.length <= 1
        ? const <HomeDashboardServiceSnapshot>[]
        : summary.serviceSnapshots.skip(1).take(2).toList(growable: false);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 150),
      children: [
        _HomeHeader(
          name: customerName,
          unreadNotifications: summary.unreadNotifications,
          onNotifications: onNotifications,
          onProfile: onProfile,
        ),
        const SizedBox(height: 20),
        if (current != null)
          _CurrentServiceCard(service: current)
        else
          _NoActiveServiceCard(
            completedCases: summary.completedCases,
            onStartService: canStartService ? onOpenServices : null,
          ),
        const SizedBox(height: 16),
        _AtAGlance(summary: summary),
        if (otherServices.isNotEmpty) ...[
          const SizedBox(height: 24),
          OmcSectionHeader(
            title: 'Other active services',
            actionLabel: onTrackServices == null ? null : 'View all',
            onAction: onTrackServices,
          ),
          const SizedBox(height: 10),
          for (final service in otherServices) ...[
            _CompactServiceCard(service: service),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 24),
        const OmcSectionHeader(title: 'Quick actions'),
        const SizedBox(height: 12),
        _QuickActions(
          onTrackServices: onTrackServices,
          onOpenDocuments: onOpenDocuments,
          onOpenPayments: onOpenPayments,
          onOpenSupport: onOpenSupport,
          onOpenServices: canStartService ? onOpenServices : null,
        ),
        const SizedBox(height: 24),
        const OmcSectionHeader(title: 'Explore OMC'),
        const SizedBox(height: 12),
        _ExploreCard(
          onOpenServices: onOpenServices,
          onOpenCalculator: onOpenCalculator,
        ),
      ],
    );
  }
}
