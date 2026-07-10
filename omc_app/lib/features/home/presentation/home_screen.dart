import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
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
    final profileAsync = ref.watch(profileSummaryProvider);
    final bannersAsync = ref.watch(appBannersProvider);
    final actionsAsync = ref.watch(mobileQuickActionsProvider);

    final canLoadDashboard =
        capabilities.canViewCustomerDashboard || capabilities.canAccessInternalWorkspace;
    final dashboardAsync = canLoadDashboard
        ? ref.watch(homeDashboardSummaryProvider)
        : AsyncValue<HomeDashboardSummary>.data(
            HomeDashboardSummary.empty(
              fallbackMessage: _lockedAccessMessage(capabilities),
            ),
          );

    final summary = dashboardAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const HomeDashboardSummary.empty(),
    );
    final profile = profileAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final displayName = profile?.displayName ??
        authState.displayName ??
        _displayNameFromUserId(authState.userId);
    final avatarUrl = profile?.avatarUrl;
    final actions = _homeActions(
      actionsAsync.maybeWhen(
        data: (value) => value,
        orElse: () => fallbackMobileQuickActions,
      ),
      capabilities.canAccessInternalWorkspace,
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
            slivers: [
              _SliverBlock(
                top: 18,
                child: _HomeHeader(
                  displayName: displayName,
                  avatarUrl: avatarUrl,
                  unreadNotifications: summary.unreadNotifications,
                  onNotifications: () => _openNotifications(
                    context,
                    capabilities,
                    onOpenNotifications,
                  ),
                ),
              ),
              _SliverBlock(
                top: 10,
                child: _SearchBar(onTap: () => context.push('/services')),
              ),
              if (capabilities.isGuest || capabilities.isPending || capabilities.isRejected)
                _SliverBlock(
                  top: 14,
                  child: _AccessBanner(
                    capabilities: capabilities,
                    onPrimary: () => _goProfile(context, capabilities),
                  ),
                ),
              _SliverBlock(
                top: 14,
                child: _HeroCard(
                  summary: summary,
                  capabilities: capabilities,
                  onPrimary: () {
                    final route = summary.nextAction?.route;
                    if (route != null && route.trim().isNotEmpty) {
                      _goAllowed(
                        context: context,
                        route: route,
                        capabilities: capabilities,
                        requiredCapability: _routeCapability(route),
                      );
                      return;
                    }
                    onOpenServices?.call();
                  },
                  onSecondary: () {
                    final callback = onOpenCalculator;
                    if (callback != null) {
                      callback();
                      return;
                    }
                    context.push('/tax-calculator');
                  },
                ),
              ),
              if (bannersAsync.hasValue && bannersAsync.value!.isNotEmpty)
                _SliverBlock(
                  top: 14,
                  child: _BannerStrip(
                    banners: bannersAsync.value!,
                    onTap: (banner) => _handleBannerTap(context, banner),
                  ),
                ),
              _SectionHeader(
                title: 'Quick actions',
                actionText: 'View all',
                onAction: () => context.go('/more'),
              ),
              _SliverBlock(
                child: _QuickActionsRail(
                  actions: actions,
                  capabilities: capabilities,
                  onTap: (action) => _handleQuickAction(
                    context,
                    action,
                    capabilities,
                    onOpenServices: onOpenServices,
                    onOpenCalculator: onOpenCalculator,
                    onOpenSupport: onOpenSupport,
                  ),
                ),
              ),
              _SectionHeader(
                title: 'Today at a glance',
                actionText: summary.serviceSnapshots.isEmpty ? null : 'Track',
                onAction: summary.serviceSnapshots.isEmpty
                    ? null
                    : () => _goAllowed(
                        context: context,
                        route: '/my-services',
                        capabilities: capabilities,
                        requiredCapability: 'can_track_requests',
                      ),
              ),
              _SliverBlock(child: _MetricGrid(metrics: _buildMetrics(summary))),
              _SliverBlock(
                top: 14,
                child: _CompletionCard(
                  summary: summary,
                  capabilities: capabilities,
                  onPrimary: () => _goProfile(context, capabilities),
                ),
              ),
              _SectionHeader(
                title: summary.serviceSnapshots.isEmpty ? 'Start with OMC' : 'Your services in progress',
                actionText: summary.serviceSnapshots.isEmpty ? null : 'View all',
                onAction: summary.serviceSnapshots.isEmpty
                    ? null
                    : () => _goAllowed(
                        context: context,
                        route: '/my-services',
                        capabilities: capabilities,
                        requiredCapability: 'can_track_requests',
                      ),
              ),
              _SliverBlock(
                child: _ServiceProgressCard(
                  services: summary.serviceSnapshots,
                  emptyTitle: 'No active service yet',
                  emptySubtitle: 'Browse services or use the tax calculator to start.',
                  onOpen: (service) => _goAllowed(
                    context: context,
                    route: '/my-services/${Uri.encodeComponent(service.id)}',
                    capabilities: capabilities,
                    requiredCapability: 'can_track_requests',
                  ),
                  onEmptyAction: onOpenServices,
                ),
              ),
              _SectionHeader(
                title: 'Recent activity',
                actionText: 'Track',
                onAction: () => _goAllowed(
                  context: context,
                  route: '/my-services',
                  capabilities: capabilities,
                  requiredCapability: 'can_track_requests',
                ),
              ),
              _SliverBlock(
                bottom: 34,
                child: _ActivityTimelineCard(
                  activities: summary.recentActivity.take(4).toList(growable: false),
                  onTrack: () => _goAllowed(
                    context: context,
                    route: '/my-services',
                    capabilities: capabilities,
                    requiredCapability: 'can_track_requests',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<MobileQuickAction> _homeActions(List<MobileQuickAction> source, bool isInternal) {
    final filtered = source
        .where((action) => action.title.trim().isNotEmpty)
        .where((action) => isInternal || action.requiredCapability != 'can_manage_customers')
        .toList(growable: false);

    filtered.sort((left, right) {
      final comparison = left.sortOrder.compareTo(right.sortOrder);
      if (comparison != 0) return comparison;
      return left.title.compareTo(right.title);
    });

    return filtered.take(6).toList(growable: false);
  }

  List<_HomeMetric> _buildMetrics(HomeDashboardSummary summary) {
    return [
      _HomeMetric(
        label: 'Active services',
        value: summary.activeCases,
        icon: Icons.work_outline_rounded,
        tint: const Color(0xFF4F8DFD),
      ),
      _HomeMetric(
        label: 'Documents',
        value: summary.pendingDocuments,
        icon: Icons.description_outlined,
        tint: const Color(0xFF37B58D),
      ),
      _HomeMetric(
        label: 'Payments due',
        value: summary.paymentsDue,
        icon: Icons.payments_outlined,
        tint: const Color(0xFFF59E0B),
      ),
      _HomeMetric(
        label: 'Notifications',
        value: summary.unreadNotifications,
        icon: Icons.notifications_none_rounded,
        tint: const Color(0xFF9B6BFF),
      ),
    ];
  }

  bool _isAllowed(String capability, AuthCapabilities capabilities) {
    return switch (capability) {
      'can_view_documents' => capabilities.canViewDocuments || capabilities.isApproved || capabilities.isInternal,
      'can_track_requests' => capabilities.canTrackRequests || capabilities.canViewCustomerDashboard || capabilities.canAccessCustomerDashboard || capabilities.isApproved || capabilities.canAccessInternalWorkspace,
      'can_view_payments' => capabilities.canViewPayments || capabilities.canReviewPayments || capabilities.isApproved || capabilities.isInternal,
      'can_review_documents' => capabilities.canReviewDocuments || capabilities.canAccessInternalWorkspace,
      'can_review_payments' => capabilities.canReviewPayments || capabilities.canAccessInternalWorkspace,
      'can_create_support_ticket' => capabilities.canCreateSupportTicket || capabilities.isApproved || capabilities.isInternal,
      'can_use_tax_calculator' => capabilities.canUseTaxCalculator,
      'can_access_internal_workspace' => capabilities.canAccessInternalWorkspace,
      _ => true,
    };
  }

  bool _isActionAllowed(MobileQuickAction action, AuthCapabilities capabilities) {
    final required = action.requiredCapability?.trim();
    if (required == null || required.isEmpty) return true;
    return _isAllowed(required, capabilities);
  }

  void _handleQuickAction(
    BuildContext context,
    MobileQuickAction action,
    AuthCapabilities capabilities, {
    VoidCallback? onOpenServices,
    VoidCallback? onOpenCalculator,
    VoidCallback? onOpenSupport,
  }) {
    if (!_isActionAllowed(action, capabilities)) {
      _showLockedSnack(context, capabilities);
      return;
    }

    switch (action.targetType) {
      case MobileQuickActionTargetType.route:
        if (action.targetValue.startsWith('/')) {
          context.push(action.targetValue);
        } else {
          context.go('/services');
        }
        return;
      case MobileQuickActionTargetType.feature:
        final key = action.targetValue.trim().toLowerCase();
        if (key == 'calculator') {
          final callback = onOpenCalculator;
          if (callback != null) {
            callback();
          } else {
            context.push('/tax-calculator');
          }
          return;
        }
        if (key == 'services') {
          final callback = onOpenServices;
          if (callback != null) {
            callback();
          } else {
            context.go('/services');
          }
          return;
        }
        if (key == 'support') {
          final callback = onOpenSupport;
          if (callback != null) {
            callback();
          } else {
            context.go('/support');
          }
          return;
        }
        context.go('/services');
        return;
      case MobileQuickActionTargetType.service:
        final callback = onOpenServices;
        if (callback != null) {
          callback();
        } else {
          context.go('/services');
        }
        return;
      case MobileQuickActionTargetType.externalUrl:
        final uri = Uri.tryParse(action.targetValue);
        if (uri != null) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return;
    }
  }

  void _handleBannerTap(BuildContext context, AppBannerItem banner) {
    final actionUrl = banner.actionUrl?.trim();
    if (actionUrl == null || actionUrl.isEmpty) return;

    if (actionUrl.startsWith('/')) {
      context.push(actionUrl);
      return;
    }

    final uri = Uri.tryParse(actionUrl);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    final fallback = Uri.tryParse('${ApiConfig.baseUrl}/$actionUrl');
    if (fallback != null) {
      launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  void _goAllowed({
    required BuildContext context,
    required String route,
    required AuthCapabilities capabilities,
    required String requiredCapability,
  }) {
    if (!_isAllowed(requiredCapability, capabilities)) {
      _showLockedSnack(context, capabilities);
      return;
    }
    context.push(route);
  }

  void _goProfile(BuildContext context, AuthCapabilities capabilities) {
    if (capabilities.isGuest) {
      context.push('/signup');
    } else {
      context.push('/profile');
    }
  }

  void _openNotifications(
    BuildContext context,
    AuthCapabilities capabilities,
    VoidCallback? callback,
  ) {
    final allowed = capabilities.canViewCustomerNotifications ||
        capabilities.isApproved ||
        capabilities.isInternal ||
        capabilities.canAccessInternalWorkspace;
    if (!allowed) {
      _showLockedSnack(context, capabilities);
      return;
    }
    if (callback != null) {
      callback();
    } else {
      context.push('/notifications');
    }
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
    if (userId == null || userId.trim().isEmpty) return 'there';
    final normalized = userId.contains('@') ? userId.split('@').first : userId;
    return normalized
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _routeCapability(String route) {
    if (route.contains('/documents')) return 'can_view_documents';
    if (route.contains('/payments')) return 'can_view_payments';
    if (route.contains('/support')) return 'can_create_support_ticket';
    if (route.contains('/my-services')) return 'can_track_requests';
    if (route.contains('/tax-calculator')) return 'can_use_tax_calculator';
    return '';
  }
}

class _SliverBlock extends StatelessWidget {
  const _SliverBlock({required this.child, this.top = 0, this.bottom = 0});

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, top, 16, bottom),
      sliver: SliverToBoxAdapter(child: child),
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
    return _SliverBlock(
      top: 16,
      bottom: 12,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          if (actionText != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryRed,
                padding: EdgeInsets.zero,
              ),
              child: Text(actionText!),
            ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.displayName,
    required this.avatarUrl,
    required this.unreadNotifications,
    required this.onNotifications,
  });

  final String displayName;
  final String? avatarUrl;
  final int unreadNotifications;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isEmpty ? 'O' : displayName.trim()[0].toUpperCase();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Good morning,',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 29,
                  height: 1.06,
                  letterSpacing: -0.35,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _IconBadgeButton(
          icon: Icons.notifications_none_rounded,
          badgeCount: unreadNotifications,
          onTap: onNotifications,
        ),
        const SizedBox(width: 10),
        _AvatarBubble(avatarUrl: avatarUrl, fallbackText: initial),
      ],
    );
  }
}

class _IconBadgeButton extends StatelessWidget {
  const _IconBadgeButton({required this.icon, required this.badgeCount, required this.onTap});

  final IconData icon;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(child: Icon(icon, color: AppTheme.textPrimary, size: 23)),
              if (badgeCount > 0)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          height: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({required this.avatarUrl, required this.fallbackText});

  final String? avatarUrl;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: hasAvatar
            ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _AvatarFallback(text: fallbackText),
              )
            : _AvatarFallback(text: fallbackText),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F7FB),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Search services, documents, invoices...',
                  style: TextStyle(
                    color: Color(0xFF9AA0AA),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tune_rounded, size: 19, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessBanner extends StatelessWidget {
  const _AccessBanner({required this.capabilities, required this.onPrimary});

  final AuthCapabilities capabilities;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    late final String title;
    late final String subtitle;
    late final Color tint;
    late final IconData icon;
    late final String buttonText;

    switch (capabilities.accessState) {
      case AccountAccessState.guest:
        title = 'Create your account';
        subtitle = 'Unlock service requests, tracking, and saved progress.';
        tint = const Color(0xFF4F8DFD);
        icon = Icons.person_add_alt_1_rounded;
        buttonText = 'Sign up';
        break;
      case AccountAccessState.pending:
        title = 'Your profile is under review';
        subtitle = 'You can explore services while the team completes verification.';
        tint = const Color(0xFF4F8DFD);
        icon = Icons.verified_outlined;
        buttonText = 'View status';
        break;
      case AccountAccessState.rejected:
        title = 'Approval needed';
        subtitle = 'Contact support to review the current account access.';
        tint = const Color(0xFFE45858);
        icon = Icons.info_outline_rounded;
        buttonText = 'Support';
        break;
      case AccountAccessState.approved:
      case AccountAccessState.internal:
        title = 'Access notice';
        subtitle = 'Some features remain restricted on this account.';
        tint = const Color(0xFF4F8DFD);
        icon = Icons.info_outline_rounded;
        buttonText = 'Continue';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: tint, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          TextButton(
            onPressed: onPrimary,
            style: TextButton.styleFrom(
              foregroundColor: tint,
              backgroundColor: Colors.white.withValues(alpha: 0.95),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: tint.withValues(alpha: 0.18)),
              ),
            ),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.summary,
    required this.capabilities,
    required this.onPrimary,
    required this.onSecondary,
  });

  final HomeDashboardSummary summary;
  final AuthCapabilities capabilities;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final heroLabel = _heroLabel(summary, capabilities);
    final heroTitle = _heroTitle(summary, capabilities);
    final heroSubtitle = _heroSubtitle(summary, capabilities);
    final buttonLabel = summary.nextAction?.buttonLabel.trim().isNotEmpty == true
        ? summary.nextAction!.buttonLabel
        : (capabilities.canTrackRequests ? 'Open tracker' : 'Explore services');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDFDFE), Color(0xFFF7F8FC)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HeroBadge(label: heroLabel, tint: const Color(0xFF4F8DFD)),
              const Spacer(),
              _MiniStat(label: 'Active', value: summary.activeCases.toString()),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            heroTitle,
            style: const TextStyle(
              fontSize: 24,
              height: 1.12,
              letterSpacing: -0.35,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            heroSubtitle,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onPrimary,
                  child: Text(buttonLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onSecondary,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Tax calculator'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _heroLabel(HomeDashboardSummary summary, AuthCapabilities capabilities) {
    final nextActionType = summary.nextAction?.type.trim();
    if (nextActionType != null && nextActionType.isNotEmpty) {
      return nextActionType.replaceAll('_', ' ');
    }
    if (capabilities.isGuest) return 'guest mode';
    if (capabilities.isPending) return 'profile review';
    return 'command center';
  }

  String _heroTitle(HomeDashboardSummary summary, AuthCapabilities capabilities) {
    final title = summary.nextAction?.title.trim();
    if (title != null && title.isNotEmpty) return title;
    if (capabilities.isGuest) return 'Welcome to OMC';
    if (capabilities.isPending) return 'Your profile is being reviewed';
    if (summary.serviceSnapshots.isNotEmpty) return 'Your work is moving';
    return 'Everything in one place';
  }

  String _heroSubtitle(HomeDashboardSummary summary, AuthCapabilities capabilities) {
    final subtitle = summary.nextAction?.subtitle.trim();
    if (subtitle != null && subtitle.isNotEmpty) return subtitle;
    if (capabilities.isGuest) {
      return 'Browse services, understand the process, and create an account whenever you are ready.';
    }
    if (capabilities.isPending) {
      return 'Track progress, prepare documents, and keep momentum while approval is underway.';
    }
    if (summary.serviceSnapshots.isNotEmpty) {
      return 'Follow active cases, review important alerts, and jump into the next action fast.';
    }
    return 'Services, documents, payments, support, and tracking designed as one clean workspace.';
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label, required this.tint});

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tint,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerStrip extends StatelessWidget {
  const _BannerStrip({required this.banners, required this.onTap});

  final List<AppBannerItem> banners;
  final ValueChanged<AppBannerItem> onTap;

  @override
  Widget build(BuildContext context) {
    final banner = banners.first;
    return GestureDetector(
      onTap: () => onTap(banner),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7FB),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.campaign_outlined, color: AppTheme.textMuted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    banner.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsRail extends StatelessWidget {
  const _QuickActionsRail({
    required this.actions,
    required this.capabilities,
    required this.onTap,
  });

  final List<MobileQuickAction> actions;
  final AuthCapabilities capabilities;
  final ValueChanged<MobileQuickAction> onTap;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: actions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final action = actions[index];
          final tint = _tintForAction(action);
          return _QuickActionCard(
            action: action,
            tint: tint,
            disabled: !_isActionAllowed(action, capabilities),
            onTap: () => onTap(action),
          );
        },
      ),
    );
  }

  bool _isActionAllowed(MobileQuickAction action, AuthCapabilities capabilities) {
    final capability = action.requiredCapability?.trim();
    if (capability == null || capability.isEmpty) return true;
    return switch (capability) {
      'can_view_documents' => capabilities.canViewDocuments || capabilities.isApproved || capabilities.isInternal,
      'can_track_requests' => capabilities.canTrackRequests || capabilities.canViewCustomerDashboard || capabilities.canAccessCustomerDashboard || capabilities.isApproved || capabilities.canAccessInternalWorkspace,
      'can_view_payments' => capabilities.canViewPayments || capabilities.canReviewPayments || capabilities.isApproved || capabilities.isInternal,
      'can_create_support_ticket' => capabilities.canCreateSupportTicket || capabilities.isApproved || capabilities.isInternal,
      'can_use_tax_calculator' => capabilities.canUseTaxCalculator,
      'can_access_internal_workspace' => capabilities.canAccessInternalWorkspace,
      _ => true,
    };
  }

  Color _tintForAction(MobileQuickAction action) {
    switch (action.iconKey.toLowerCase()) {
      case 'documents':
      case 'track':
        return const Color(0xFF4F8DFD);
      case 'tax-return':
      case 'gst':
      case 'calculator':
        return const Color(0xFFF59E0B);
      case 'support':
      case 'message':
        return const Color(0xFF9B6BFF);
      case 'notifications':
        return const Color(0xFFE45858);
      default:
        return const Color(0xFF37B58D);
    }
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.action,
    required this.tint,
    required this.disabled,
    required this.onTap,
  });

  final MobileQuickAction action;
  final Color tint;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedOpacity(
          opacity: disabled ? 0.55 : 1,
          duration: const Duration(milliseconds: 160),
          child: Container(
            width: 108,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      action.iconAsset,
                      width: 22,
                      height: 22,
                      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  action.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    height: 1.15,
                  ),
                ),
                if (action.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    action.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_HomeMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 118,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, index) => _MetricCard(metric: metrics[index]),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _HomeMetric metric;

  @override
  Widget build(BuildContext context) {
    final progressValue = metric.value <= 0
        ? 0.08
        : ((metric.value.clamp(0, 999) / 10).clamp(0.08, 0.95)).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: metric.tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(metric.icon, color: metric.tint, size: 19),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
            ],
          ),
          const Spacer(),
          Text(
            metric.label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.value.toString(),
            style: const TextStyle(
              fontSize: 28,
              height: 1,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 5,
              backgroundColor: metric.tint.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(metric.tint),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({
    required this.summary,
    required this.capabilities,
    required this.onPrimary,
  });

  final HomeDashboardSummary summary;
  final AuthCapabilities capabilities;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final isComplete = summary.documentSummary.total > 0 &&
        summary.documentSummary.missing == 0 &&
        summary.paymentSummary.pending == 0;
    final title = isComplete ? 'Profile and documents look good' : 'Complete your profile';
    final subtitle = isComplete
        ? 'Your workspace is synced and ready for the next step.'
        : capabilities.isGuest
            ? 'Create your account to unlock syncing, tracking, and saved progress.'
            : 'Finish a few details to get smoother access across the app.';
    final buttonLabel = isComplete
        ? 'Open profile'
        : (capabilities.isGuest ? 'Create account' : 'Complete now');
    final tint = isComplete ? const Color(0xFF37B58D) : const Color(0xFF4F8DFD);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isComplete ? Icons.verified_rounded : Icons.badge_outlined,
              color: tint,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          TextButton(
            onPressed: onPrimary,
            style: TextButton.styleFrom(
              foregroundColor: tint,
              backgroundColor: Colors.white.withValues(alpha: 0.95),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: tint.withValues(alpha: 0.18)),
              ),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _ServiceProgressCard extends StatelessWidget {
  const _ServiceProgressCard({
    required this.services,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onOpen,
    required this.onEmptyAction,
  });

  final List<HomeDashboardServiceSnapshot> services;
  final String emptyTitle;
  final String emptySubtitle;
  final ValueChanged<HomeDashboardServiceSnapshot> onOpen;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7FB),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.folder_open_rounded, color: AppTheme.textMuted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emptyTitle,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    emptySubtitle,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton(onPressed: onEmptyAction, child: const Text('Browse')),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < services.length; index++)
            _ServiceRow(
              service: services[index],
              onTap: () => onOpen(services[index]),
              showDivider: index != services.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.onTap,
    required this.showDivider,
  });

  final HomeDashboardServiceSnapshot service;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tint = _statusTint(service.status);
    final progress = service.progress.clamp(0.0, 1.0).toDouble();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.work_outline_rounded, color: tint, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service.customerName.isNotEmpty
                            ? 'Applied by ${service.customerName}'
                            : 'Applied by your team',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StatusChip(text: _statusLabel(service.status), tint: tint),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: tint.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation<Color>(tint),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(progress * 100).round()}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
              ],
            ),
            if (showDivider) ...[
              const SizedBox(height: 14),
              Divider(height: 1, color: AppTheme.border.withValues(alpha: 0.8)),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusTint(String status) {
    switch (status.trim().toLowerCase()) {
      case 'under review':
      case 'pending':
      case 'information required':
        return const Color(0xFFF59E0B);
      case 'approved':
      case 'completed':
      case 'paid':
        return const Color(0xFF37B58D);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFE45858);
      default:
        return const Color(0xFF4F8DFD);
    }
  }

  String _statusLabel(String status) {
    final value = status.trim();
    return value.isEmpty ? 'In progress' : value;
  }
}

