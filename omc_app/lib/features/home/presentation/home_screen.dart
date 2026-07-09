import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../content/data/app_content_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/home_dashboard_repository.dart';
import '../data/mobile_quick_actions_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
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
    final authState = ref.watch(authControllerProvider);
    final capabilities = authState.capabilities;
    final profileSummary = ref.watch(profileSummaryProvider);
    final bannersAsync = ref.watch(appBannersProvider);
    final actionsAsync = ref.watch(mobileQuickActionsProvider);
    final canLoadDashboard =
        capabilities.canViewCustomerDashboard ||
        capabilities.canAccessInternalWorkspace;
    final dashboardAsync = canLoadDashboard
        ? ref.watch(homeDashboardSummaryProvider)
        : AsyncValue<HomeDashboardSummary>.data(
            HomeDashboardSummary.empty(
              fallbackMessage: _lockedAccessMessage(capabilities),
            ),
          );

    final summary = dashboardAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const HomeDashboardSummary.empty(
        fallbackMessage: 'Dashboard summary is loading right now.',
      ),
    );
    final displayName =
        profileSummary.maybeWhen(
          data: (profile) => profile?.displayName,
          orElse: () => null,
        ) ??
        authState.displayName ??
        _displayNameFromUserId(authState.userId);
    final isInternal = capabilities.canAccessInternalWorkspace;
    final actions = _actionsForHome(
      actionsAsync.maybeWhen(
        data: (value) => value,
        orElse: () => fallbackMobileQuickActions,
      ),
      isInternal,
    );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          onRefresh: () async {
            ref.invalidate(homeDashboardSummaryProvider);
            ref.invalidate(mobileQuickActionsProvider);
            ref.invalidate(appBannersProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: isInternal
                ? _internalSlivers(
                    context,
                    displayName,
                    summary,
                    actions,
                    capabilities,
                  )
                : _customerSlivers(
                    context,
                    displayName,
                    summary,
                    actions,
                    bannersAsync,
                    capabilities,
                  ),
          ),
        ),
      ),
    );
  }

  List<Widget> _customerSlivers(
    BuildContext context,
    String displayName,
    HomeDashboardSummary summary,
    List<MobileQuickAction> actions,
    AsyncValue<List<AppBannerItem>> bannersAsync,
    AuthCapabilities capabilities,
  ) {
    return [
      _SliverBlock(
        top: 18,
        child: _HomeHeader(
          title: _greeting(displayName),
          subtitle: 'Your OMC command center',
          badge: _accessLabel(capabilities),
          unreadNotifications: summary.unreadNotifications,
          onOpenNotifications: () => _openNotifications(context, capabilities),
        ),
      ),
      if (capabilities.isGuest ||
          capabilities.isPending ||
          capabilities.isRejected)
        _SliverBlock(child: _AccessBanner(capabilities: capabilities)),
      _SliverBlock(
        child: _HeroCard(
          label:
              summary.nextAction?.type.replaceAll('_', ' ') ??
              _accessLabel(capabilities),
          title: _customerHeroTitle(summary, capabilities),
          subtitle: _customerHeroSubtitle(summary, capabilities),
          buttonLabel:
              summary.nextAction?.buttonLabel ??
              _customerHeroButton(capabilities),
          statValue: summary.activeCases.toString(),
          statLabel: 'active',
          onPressed: () {
            final route = summary.nextAction?.route;
            if (route != null && route.trim().isNotEmpty) {
              _goWithCapability(
                context,
                route,
                capabilities,
                _routeCapability(route),
              );
            } else {
              onOpenServices?.call();
            }
          },
        ),
      ),
      _SliverBlock(
        child: _ActionRequiredCard(
          summary: summary,
          onDocuments: () => _goWithCapability(
            context,
            '/documents',
            capabilities,
            'can_view_documents',
          ),
          onPayments: () => _goWithCapability(
            context,
            '/payments',
            capabilities,
            'can_view_payments',
          ),
          onSupport: () => _goWithCapability(
            context,
            '/support',
            capabilities,
            'can_create_support_ticket',
          ),
        ),
      ),
      _SliverBlock(
        child: _BackendBannersSection(
          bannersAsync: bannersAsync,
          onTap: (banner) => _handleBannerTap(context, banner),
        ),
      ),
      _MetricRail(items: _customerMetrics(summary)),
      _Section(
        title: 'Quick actions',
        actionText: 'View all',
        onAction: () => context.go('/more'),
      ),
      _SliverBlock(
        child: _QuickActionsGrid(
          actions: actions,
          summary: summary,
          onTap: (action) => _handleQuickAction(context, action, capabilities),
        ),
      ),
      _Section(
        title: summary.serviceSnapshots.isEmpty
            ? 'Start with OMC'
            : 'Service progress',
        actionText: summary.serviceSnapshots.isEmpty ? null : 'Track',
        onAction: summary.serviceSnapshots.isEmpty
            ? null
            : () => _goWithCapability(
                context,
                '/my-services',
                capabilities,
                'can_track_requests',
              ),
      ),
      _SliverBlock(
        child: _ServiceSnapshots(
          services: summary.serviceSnapshots,
          emptyTitle: 'No active service yet',
          emptySubtitle: 'Browse services or use the tax calculator to start.',
          onOpen: (service) => _goWithCapability(
            context,
            '/my-services/${Uri.encodeComponent(service.id)}',
            capabilities,
            'can_track_requests',
          ),
          onEmptyAction: onOpenServices,
        ),
      ),
      if (summary.fallbackMessage != null)
        _SliverBlock(child: _FallbackNote(message: summary.fallbackMessage!)),
      _Section(
        title: 'Recent activity',
        actionText: 'Track',
        onAction: () => _goWithCapability(
          context,
          '/my-services',
          capabilities,
          'can_track_requests',
        ),
      ),
      _SliverBlock(
        bottom: 34,
        child: _RecentActivityCard(
          activities: summary.recentActivity.take(3).toList(growable: false),
          onTrack: () => _goWithCapability(
            context,
            '/my-services',
            capabilities,
            'can_track_requests',
          ),
        ),
      ),
    ];
  }

  List<Widget> _internalSlivers(
    BuildContext context,
    String displayName,
    HomeDashboardSummary summary,
    List<MobileQuickAction> actions,
    AuthCapabilities capabilities,
  ) {
    return [
      _SliverBlock(
        top: 18,
        child: _HomeHeader(
          title: 'Operations Center',
          subtitle: displayName,
          badge:
              capabilities.canReviewDocuments || capabilities.canReviewPayments
              ? 'Reviewer'
              : 'Internal',
          unreadNotifications: summary.unreadNotifications,
          onOpenNotifications: () => _openNotifications(context, capabilities),
        ),
      ),
      _SliverBlock(
        child: _HeroCard(
          label: 'internal',
          title: summary.nextAction?.title ?? 'Operations queue is ready',
          subtitle:
              summary.nextAction?.subtitle ??
              'Review services, documents, payments and customer queues.',
          buttonLabel: summary.nextAction?.buttonLabel ?? 'Open workspace',
          statValue: summary.pendingDocuments.toString(),
          statLabel: 'docs',
          onPressed: () =>
              context.go(summary.nextAction?.route ?? '/internal-workspace'),
        ),
      ),
      _Section(title: 'Operations KPIs'),
      _SliverBlock(child: _InternalKpiGrid(summary: summary)),
      _Section(
        title: 'Priority queue',
        actionText: 'Open all',
        onAction: () => context.go('/internal-workspace/service-cases'),
      ),
      _SliverBlock(
        child: _ServiceSnapshots(
          services: summary.serviceSnapshots,
          emptyTitle: 'No urgent service cases',
          emptySubtitle: 'The visible internal queue is clear right now.',
          internal: true,
          onOpen: (service) => context.go(
            '/internal-workspace/service-cases/${Uri.encodeComponent(service.id)}',
          ),
        ),
      ),
      _Section(title: 'Internal quick actions'),
      _SliverBlock(
        child: _QuickActionsGrid(
          actions: actions,
          summary: summary,
          onTap: (action) => _handleQuickAction(context, action, capabilities),
        ),
      ),
      if (summary.fallbackMessage != null)
        _SliverBlock(child: _FallbackNote(message: summary.fallbackMessage!)),
      _Section(title: 'Recent activity'),
      _SliverBlock(
        bottom: 34,
        child: _RecentActivityCard(
          activities: summary.recentActivity.take(4).toList(growable: false),
          onTrack: () => context.go('/internal-workspace/service-cases'),
        ),
      ),
    ];
  }

  List<MobileQuickAction> _actionsForHome(
    List<MobileQuickAction> actions,
    bool isInternal,
  ) {
    final sorted = [...actions]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (isInternal) {
      final hasInternal = sorted.any(
        (a) =>
            a.targetValue.startsWith('/internal-workspace') ||
            a.requiredCapability == 'can_access_internal_workspace',
      );
      return hasInternal ? sorted : _fallbackInternalActions;
    }
    return (sorted.isEmpty ? fallbackMobileQuickActions : sorted)
        .take(6)
        .toList(growable: false);
  }

  void _openNotifications(BuildContext context, AuthCapabilities capabilities) {
    if (_capabilityAllowed('can_view_customer_notifications', capabilities)) {
      onOpenNotifications?.call();
    } else {
      _showLockedSnack(context, capabilities);
    }
  }

  void _handleQuickAction(
    BuildContext context,
    MobileQuickAction action,
    AuthCapabilities capabilities,
  ) {
    if (!_capabilityAllowed(action.requiredCapability, capabilities)) {
      _showLockedSnack(context, capabilities);
      return;
    }
    switch (action.targetType) {
      case MobileQuickActionTargetType.feature:
        _handleFeatureTarget(context, action.targetValue, capabilities);
        return;
      case MobileQuickActionTargetType.route:
        final route = action.targetValue.trim();
        route.isEmpty
            ? onOpenServices?.call()
            : context.go(route.startsWith('/') ? route : '/$route');
        return;
      case MobileQuickActionTargetType.service:
        final serviceId = action.targetValue.trim();
        serviceId.isEmpty
            ? onOpenServices?.call()
            : context.go('/services/${Uri.encodeComponent(serviceId)}');
        return;
      case MobileQuickActionTargetType.externalUrl:
        final uri = _safeExternalUri(action.targetValue);
        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
    }
  }

  void _handleFeatureTarget(
    BuildContext context,
    String target,
    AuthCapabilities capabilities,
  ) {
    switch (target.trim().toLowerCase().replaceAll('_', '-')) {
      case 'services':
      case 'service':
      case 'tax-return':
      case 'ntn':
      case 'gst':
        onOpenServices?.call();
        return;
      case 'calculator':
      case 'tax-calculator':
        onOpenCalculator?.call();
        return;
      case 'support':
        _capabilityAllowed('can_create_support_ticket', capabilities)
            ? onOpenSupport?.call()
            : _showLockedSnack(context, capabilities);
        return;
      case 'documents':
        _goWithCapability(
          context,
          '/documents',
          capabilities,
          'can_view_documents',
        );
        return;
      case 'payments':
        _goWithCapability(
          context,
          '/payments',
          capabilities,
          'can_view_payments',
        );
        return;
      case 'track':
      case 'my-services':
        _goWithCapability(
          context,
          '/my-services',
          capabilities,
          'can_track_requests',
        );
        return;
      case 'knowledge':
        context.go('/knowledge');
        return;
      case 'expense-tracker':
      case 'expenses':
        context.go('/expense-tracker');
        return;
      default:
        onOpenServices?.call();
    }
  }

  void _goWithCapability(
    BuildContext context,
    String route,
    AuthCapabilities capabilities,
    String? capability,
  ) {
    if (!_capabilityAllowed(capability, capabilities)) {
      _showLockedSnack(context, capabilities);
      return;
    }
    context.go(route);
  }

  bool _capabilityAllowed(String? capability, AuthCapabilities capabilities) {
    if (capability == null || capability.trim().isEmpty) return true;
    return switch (capability.trim()) {
      'can_create_service_request' => capabilities.canCreateServiceRequest,
      'can_track_requests' =>
        capabilities.canTrackRequests ||
            capabilities.canAccessInternalWorkspace,
      'can_view_documents' =>
        capabilities.canViewDocuments || capabilities.canReviewDocuments,
      'can_view_payments' =>
        capabilities.canViewPayments || capabilities.canReviewPayments,
      'can_create_support_ticket' => capabilities.canCreateSupportTicket,
      'can_view_support_tickets' => capabilities.canViewSupportTickets,
      'can_use_tax_calculator' => capabilities.canUseTaxCalculator,
      'can_view_customer_notifications' =>
        capabilities.canViewCustomerNotifications ||
            capabilities.canAccessInternalWorkspace,
      'can_access_internal_workspace' =>
        capabilities.canAccessInternalWorkspace,
      _ => true,
    };
  }

  void _handleBannerTap(BuildContext context, AppBannerItem banner) {
    final target = banner.actionUrl?.trim();
    if (target == null || target.isEmpty) return;
    if (target.startsWith('/')) {
      context.go(target);
      return;
    }
    final uri = _safeExternalUri(target);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(target), behavior: SnackBarBehavior.floating),
        );
    }
  }

  Uri? _safeExternalUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) return null;
    return uri.scheme == 'https' || uri.scheme == 'http' ? uri : null;
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
      return 'Please sign in or create an account to use this service.';
    }
    if (capabilities.isPending) {
      return 'Your account is under review. OMC team will verify your profile before enabling service access.';
    }
    if (capabilities.isRejected) {
      return 'This account is not approved for this action. Please contact OMC support.';
    }
    return 'This account does not have access to that area.';
  }

  String _displayNameFromUserId(String? userId) {
    final value = userId?.trim();
    if (value == null || value.isEmpty) return 'OMC Customer';
    final cleaned = value
        .split('@')
        .first
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .trim();
    if (cleaned.isEmpty) return value;
    return cleaned
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _greeting(String name) {
    final hour = DateTime.now().hour;
    final prefix = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return '$prefix, $name';
  }

  String _accessLabel(AuthCapabilities capabilities) {
    if (capabilities.isGuest) return 'Guest';
    if (capabilities.isPending) return 'Pending review';
    if (capabilities.isRejected) return 'Approval required';
    return 'Approved';
  }

  String _customerHeroTitle(
    HomeDashboardSummary summary,
    AuthCapabilities capabilities,
  ) {
    final nextTitle = summary.nextAction?.title.trim();
    if (nextTitle != null && nextTitle.isNotEmpty) return nextTitle;
    if (capabilities.isGuest) return 'Start with OMC';
    if (capabilities.isPending) return 'Profile under review';
    return 'Your OMC workspace is active';
  }

  String _customerHeroSubtitle(
    HomeDashboardSummary summary,
    AuthCapabilities capabilities,
  ) {
    final nextSubtitle = summary.nextAction?.subtitle.trim();
    if (nextSubtitle != null && nextSubtitle.isNotEmpty) {
      return nextSubtitle;
    }
    if (capabilities.isGuest) {
      return 'Browse services, use the tax calculator and create an account when ready.';
    }
    if (capabilities.isPending) {
      return 'Sync, service requests and document uploads unlock after profile approval.';
    }
    return 'Track services, documents, payments and support from one place.';
  }

  String _customerHeroButton(AuthCapabilities capabilities) =>
      capabilities.isGuest || capabilities.isPending
      ? 'Browse services'
      : 'Start request';
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.unreadNotifications,
    required this.onOpenNotifications,
  });

  final String title;
  final String subtitle;
  final String badge;
  final int unreadNotifications;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          padding: const EdgeInsets.all(8),
          decoration: _softDecoration(19),
          child: Image.asset(
            'assets/images/logo_symbol_transparent.png',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.business_rounded, color: AppTheme.primaryRed),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _TextStyles.eyebrow,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TinyBadge(label: badge),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _TextStyles.pageTitle,
              ),
            ],
          ),
        ),
        _RoundIconButton(
          icon: Icons.notifications_none_rounded,
          badgeCount: unreadNotifications,
          onTap: onOpenNotifications,
        ),
      ],
    );
  }
}

