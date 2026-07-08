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

  static const List<_WorkspaceAction> _workspaceActions = [
    _WorkspaceAction(
      title: 'My Services',
      subtitle: 'Track active cases and request status',
      icon: Icons.assignment_outlined,
      route: '/my-services',
      capability: 'can_track_requests',
    ),
    _WorkspaceAction(
      title: 'Payments',
      subtitle: 'Review invoices and pending dues',
      icon: Icons.account_balance_wallet_outlined,
      route: '/payments',
      capability: 'can_view_payments',
    ),
    _WorkspaceAction(
      title: 'Knowledge',
      subtitle: 'Guides, updates and tax information',
      icon: Icons.menu_book_outlined,
      route: '/knowledge',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final capabilities = authState.capabilities;
    final profileSummary = ref.watch(profileSummaryProvider);
    final appBanners = ref.watch(appBannersProvider);
    final quickActionsAsync = ref.watch(mobileQuickActionsProvider);
    final canLoadDashboard =
        capabilities.canViewCustomerDashboard ||
        capabilities.canAccessInternalWorkspace;
    final dashboardSummary = canLoadDashboard
        ? ref.watch(homeDashboardSummaryProvider)
        : AsyncValue<HomeDashboardSummary>.data(
            HomeDashboardSummary.empty(
              fallbackMessage: _lockedAccessMessage(capabilities),
            ),
          );
    final summary = dashboardSummary.maybeWhen(
      data: (summary) => summary,
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
    final quickActions = quickActionsAsync.maybeWhen(
      data: (actions) {
        final sorted = [...actions]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return sorted.isEmpty ? fallbackMobileQuickActions : sorted;
      },
      orElse: () => fallbackMobileQuickActions,
    );

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _HomeHeader(
                  displayName: displayName,
                  unreadNotifications: summary.unreadNotifications,
                  onOpenNotifications: () {
                    if (_capabilityAllowed(
                      'can_view_customer_notifications',
                      capabilities,
                    )) {
                      onOpenNotifications?.call();
                      return;
                    }
                    _showLockedSnack(context, capabilities);
                  },
                ),
              ),
            ),
            if (capabilities.isGuest ||
                capabilities.isPending ||
                capabilities.isRejected)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _HomeAccessBanner(capabilities: capabilities),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _HeroCard(
                  activeCases: summary.activeCases,
                  onStartRequest: onOpenServices,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _BackendBannersSection(
                  bannersAsync: appBanners,
                  onTap: (banner) => _handleBannerTap(context, banner),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 0, 0),
              sliver: SliverToBoxAdapter(
                child: _StatusScroller(items: _statusItemsFromSummary(summary)),
              ),
            ),
            if (summary.fallbackMessage != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _DashboardFallbackNote(message: summary.fallbackMessage!),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Quick Actions',
                  actionText: 'View all',
                  onAction: onOpenServices,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              sliver: SliverToBoxAdapter(
                child: _QuickActionLauncher(
                  actions: quickActions,
                  summary: summary,
                  onTap: (action) => _handleQuickAction(
                    context,
                    action,
                    capabilities,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  title: summary.activeCases > 0
                      ? 'Current Progress'
                      : 'Start with OMC',
                  actionText: summary.activeCases > 0 ? 'Track' : null,
                  onAction: summary.activeCases > 0
                      ? () => _goWithCapability(
                            context,
                            '/my-services',
                            capabilities,
                            'can_track_requests',
                          )
                      : null,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              sliver: SliverToBoxAdapter(
                child: _ProgressCard(
                  summary: summary,
                  onStartRequest: onOpenServices,
                  onTrack: () => _goWithCapability(
                    context,
                    '/my-services',
                    capabilities,
                    'can_track_requests',
                  ),
                ),
              ),
            ),
            if (summary.pendingDocuments > 0 || summary.paymentsDue > 0)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                sliver: SliverToBoxAdapter(
                  child: _AttentionCard(
                    pendingDocuments: summary.pendingDocuments,
                    paymentsDue: summary.paymentsDue,
                    onOpenDocuments: () => _goWithCapability(
                      context,
                      '/documents',
                      capabilities,
                      'can_view_documents',
                    ),
                    onOpenPayments: () => _goWithCapability(
                      context,
                      '/payments',
                      capabilities,
                      'can_view_payments',
                    ),
                  ),
                ),
              ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              sliver: SliverToBoxAdapter(child: _SectionHeader(title: 'Workspace')),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              sliver: SliverToBoxAdapter(
                child: _WorkspaceList(
                  actions: _workspaceActions,
                  onTap: (action) => _goWithCapability(
                    context,
                    action.route,
                    capabilities,
                    action.capability,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Recent Activity',
                  actionText: 'Track',
                  onAction: () => _goWithCapability(
                    context,
                    '/my-services',
                    capabilities,
                    'can_track_requests',
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
              sliver: SliverToBoxAdapter(
                child: _RecentActivityCard(
                  activities: summary.recentActivity,
                  onTrack: () => _goWithCapability(
                    context,
                    '/my-services',
                    capabilities,
                    'can_track_requests',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_StatusItem> _statusItemsFromSummary(HomeDashboardSummary summary) {
    return [
      _StatusItem(
        label: 'Active Services',
        value: summary.activeCases.toString(),
        icon: Icons.assignment_turned_in_rounded,
      ),
      _StatusItem(
        label: 'Documents',
        value: summary.pendingDocuments.toString(),
        icon: Icons.folder_copy_rounded,
      ),
      _StatusItem(
        label: 'Payments Due',
        value: summary.paymentsDue.toString(),
        icon: Icons.account_balance_wallet_rounded,
      ),
      _StatusItem(
        label: 'Alerts',
        value: summary.unreadNotifications.toString(),
        icon: Icons.notifications_active_rounded,
      ),
    ];
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
        if (route.isEmpty) {
          onOpenServices?.call();
          return;
        }
        context.go(route.startsWith('/') ? route : '/$route');
        return;
      case MobileQuickActionTargetType.service:
        final serviceId = action.targetValue.trim();
        if (serviceId.isEmpty) {
          onOpenServices?.call();
          return;
        }
        context.go('/services/${Uri.encodeComponent(serviceId)}');
        return;
      case MobileQuickActionTargetType.externalUrl:
        final uri = _safeExternalUri(action.targetValue);
        if (uri != null) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
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
        if (!_capabilityAllowed('can_create_support_ticket', capabilities)) {
          _showLockedSnack(context, capabilities);
          return;
        }
        onOpenSupport?.call();
        return;
      case 'documents':
        _goWithCapability(context, '/documents', capabilities, 'can_view_documents');
        return;
      case 'payments':
        _goWithCapability(context, '/payments', capabilities, 'can_view_payments');
        return;
      case 'track':
      case 'my-services':
        _goWithCapability(context, '/my-services', capabilities, 'can_track_requests');
        return;
      case 'knowledge':
        context.go('/knowledge');
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
        capabilities.canTrackRequests || capabilities.canAccessInternalWorkspace,
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
      'can_access_internal_workspace' => capabilities.canAccessInternalWorkspace,
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
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(target), behavior: SnackBarBehavior.floating),
      );
  }

  Uri? _safeExternalUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    return uri;
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
    final localPart = value.split('@').first;
    final cleaned = localPart.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (cleaned.isEmpty) return value;
    return cleaned
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.displayName,
    required this.onOpenNotifications,
    required this.unreadNotifications,
  });

  final String displayName;
  final VoidCallback? onOpenNotifications;
  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 24,
                offset: const Offset(0, 11),
              ),
            ],
          ),
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
              const Text('Welcome back', style: _TextStyles.eyebrow),
              const SizedBox(height: 3),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _TextStyles.pageTitle,
              ),
            ],
          ),
        ),
        _RoundIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          badgeCount: unreadNotifications,
          onTap: onOpenNotifications,
        ),
      ],
    );
  }
}

