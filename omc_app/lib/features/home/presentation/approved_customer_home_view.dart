import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/design_tokens.dart';
import '../../../app/providers/effective_capabilities_provider.dart';
import '../../../app/route_access_policy.dart';
import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../profile/data/profile_repository.dart';
import '../data/home_content.dart';
import '../data/home_content_repository.dart';
import '../data/home_dashboard_repository.dart';
import 'widgets/home_content_rail.dart';
import 'widgets/home_featured_carousel.dart';

part 'approved_customer_home_actions.dart';
part 'approved_customer_home_content.dart';
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
    final homeContentAsync = ref.watch(homeContentProvider);
    final capabilities = ref.watch(effectiveCapabilitiesProvider);
    final profileAsync = ref.watch(profileSummaryProvider);
    final profileName = profileAsync.maybeWhen(
      data: (profile) => profile?.displayName.trim() ?? '',
      orElse: () => '',
    );

    Future<void> refresh() async {
      ref.invalidate(homeDashboardSummaryProvider);
      ref.invalidate(homeContentProvider);
      ref.invalidate(profileSummaryProvider);
      await ref.read(homeDashboardSummaryProvider.future);
    }

    void pushAllowed(String rawRoute) {
      final route = rawRoute.startsWith('/') ? rawRoute : '/$rawRoute';
      if (!canAccessRoute(route, capabilities)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('This item is not available for your account.'),
            ),
          );
        return;
      }
      context.push(route);
    }

    void openHomeContent(HomeContentCard item) {
      final mobileRoute = item.mobileRoute?.trim();
      if (mobileRoute != null && mobileRoute.isNotEmpty) {
        pushAllowed(mobileRoute);
        return;
      }

      final id = item.id.trim();
      if (id.isEmpty) return;
      pushAllowed('/knowledge/${Uri.encodeComponent(id)}');
    }

    void openHomeBanner(HomeBanner banner) {
      final target = banner.action.target.trim();
      if (target.isEmpty) return;

      switch (banner.action.type) {
        case HomeBannerActionType.none:
          return;
        case HomeBannerActionType.route:
          pushAllowed(target);
          return;
        case HomeBannerActionType.knowledgeArticle:
          pushAllowed('/knowledge/${Uri.encodeComponent(target)}');
          return;
        case HomeBannerActionType.service:
          pushAllowed('/services/${Uri.encodeComponent(target)}');
          return;
        case HomeBannerActionType.externalUrl:
          final uri = Uri.tryParse(target);
          if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          return;
      }
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
              homeContentAsync: homeContentAsync,
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
              onBannerTap: openHomeBanner,
              onContentTap: openHomeContent,
              onRetryHomeContent: () => ref.invalidate(homeContentProvider),
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
    required this.homeContentAsync,
    required this.customerName,
    required this.onNotifications,
    required this.onProfile,
    required this.onOpenServices,
    required this.onOpenCalculator,
    required this.onOpenSupport,
    required this.onOpenDocuments,
    required this.onOpenPayments,
    required this.onTrackServices,
    required this.onBannerTap,
    required this.onContentTap,
    required this.onRetryHomeContent,
    required this.canStartService,
  });

  final HomeDashboardSummary summary;
  final AsyncValue<HomeContent> homeContentAsync;
  final String customerName;
  final VoidCallback? onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onOpenServices;
  final VoidCallback onOpenCalculator;
  final VoidCallback? onOpenSupport;
  final VoidCallback? onOpenDocuments;
  final VoidCallback? onOpenPayments;
  final VoidCallback? onTrackServices;
  final ValueChanged<HomeBanner> onBannerTap;
  final ValueChanged<HomeContentCard> onContentTap;
  final VoidCallback onRetryHomeContent;
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
        else if (summary.activeCases > 0)
          _ActiveServiceCountCard(
            activeCases: summary.activeCases,
            onTrackServices: onTrackServices,
          )
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
        _CustomerHomeContentSections(
          contentAsync: homeContentAsync,
          onBannerTap: onBannerTap,
          onContentTap: onContentTap,
          onRetry: onRetryHomeContent,
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