class _AccessBanner extends StatelessWidget {
  const _AccessBanner({required this.capabilities});

  final AuthCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final title = capabilities.isGuest
        ? 'Guest workspace'
        : capabilities.isPending
        ? 'Profile under review'
        : 'Approval required';
    final message = capabilities.isGuest
        ? 'Local tools are available. Create an OMC account to unlock sync, requests and document uploads.'
        : capabilities.isPending
        ? 'OMC will enable protected customer features after verification.'
        : 'Contact OMC support to review this account.';
    return PremiumCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          _IconBox(
            icon: capabilities.isGuest
                ? Icons.explore_outlined
                : Icons.verified_user_outlined,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _TextStyles.cardTitle),
                const SizedBox(height: 3),
                Text(message, style: _TextStyles.cardSubtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.statValue,
    required this.statLabel,
    required this.onPressed,
  });

  final String label;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final String statValue;
  final String statLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(31),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryRed.withValues(alpha: 0.21),
            blurRadius: 34,
            offset: const Offset(0, 19),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(31),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(23),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryRed,
                Color(0xFFA3162A),
                AppTheme.darkRed,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroBadge(label: label),
              const SizedBox(height: 20),
              Text(title, style: _TextStyles.heroTitle),
              const SizedBox(height: 10),
              Text(subtitle, style: _TextStyles.heroSubtitle),
              const SizedBox(height: 23),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: onPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryRed,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(19),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                        label: Text(
                          buttonLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HeroMiniStat(value: statValue, label: statLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRequiredCard extends StatelessWidget {
  const _ActionRequiredCard({
    required this.summary,
    required this.onDocuments,
    required this.onPayments,
    required this.onSupport,
  });

  final HomeDashboardSummary summary;
  final VoidCallback onDocuments;
  final VoidCallback onPayments;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final items = <_AttentionItem>[
      if (summary.pendingDocuments > 0)
        _AttentionItem(
          Icons.upload_file_rounded,
          '${summary.pendingDocuments} documents missing',
          'Upload required files to keep service processing active.',
          'Upload',
          onDocuments,
        ),
      if (summary.paymentsDue > 0)
        _AttentionItem(
          Icons.receipt_long_rounded,
          '${summary.paymentsDue} payments due',
          'Review dues or upload receipts for verification.',
          'Review',
          onPayments,
        ),
      if (summary.paymentSummary.rejected > 0)
        _AttentionItem(
          Icons.warning_amber_rounded,
          '${summary.paymentSummary.rejected} receipts rejected',
          'Open payments and upload corrected receipts.',
          'Fix',
          onPayments,
        ),
      if (summary.supportSummary.waitingCustomer > 0)
        _AttentionItem(
          Icons.support_agent_rounded,
          '${summary.supportSummary.waitingCustomer} support replies waiting',
          'OMC needs your response on support tickets.',
          'Reply',
          onSupport,
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    final item = items.first;
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _IconBox(icon: item.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Action required', style: _TextStyles.eyebrow),
                const SizedBox(height: 4),
                Text(item.title, style: _TextStyles.cardTitle),
                const SizedBox(height: 4),
                Text(item.subtitle, style: _TextStyles.cardSubtitle),
              ],
            ),
          ),
          TextButton(onPressed: item.onTap, child: Text(item.actionLabel)),
        ],
      ),
    );
  }
}