class _ActivityTimelineCard extends StatelessWidget {
  const _ActivityTimelineCard({required this.activities, required this.onTrack});

  final List<HomeDashboardActivity> activities;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.timeline_rounded, color: AppTheme.textMuted),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No recent activity yet.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(onPressed: onTrack, child: const Text('Track')),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < activities.length; index++)
            _ActivityRow(
              activity: activities[index],
              showDivider: index != activities.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, required this.showDivider});

  final HomeDashboardActivity activity;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tint = _tintForActivity(activity.status);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_iconForActivity(activity.status), color: tint, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title.isNotEmpty ? activity.title : activity.subtitle,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activity.subtitle,
                      style: const TextStyle(
                        fontSize: 12.8,
                        height: 1.35,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (activity.createdAtLabel?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        activity.createdAtLabel!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted.withValues(alpha: 0.8)),
            ],
          ),
          if (showDivider) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: AppTheme.border.withValues(alpha: 0.8)),
          ],
        ],
      ),
    );
  }

  Color _tintForActivity(String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'verified':
      case 'approved':
      case 'completed':
        return const Color(0xFF37B58D);
      case 'under review':
      case 'pending':
        return const Color(0xFF4F8DFD);
      case 'needs information':
      case 'information required':
        return const Color(0xFFF59E0B);
      case 'rejected':
        return const Color(0xFFE45858);
      default:
        return const Color(0xFF9B6BFF);
    }
  }

  IconData _iconForActivity(String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'verified':
      case 'approved':
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'under review':
      case 'pending':
        return Icons.pending_actions_rounded;
      case 'needs information':
      case 'information required':
        return Icons.info_outline_rounded;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.receipt_long_rounded;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.tint});

  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: tint,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HomeMetric {
  const _HomeMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color tint;
}