class _HomeAccessBanner extends StatelessWidget {
  const _HomeAccessBanner({required this.capabilities});

  final AuthCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final (icon, title, message) = switch (capabilities.accessState) {
      AccountAccessState.guest => (
        Icons.explore_outlined,
        'Guest mode',
        'Browse services and tax resources. Sign in to request services and upload documents.',
      ),
      AccountAccessState.pending => (
        Icons.hourglass_top_rounded,
        'Account under review',
        'Protected actions will unlock after OMC approves your profile.',
      ),
      AccountAccessState.rejected => (
        Icons.block_rounded,
        'Approval required',
        'This account cannot access protected services yet.',
      ),
      _ => (
        Icons.verified_user_outlined,
        'Approved access',
        'Protected services are enabled.',
      ),
    };

    return PremiumCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          _IconBox(icon: icon),
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
  const _HeroCard({required this.activeCases, required this.onStartRequest});

  final int activeCases;
  final VoidCallback? onStartRequest;

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
              colors: [AppTheme.primaryRed, Color(0xFFA3162A), AppTheme.darkRed],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HeroBadge(),
              const SizedBox(height: 21),
              const Text(
                'Your tax and business services, organized.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.06,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Submit requests, upload documents and track every update from one place.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 23),
              Row(
                children: [
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: onStartRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryRed,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 19),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(19),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'Start Request',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _HeroMiniStat(activeCases: activeCases)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackendBannersSection extends StatelessWidget {
  const _BackendBannersSection({required this.bannersAsync, required this.onTap});

  final AsyncValue<List<AppBannerItem>> bannersAsync;
  final ValueChanged<AppBannerItem> onTap;

  @override
  Widget build(BuildContext context) {
    return bannersAsync.maybeWhen(
      data: (banners) {
        final visible = [...banners]..sort((a, b) => b.priority.compareTo(a.priority));
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
            if (imageUrl == null)
              _IconBox(icon: Icons.campaign_rounded)
            else
              _BannerImage(url: imageUrl),
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

class _BannerImage extends StatelessWidget {
  const _BannerImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _IconBox(icon: Icons.campaign_rounded),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth.isFinite && constraints.maxWidth < 155;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 11, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
              if (!compact) ...[
                const SizedBox(width: 7),
                const Flexible(
                  child: Text(
                    'OMC Premium Workspace',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HeroMiniStat extends StatelessWidget {
  const _HeroMiniStat({required this.activeCases});

  final int activeCases;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              '$activeCases active',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusScroller extends StatelessWidget {
  const _StatusScroller({required this.items});

  final List<_StatusItem> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(right: 20),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _StatusChip(item: items[index]),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.item});

  final _StatusItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 146,
      padding: const EdgeInsets.all(14),
      decoration: _softCardDecoration(radius: 23),
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

class _DashboardFallbackNote extends StatelessWidget {
  const _DashboardFallbackNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          _IconBox(icon: Icons.info_outline_rounded, size: 30, iconSize: 17),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: _TextStyles.cardSubtitle)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionText, this.onAction});

  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: _TextStyles.sectionTitle)),
        if (actionText != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryRed,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
            child: Text(actionText!),
          ),
      ],
    );
  }
}

class _QuickActionLauncher extends StatelessWidget {
  const _QuickActionLauncher({
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
          return _LogoActionTile(
            action: action,
            badgeCount: _badgeCount(action.badgeType, summary),
            onTap: () => onTap(action),
          );
        },
      ),
    );
  }

  int _badgeCount(String badgeType, HomeDashboardSummary summary) {
    return switch (badgeType.trim().toLowerCase().replaceAll('_', '-')) {
      'documents' => summary.pendingDocuments,
      'payments' => summary.paymentsDue,
      'notifications' => summary.unreadNotifications,
      _ => 0,
    };
  }
}

class _LogoActionTile extends StatelessWidget {
  const _LogoActionTile({
    required this.action,
    required this.onTap,
    required this.badgeCount,
  });