class _BackendBannersSection extends StatelessWidget {
  const _BackendBannersSection({
    required this.bannersAsync,
    required this.onTap,
  });

  final AsyncValue<List<AppBannerItem>> bannersAsync;
  final ValueChanged<AppBannerItem> onTap;

  @override
  Widget build(BuildContext context) {
    return bannersAsync.maybeWhen(
      data: (banners) {
        final visible = [...banners]
          ..sort((a, b) => b.priority.compareTo(a.priority));
        if (visible.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _BackendBannerCard(
              banner: visible[index],
              onTap: () => onTap(visible[index]),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _BackendBannerCard extends StatelessWidget {
  const _BackendBannerCard({required this.banner, required this.onTap});

  final AppBannerItem banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolvedImageUrl(banner.imageUrl);
    return SizedBox(
      width: 286,
      child: PremiumCard(
        padding: const EdgeInsets.all(16),
        onTap: banner.actionUrl == null ? null : onTap,
        child: Row(
          children: [
            imageUrl == null
                ? const _IconBox(icon: Icons.campaign_rounded)
                : _BannerImage(url: imageUrl),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    banner.title.isEmpty ? 'OMC update' : banner.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _TextStyles.cardTitle,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    banner.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _TextStyles.cardSubtitle,
                  ),
                  if ((banner.actionLabel ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      banner.actionLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _TextStyles.linkLabel,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _resolvedImageUrl(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    if (text.startsWith('http://') || text.startsWith('https://')) return text;
    if (text.startsWith('/')) return '${ApiConfig.baseUrl}$text';
    return null;
  }
}

class _MetricRail extends StatelessWidget {
  const _MetricRail({required this.items});

  final List<_MetricItem> items;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 0, 0),
      sliver: SliverToBoxAdapter(
        child: SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(right: 20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _MetricChip(item: items[index]),
          ),
        ),
      ),
    );
  }
}

class _InternalKpiGrid extends StatelessWidget {
  const _InternalKpiGrid({required this.summary});

  final HomeDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricItem(
        'Open services',
        summary.activeCases.toString(),
        Icons.assignment_rounded,
        '/internal-workspace/service-cases',
      ),
      _MetricItem(
        'Waiting customer',
        summary.supportSummary.waitingCustomer.toString(),
        Icons.hourglass_bottom_rounded,
        '/internal-workspace/service-cases',
      ),
      _MetricItem(
        'Documents review',
        summary.documentSummary.uploaded.toString(),
        Icons.folder_special_rounded,
        '/internal-workspace/documents',
      ),
      _MetricItem(
        'Payments review',
        summary.paymentSummary.receiptUnderReview.toString(),
        Icons.payments_rounded,
        '/internal-workspace/payments',
      ),
      _MetricItem('Open leads', 'Open', Icons.leaderboard_rounded, '/leads'),
      _MetricItem('Pending tasks', 'Tasks', Icons.task_alt_rounded, '/tasks'),
      _MetricItem('Customers', 'Profiles', Icons.groups_rounded, '/customers'),
    ];
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.78,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return PremiumCard(
          padding: const EdgeInsets.all(14),
          onTap: () => context.go(item.route ?? '/internal-workspace'),
          child: Row(
            children: [
              _IconBox(icon: item.icon, size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.value, style: _TextStyles.metricValue),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _TextStyles.metricLabel,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.actions,
    required this.summary,
    required this.onTap,
  });

  final List<MobileQuickAction> actions;
  final HomeDashboardSummary summary;
  final ValueChanged<MobileQuickAction> onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(15, 17, 15, 13),
      child: GridView.builder(
        itemCount: actions.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 13,
          crossAxisSpacing: 11,
          childAspectRatio: 0.91,
        ),
        itemBuilder: (context, index) {
          final action = actions[index];
          return _ActionTile(
            action: action,
            badgeCount: _badgeCount(action.badgeType),
            onTap: () => onTap(action),
          );
        },
      ),
    );
  }

  int _badgeCount(String badgeType) {
    return switch (badgeType.trim().toLowerCase().replaceAll('_', '-')) {
      'documents' => summary.pendingDocuments,
      'payments' => summary.paymentsDue,
      'support' => summary.supportSummary.waitingCustomer,
      'notifications' => summary.unreadNotifications,
      _ => 0,
    };
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.action,
    required this.badgeCount,
    required this.onTap,
  });

  final MobileQuickAction action;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUrgent = action.style == MobileQuickActionStyle.urgent;
    final isHighlighted = action.style == MobileQuickActionStyle.highlighted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isUrgent
              ? AppTheme.primaryRed.withValues(alpha: 0.09)
              : isHighlighted
              ? AppTheme.primaryRed.withValues(alpha: 0.06)
              : const Color(0xFFF8F4F1),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isUrgent || isHighlighted
                ? AppTheme.primaryRed.withValues(alpha: 0.20)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: SvgPicture.asset(
                    action.iconAsset,
                    fit: BoxFit.contain,
                    placeholderBuilder: (_) => Icon(
                      _iconForAction(action.iconKey),
                      color: AppTheme.primaryRed,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  action.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: _TextStyles.actionTitle,
                ),
                const SizedBox(height: 3),
                Text(
                  action.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: _TextStyles.actionSubtitle,
                ),
              ],
            ),
            if (badgeCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: _CountBadge(count: badgeCount),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForAction(String key) => switch (key) {
    'documents' => Icons.folder_copy_rounded,
    'track' => Icons.timeline_rounded,
    'calculator' => Icons.calculate_rounded,
    'support' => Icons.support_agent_rounded,
    'payments' => Icons.payments_rounded,
    'knowledge' => Icons.menu_book_rounded,
    'notifications' => Icons.notifications_rounded,
    'dashboard' => Icons.dashboard_rounded,
    _ => Icons.apps_rounded,
  };
}

class _ServiceSnapshots extends StatelessWidget {
  const _ServiceSnapshots({
    required this.services,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onOpen,
    this.onEmptyAction,
    this.internal = false,
  });

  final List<HomeDashboardServiceSnapshot> services;
  final String emptyTitle;
  final String emptySubtitle;
  final ValueChanged<HomeDashboardServiceSnapshot> onOpen;
  final VoidCallback? onEmptyAction;
  final bool internal;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return PremiumCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const _IconBox(icon: Icons.inbox_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emptyTitle, style: _TextStyles.cardTitle),
                  const SizedBox(height: 4),
                  Text(emptySubtitle, style: _TextStyles.cardSubtitle),
                ],
              ),
            ),
            if (onEmptyAction != null)
              TextButton(onPressed: onEmptyAction, child: const Text('Browse')),
          ],
        ),
      );
    }
    return Column(
      children: services
          .take(internal ? 5 : 3)
          .map((service) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PremiumCard(
                padding: const EdgeInsets.all(16),
                onTap: () => onOpen(service),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            service.title.isEmpty
                                ? 'Service Request'
                                : service.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _TextStyles.cardTitle,
                          ),
                        ),
                        _StatusPill(
                          label: service.status.isEmpty
                              ? 'Open'
                              : service.status,
                        ),
                      ],
                    ),
                    if (internal && service.customerName.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        service.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _TextStyles.cardSubtitle,
                      ),
                    ],
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: service.progress <= 0 ? 0.12 : service.progress,
                        minHeight: 7,
                        backgroundColor: AppTheme.primaryRed.withValues(
                          alpha: 0.08,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryRed.withValues(alpha: 0.74),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniHealth(
                            label: 'Docs',
                            value:
                                '${service.documentSummary.approved}/${service.documentSummary.total} approved',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MiniHealth(
                            label: 'Payments',
                            value:
                                '${service.paymentSummary.paid}/${service.paymentSummary.total} paid',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.activities, required this.onTrack});

  final List<HomeDashboardActivity> activities;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(17),
      child: activities.isEmpty
          ? Row(
              children: const [
                _IconBox(icon: Icons.history_rounded),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Updates will appear here when your workspace changes.',
                    style: _TextStyles.cardSubtitle,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                for (final activity in activities) ...[
                  _ActivityRow(activity: activity),
                  if (activity != activities.last) const Divider(height: 18),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onTrack,
                    child: const Text('Open timeline'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final HomeDashboardActivity activity;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            color: AppTheme.primaryRed,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.title.isEmpty ? 'Update' : activity.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _TextStyles.actionTitle,
              ),
              if (activity.subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  activity.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _TextStyles.cardSubtitle,
                ),
              ],
              if ((activity.createdAtLabel ?? '').isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(activity.createdAtLabel!, style: _TextStyles.metricLabel),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.item});

  final _MetricItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: _softDecoration(23),
      child: Row(
        children: [
          _IconBox(icon: item.icon, size: 38, iconSize: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.value, style: _TextStyles.metricValue),
                const SizedBox(height: 5),
                Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _TextStyles.metricLabel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.actionText, this.onAction});
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
    sliver: SliverToBoxAdapter(
      child: Row(
        children: [
          Expanded(child: Text(title, style: _TextStyles.sectionTitle)),
          if (actionText != null)
            TextButton(onPressed: onAction, child: Text(actionText!)),
        ],
      ),
    ),
  );
}

class _SliverBlock extends StatelessWidget {
  const _SliverBlock({required this.child, this.top = 16, this.bottom = 0});
  final Widget child;
  final double top;
  final double bottom;
  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: EdgeInsets.fromLTRB(20, top, 20, bottom),
    sliver: SliverToBoxAdapter(child: child),
  );
}

class _BannerImage extends StatelessWidget {
  const _BannerImage({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Image.network(
      url,
      width: 52,
      height: 52,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const _IconBox(icon: Icons.campaign_rounded),
    ),
  );
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 7),
        Text(label.toUpperCase(), style: _TextStyles.whiteBadge),
      ],
    ),
  );
}

class _HeroMiniStat extends StatelessWidget {
  const _HeroMiniStat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 13),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
    ),
    child: Row(
      children: [
        const Icon(Icons.timeline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$value $label',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _TextStyles.whiteMini,
          ),
        ),
      ],
    ),
  );
}

class _MiniHealth extends StatelessWidget {
  const _MiniHealth({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFF9F3F0),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _TextStyles.metricLabel),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _TextStyles.actionTitle,
        ),
      ],
    ),
  );
}

class _FallbackNote extends StatelessWidget {
  const _FallbackNote({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => PremiumCard(
    padding: const EdgeInsets.all(13),
    child: Row(
      children: [
        const _IconBox(
          icon: Icons.info_outline_rounded,
          size: 30,
          iconSize: 17,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: _TextStyles.cardSubtitle)),
      ],
    ),
  );
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.primaryRed.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppTheme.primaryRed,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppTheme.primaryRed.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppTheme.primaryRed,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: AppTheme.primaryRed,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.badgeCount,
    required this.onTap,
  });
  final IconData icon;
  final int badgeCount;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: _softDecoration(18),
          child: Icon(icon, color: AppTheme.primaryRed),
        ),
        if (badgeCount > 0)
          Positioned(right: -3, top: -3, child: _CountBadge(count: badgeCount)),
      ],
    ),
  );
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, this.size = 44, this.iconSize = 22});
  final IconData icon;
  final double size;
  final double iconSize;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppTheme.primaryRed.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(size * 0.36),
    ),
    child: Icon(icon, color: AppTheme.primaryRed, size: iconSize),
  );
}