  final MobileQuickAction action;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final isUrgent = action.style == MobileQuickActionStyle.urgent;
    final isHighlighted = action.style == MobileQuickActionStyle.highlighted || isUrgent;
    return Material(
      color: isHighlighted
          ? AppTheme.primaryRed.withValues(alpha: isUrgent ? 0.12 : 0.08)
          : AppTheme.primaryRed.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _SvgIconBox(asset: action.iconAsset, solid: isHighlighted),
                  if (badgeCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: _CountBadge(count: badgeCount),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                action.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: _TextStyles.actionTitle,
              ),
              const SizedBox(height: 2),
              Text(
                action.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: _TextStyles.actionSubtitle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SvgIconBox extends StatelessWidget {
  const _SvgIconBox({required this.asset, this.solid = false});

  final String asset;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: solid ? AppTheme.primaryRed : Colors.white,
        borderRadius: BorderRadius.circular(19),
        boxShadow: solid
            ? null
            : [
                BoxShadow(
                  color: AppTheme.primaryRed.withValues(alpha: 0.06),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: SvgPicture.asset(
        asset,
        colorFilter: ColorFilter.mode(
          solid ? Colors.white : AppTheme.primaryRed,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.pendingDocuments,
    required this.paymentsDue,
    required this.onOpenDocuments,
    required this.onOpenPayments,
  });

  final int pendingDocuments;
  final int paymentsDue;
  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenPayments;

  @override
  Widget build(BuildContext context) {
    final hasDocuments = pendingDocuments > 0;
    return _SimpleActionCard(
      title: hasDocuments ? 'Documents needed' : 'Payment pending',
      subtitle: hasDocuments
          ? '$pendingDocuments document(s) required for your active request.'
          : '$paymentsDue payment item(s) need your review.',
      icon: hasDocuments ? Icons.folder_copy_rounded : Icons.account_balance_wallet_rounded,
      onTap: hasDocuments ? onOpenDocuments : onOpenPayments,
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.summary,
    required this.onStartRequest,
    required this.onTrack,
  });

  final HomeDashboardSummary summary;
  final VoidCallback? onStartRequest;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final hasActiveCase = summary.activeCases > 0;
    return _SimpleActionCard(
      title: hasActiveCase ? 'Service work is in progress' : 'No active service yet',
      subtitle: hasActiveCase
          ? '${summary.activeCases} active case(s) currently being tracked.'
          : 'Start a request and your service progress will appear here.',
      icon: hasActiveCase ? Icons.track_changes_rounded : Icons.add_task_rounded,
      onTap: hasActiveCase ? onTrack : onStartRequest,
      progressValue: hasActiveCase ? 0.62 : null,
    );
  }
}

class _WorkspaceList extends StatelessWidget {
  const _WorkspaceList({required this.actions, required this.onTap});

  final List<_WorkspaceAction> actions;
  final ValueChanged<_WorkspaceAction> onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int index = 0; index < actions.length; index++) ...[
            _WorkspaceTile(action: actions[index], onTap: () => onTap(actions[index])),
            if (index != actions.length - 1)
              const Divider(height: 1, indent: 76, endIndent: 18),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({required this.action, required this.onTap});

  final _WorkspaceAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(
          children: [
            _IconBox(icon: action.icon, size: 42, iconSize: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action.title, style: _TextStyles.cardTitle),
                  const SizedBox(height: 4),
                  Text(action.subtitle, style: _TextStyles.cardSubtitle),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.activities, required this.onTrack});

  final List<HomeDashboardActivity> activities;
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    final latestActivity = activities.isNotEmpty ? activities.first : null;
    return _SimpleActionCard(
      title: latestActivity?.title ?? 'No live case activity yet',
      subtitle: latestActivity == null
          ? 'Submitted requests and status updates stay here.'
          : latestActivity.subtitle.isNotEmpty
              ? latestActivity.subtitle
              : latestActivity.createdAtLabel ?? 'Latest update',
      icon: Icons.history_rounded,
      onTap: onTrack,
      footer: activities.length > 1 ? '+${activities.length - 1} more update(s)' : null,
    );
  }
}

class _SimpleActionCard extends StatelessWidget {
  const _SimpleActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.progressValue,
    this.footer,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final double? progressValue;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(19),
      onTap: onTap,
      child: Row(
        children: [
          _IconBox(icon: icon, size: 54, iconSize: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _TextStyles.cardTitle),
                const SizedBox(height: 6),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: _TextStyles.cardSubtitle),
                if (progressValue != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: progressValue,
                      backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.10),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryRed),
                    ),
                  ),
                ],
                if (footer != null) ...[
                  const SizedBox(height: 8),
                  Text(footer!, style: _TextStyles.linkLabel),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: AppTheme.primaryRed, size: 23),
                if (badgeCount > 0)
                  Positioned(top: 9, right: 9, child: _CountDot()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    this.size = 40,
    this.iconSize = 21,
    this.solid = false,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: solid ? AppTheme.primaryRed : AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(size * 0.38),
      ),
      child: Icon(icon, color: solid ? Colors.white : AppTheme.primaryRed, size: iconSize),
    );
  }
}

BoxDecoration _softCardDecoration({required double radius}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.045)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.032),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

class _TextStyles {
  static const eyebrow = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w800,
  );

  static const pageTitle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 21,
    fontWeight: FontWeight.w900,
    height: 1.05,
    letterSpacing: -0.4,
  );

  static const sectionTitle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 21,
    fontWeight: FontWeight.w900,
    height: 1.05,
    letterSpacing: -0.45,
  );

  static const cardTitle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w900,
  );

  static const cardSubtitle = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );

  static const metricValue = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 19,
    fontWeight: FontWeight.w900,
    height: 1,
  );

  static const metricLabel = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 11,
    height: 1.15,
    fontWeight: FontWeight.w700,
  );

  static const actionTitle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 12.5,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.2,
  );

  static const actionSubtitle = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
  );

  static const linkLabel = TextStyle(
    color: AppTheme.primaryRed,
    fontSize: 11.5,
    fontWeight: FontWeight.w900,
  );
}

class _WorkspaceAction {
  const _WorkspaceAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.capability,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final String? capability;
}

class _StatusItem {
  const _StatusItem({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;
}