class _AttentionItem {
  const _AttentionItem(
    this.icon,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.onTap,
  );
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;
}

class _MetricItem {
  const _MetricItem(this.label, this.value, this.icon, [this.route]);
  final String label;
  final String value;
  final IconData icon;
  final String? route;
}

BoxDecoration _softDecoration(double radius) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.045),
      blurRadius: 24,
      offset: const Offset(0, 13),
    ),
  ],
);

String? _routeCapability(String route) {
  if (route.startsWith('/documents')) return 'can_view_documents';
  if (route.startsWith('/payments')) return 'can_view_payments';
  if (route.startsWith('/my-services')) return 'can_track_requests';
  if (route.startsWith('/support')) return 'can_create_support_ticket';
  return null;
}

List<_MetricItem> _customerMetrics(HomeDashboardSummary summary) => [
  _MetricItem(
    'Active services',
    summary.activeCases.toString(),
    Icons.assignment_turned_in_rounded,
  ),
  _MetricItem(
    'Missing docs',
    summary.pendingDocuments.toString(),
    Icons.folder_copy_rounded,
  ),
  _MetricItem(
    'Payments due',
    summary.paymentsDue.toString(),
    Icons.account_balance_wallet_rounded,
  ),
  _MetricItem(
    'Support open',
    summary.supportSummary.open.toString(),
    Icons.support_agent_rounded,
  ),
];

const List<MobileQuickAction> _fallbackInternalActions = [
  MobileQuickAction(
    id: 'internal-service-cases',
    title: 'Cases',
    subtitle: 'Services',
    iconKey: 'dashboard',
    targetType: MobileQuickActionTargetType.route,
    targetValue: '/internal-workspace/service-cases',
    requiredCapability: 'can_access_internal_workspace',
    sortOrder: 10,
  ),
  MobileQuickAction(
    id: 'internal-documents',
    title: 'Documents',
    subtitle: 'Review',
    iconKey: 'documents',
    targetType: MobileQuickActionTargetType.route,
    targetValue: '/internal-workspace/documents',
    requiredCapability: 'can_access_internal_workspace',
    badgeType: 'documents',
    sortOrder: 20,
  ),
  MobileQuickAction(
    id: 'internal-payments',
    title: 'Payments',
    subtitle: 'Review',
    iconKey: 'payments',
    targetType: MobileQuickActionTargetType.route,
    targetValue: '/internal-workspace/payments',
    requiredCapability: 'can_access_internal_workspace',
    badgeType: 'payments',
    sortOrder: 30,
  ),
  MobileQuickAction(
    id: 'internal-leads',
    title: 'Leads',
    subtitle: 'Pipeline',
    iconKey: 'services',
    targetType: MobileQuickActionTargetType.route,
    targetValue: '/leads',
    requiredCapability: 'can_access_internal_workspace',
    sortOrder: 40,
  ),
  MobileQuickAction(
    id: 'internal-tasks',
    title: 'Tasks',
    subtitle: 'Pending',
    iconKey: 'track',
    targetType: MobileQuickActionTargetType.route,
    targetValue: '/tasks',
    requiredCapability: 'can_access_internal_workspace',
    sortOrder: 50,
  ),
  MobileQuickAction(
    id: 'internal-customers',
    title: 'Customers',
    subtitle: 'Profiles',
    iconKey: 'message',
    targetType: MobileQuickActionTargetType.route,
    targetValue: '/customers',
    requiredCapability: 'can_access_internal_workspace',
    sortOrder: 60,
  ),
];

abstract final class _TextStyles {
  static const eyebrow = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
  );
  static const pageTitle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 22,
    height: 1.05,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
  );
  static const heroTitle = TextStyle(
    color: Colors.white,
    fontSize: 25,
    height: 1.06,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.8,
  );
  static const heroSubtitle = TextStyle(
    color: Colors.white70,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w600,
  );
  static const whiteMini = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w800,
  );
  static const whiteBadge = TextStyle(
    color: Colors.white,
    fontSize: 11,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.4,
  );
  static const sectionTitle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.35,
  );
  static const cardTitle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.15,
  );
  static const cardSubtitle = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 12.6,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );
  static const metricValue = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.45,
  );
  static const metricLabel = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
  );
  static const actionTitle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 12.5,
    fontWeight: FontWeight.w900,
  );
  static const actionSubtitle = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );
  static const linkLabel = TextStyle(
    color: AppTheme.primaryRed,
    fontSize: 12,
    fontWeight: FontWeight.w900,
  );
}
