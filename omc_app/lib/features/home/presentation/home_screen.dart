import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
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
    final actionsAsync = ref.watch(mobileQuickActionsProvider);

    final dashboardAsync = capabilities.canViewCustomerDashboard || capabilities.canAccessInternalWorkspace
        ? ref.watch(homeDashboardSummaryProvider)
        : AsyncValue<HomeDashboardSummary>.data(
            HomeDashboardSummary.empty(
              fallbackMessage: _accessMessage(capabilities),
            ),
          );

    final profile = profileAsync.maybeWhen(data: (value) => value, orElse: () => null);
    final summary = dashboardAsync.maybeWhen(data: (value) => value, orElse: () => const HomeDashboardSummary.empty());
    final displayName = profile?.displayName ?? authState.displayName ?? _displayNameFromUserId(authState.userId);
    final avatarUrl = _resolveAvatarUrl(profile?.avatarUrl);
    final actions = _visibleActions(
      actionsAsync.maybeWhen(data: (value) => value, orElse: () => fallbackMobileQuickActions),
      capabilities.canAccessInternalWorkspace,
    );
    final showAccessBanner = capabilities.isGuest || capabilities.isPending || capabilities.isRejected;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _Backdrop()),
          SafeArea(
            child: RefreshIndicator.adaptive(
              onRefresh: () async {
                ref.invalidate(homeDashboardSummaryProvider);
                ref.invalidate(mobileQuickActionsProvider);
                ref.invalidate(profileSummaryProvider);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: _TopHeader(
                        displayName: displayName,
                        avatarUrl: avatarUrl,
                        unreadNotifications: summary.unreadNotifications,
                        onNotifications: () => _openNotifications(context, capabilities, onOpenNotifications),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: _SearchBar(onTap: () => context.push('/services')),
                    ),
                  ),
                  if (showAccessBanner)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _AccessBanner(
                          capabilities: capabilities,
                          onPrimary: () => _goProfile(context, capabilities),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _HeroCard(
                        displayName: displayName,
                        summary: summary,
                        capabilities: capabilities,
                        avatarUrl: avatarUrl,
                        onPrimary: () => _openNext(context, summary, capabilities, onOpenServices),
                        onSecondary: () => _openCalculator(context, onOpenCalculator),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: _SectionTitle(
                        title: 'Quick actions',
                        actionLabel: 'View all',
                        onTap: () => context.go('/more'),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: _QuickActionsRow(
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
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: _SectionTitle(
                        title: 'At a glance',
                        actionLabel: summary.serviceSnapshots.isEmpty ? null : 'Track',
                        onTap: summary.serviceSnapshots.isEmpty
                            ? null
                            : () => _goAllowed(
                                context: context,
                                route: '/my-services',
                                capabilities: capabilities,
                                requiredCapability: 'can_track_requests',
                              ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.28,
                      ),
                      delegate: SliverChildListDelegate.fixed(
                        _metricCards(summary).map((item) => _MetricCard(item: item)).toList(growable: false),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: _SectionTitle(
                        title: summary.serviceSnapshots.isEmpty ? 'Start something new' : 'Your services',
                        actionLabel: summary.serviceSnapshots.isEmpty ? null : 'View all',
                        onTap: summary.serviceSnapshots.isEmpty
                            ? null
                            : () => _goAllowed(
                                context: context,
                                route: '/my-services',
                                capabilities: capabilities,
                                requiredCapability: 'can_track_requests',
                              ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: _ServicesPanel(
                        services: summary.serviceSnapshots,
                        onOpen: (service) => _goAllowed(
                          context: context,
                          route: '/my-services/${Uri.encodeComponent(service.id)}',
                          capabilities: capabilities,
                          requiredCapability: 'can_track_requests',
                        ),
                        onBrowse: onOpenServices,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: _SectionTitle(
                        title: 'Recent activity',
                        actionLabel: 'Track',
                        onTap: () => _goAllowed(
                          context: context,
                          route: '/my-services',
                          capabilities: capabilities,
                          requiredCapability: 'can_track_requests',
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                    sliver: SliverToBoxAdapter(
                      child: _ActivityPanel(
                        activities: summary.recentActivity.take(4).toList(growable: false),
                        onTrack: () => _goAllowed(
                          context: context,
                          route: '/my-services',
                          capabilities: capabilities,
                          requiredCapability: 'can_track_requests',
                        ),
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
  }

  List<MobileQuickAction> _visibleActions(List<MobileQuickAction> source, bool allowInternal) {
    final filtered = source
        .where((action) => action.title.trim().isNotEmpty)
        .where((action) => allowInternal || action.requiredCapability != 'can_manage_customers')
        .toList(growable: false);

    filtered.sort((left, right) {
      final byOrder = left.sortOrder.compareTo(right.sortOrder);
      if (byOrder != 0) return byOrder;
      return left.title.compareTo(right.title);
    });

    return filtered.take(6).toList(growable: false);
  }

  List<_MetricItem> _metricCards(HomeDashboardSummary summary) {
    return [
      _MetricItem(
        label: 'Active services',
        value: summary.activeCases,
        icon: Icons.work_outline_rounded,
        accent: const Color(0xFF4F8DFD),
        hint: 'Live cases',
      ),
      _MetricItem(
        label: 'Documents',
        value: summary.pendingDocuments,
        icon: Icons.description_outlined,
        accent: const Color(0xFF17B890),
        hint: 'Pending review',
      ),
      _MetricItem(
        label: 'Payments due',
        value: summary.paymentsDue,
        icon: Icons.payments_outlined,
        accent: const Color(0xFFF59E0B),
        hint: 'Action needed',
      ),
      _MetricItem(
        label: 'Notifications',
        value: summary.unreadNotifications,
        icon: Icons.notifications_none_rounded,
        accent: const Color(0xFF8B5CF6),
        hint: 'Unread',
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
        context.push(action.targetValue.startsWith('/') ? action.targetValue : '/services');
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

  void _openNext(
    BuildContext context,
    HomeDashboardSummary summary,
    AuthCapabilities capabilities,
    VoidCallback? onOpenServices,
  ) {
    final nextAction = summary.nextAction;
    if (nextAction != null && nextAction.route.trim().isNotEmpty) {
      _goAllowed(
        context: context,
        route: nextAction.route,
        capabilities: capabilities,
        requiredCapability: _routeCapability(nextAction.route),
      );
      return;
    }

    final callback = onOpenServices;
    if (callback != null) {
      callback();
    } else {
      context.go('/services');
    }
  }

  void _openCalculator(BuildContext context, VoidCallback? callback) {
    if (callback != null) {
      callback();
      return;
    }
    context.push('/tax-calculator');
  }

  void _openNotifications(BuildContext context, AuthCapabilities capabilities, VoidCallback? callback) {
    final allowed = capabilities.canViewCustomerNotifications || capabilities.isApproved || capabilities.isInternal || capabilities.canAccessInternalWorkspace;
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

  void _showLockedSnack(BuildContext context, AuthCapabilities capabilities) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_accessMessage(capabilities)),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _accessMessage(AuthCapabilities capabilities) {
    if (capabilities.isGuest) return 'Please sign in or create an account to unlock this area.';
    if (capabilities.isPending) return 'Your account is under review. Full access will unlock after approval.';
    if (capabilities.isRejected) return 'This account is not approved for that action.';
    return 'This account does not have access to that area.';
  }

  String _displayNameFromUserId(String? userId) {
    if (userId == null || userId.trim().isEmpty) return 'there';
    final base = userId.contains('@') ? userId.split('@').first : userId;
    return base
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

  String? _resolveAvatarUrl(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    if (text.startsWith('http://') || text.startsWith('https://')) return text;
    return text.startsWith('/') ? '${ApiConfig.baseUrl}$text' : '${ApiConfig.baseUrl}/$text';
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFF5F7FC), Color(0xFFF7F8FB)],
          ),
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({
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
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _Badge(label: 'Workspace live', icon: Icons.bolt_rounded),
                  _Badge(label: 'Fast access', icon: Icons.flash_on_rounded),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _HeaderIconButton(unreadNotifications: unreadNotifications, onTap: onNotifications),
        const SizedBox(width: 10),
        _AvatarBadge(avatarUrl: avatarUrl, name: displayName),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.unreadNotifications, required this.onTap});

  final int unreadNotifications;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.notifications_none_rounded, size: 22, color: AppTheme.textPrimary),
            ),
            if (unreadNotifications > 0)
              Positioned(
                right: 7,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    unreadNotifications > 9 ? '9+' : unreadNotifications.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
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

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.avatarUrl, required this.name});

  final String? avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: ClipOval(
        child: avatarUrl == null
            ? Container(
                color: const Color(0xFFF3F4F6),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                ),
              )
            : Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFF3F4F6),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((part) => part.isNotEmpty).toList(growable: false);
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryRed),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
        ],
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
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.border),
            boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 18, offset: Offset(0, 8))],
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Search services, documents, invoices...',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.cardSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tune_rounded, size: 18, color: AppTheme.textPrimary),
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
    final tone = capabilities.isPending
        ? const Color(0xFFF59E0B)
        : capabilities.isRejected
            ? const Color(0xFFDC2626)
            : const Color(0xFF4F8DFD);

    final title = capabilities.isRejected
        ? 'Profile blocked'
        : capabilities.isPending
            ? 'Profile under review'
            : 'Guest access';
    final message = capabilities.isRejected
        ? 'Please contact OMC support for manual review.'
        : 'You can explore public services. Full access unlocks after approval.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(capabilities.isRejected ? Icons.block_rounded : Icons.verified_outlined, color: tone),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: tone,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              minimumSize: const Size(0, 0),
            ),
            onPressed: onPrimary,
            child: const Text('View status'),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.displayName,
    required this.summary,
    required this.capabilities,
    required this.avatarUrl,
    required this.onPrimary,
    required this.onSecondary,
  });

  final String displayName;
  final HomeDashboardSummary summary;
  final AuthCapabilities capabilities;
  final String? avatarUrl;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final nextAction = summary.nextAction;
    final heroTitle = nextAction?.title ?? 'Start with OMC';
    final heroSubtitle = nextAction?.subtitle ?? summary.fallbackMessage ?? 'Explore services, track progress, and keep the workspace moving.';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFFC81D32)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x220F172A), blurRadius: 28, offset: Offset(0, 16))],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -48,
            right: -10,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -56,
            left: -26,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                      ),
                      child: Text(
                        capabilities.isGuest
                            ? 'Guest workspace'
                            : capabilities.isPending
                                ? 'Under review'
                                : capabilities.isRejected
                                    ? 'Action restricted'
                                    : 'Priority workspace',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),
                    if (avatarUrl != null) _AvatarMini(url: avatarUrl!) else const _AvatarMiniFallback(),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Good to see you,', style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  heroTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  heroSubtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _HeroStat(label: 'Active', value: summary.activeCases.toString()),
                    _HeroStat(label: 'Docs', value: summary.pendingDocuments.toString()),
                    _HeroStat(label: 'Payments', value: summary.paymentsDue.toString()),
                    _HeroStat(label: 'Alerts', value: summary.unreadNotifications.toString()),
                  ],
                ),
                if ((summary.fallbackMessage ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    child: Text(
                      summary.fallbackMessage!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.84),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryRed,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        onPressed: onPrimary,
                        child: Text(nextAction?.buttonLabel.trim().isNotEmpty == true ? nextAction!.buttonLabel : 'Continue'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.32)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        onPressed: onSecondary,
                        child: const Text('Tax calculator'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarMini extends StatelessWidget {
  const _AvatarMini({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(url, fit: BoxFit.cover),
    );
  }
}

class _AvatarMiniFallback extends StatelessWidget {
  const _AvatarMiniFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1.2),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel, this.onTap});

  final String title;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryRed,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _MetricItem {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.hint,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color accent;
  final String hint;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.item});

  final _MetricItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: item.accent, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.hint,
                  style: TextStyle(
                    color: item.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.value.toString(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.actions, required this.capabilities, required this.onTap});

  final List<MobileQuickAction> actions;
  final AuthCapabilities capabilities;
  final ValueChanged<MobileQuickAction> onTap;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox(
        height: 124,
        child: Center(
          child: Text(
            'No quick actions available yet.',
            style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return SizedBox(
      height: 136,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final action = actions[index];
          final allowed = _isAllowed(action, capabilities);
          return _ActionCard(action: action, allowed: allowed, onTap: () => onTap(action));
        },
      ),
    );
  }

  bool _isAllowed(MobileQuickAction action, AuthCapabilities capabilities) {
    final required = action.requiredCapability?.trim();
    if (required == null || required.isEmpty) return true;
    return switch (required) {
      'can_view_documents' => capabilities.canViewDocuments || capabilities.isApproved || capabilities.isInternal,
      'can_track_requests' => capabilities.canTrackRequests || capabilities.canViewCustomerDashboard || capabilities.canAccessCustomerDashboard || capabilities.isApproved || capabilities.canAccessInternalWorkspace,
      'can_view_payments' => capabilities.canViewPayments || capabilities.canReviewPayments || capabilities.isApproved || capabilities.isInternal,
      'can_create_support_ticket' => capabilities.canCreateSupportTicket || capabilities.isApproved || capabilities.isInternal,
      'can_use_tax_calculator' => capabilities.canUseTaxCalculator,
      'can_access_internal_workspace' => capabilities.canAccessInternalWorkspace,
      _ => true,
    };
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, required this.allowed, required this.onTap});

  final MobileQuickAction action;
  final bool allowed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForAction(action);
    final background = switch (action.style) {
      MobileQuickActionStyle.highlighted => palette.soft,
      MobileQuickActionStyle.urgent => const Color(0xFFFFF4F5),
      _ => Colors.white,
    };

    return Opacity(
      opacity: allowed ? 1 : 0.56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 112,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: allowed ? palette.border : AppTheme.border),
              boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.soft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(8.5),
                  child: SvgPicture.asset(action.iconAsset, fit: BoxFit.contain),
                ),
                const Spacer(),
                Text(
                  action.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  action.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _ActionPill(label: allowed ? 'Open' : 'Locked', color: allowed ? palette.accent : AppTheme.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActionPalette {
  const _ActionPalette({required this.accent, required this.soft, required this.border});

  final Color accent;
  final Color soft;
  final Color border;
}

_ActionPalette _paletteForAction(MobileQuickAction action) {
  final key = action.iconKey.trim().toLowerCase();
  if (key.contains('document')) {
    return const _ActionPalette(
      accent: Color(0xFF4F8DFD),
      soft: Color(0xFFF0F6FF),
      border: Color(0xFFD9E7FF),
    );
  }
  if (key.contains('track')) {
    return const _ActionPalette(
      accent: Color(0xFF17B890),
      soft: Color(0xFFF0FBF8),
      border: Color(0xFFD7F4EC),
    );
  }
  if (key.contains('calc')) {
    return const _ActionPalette(
      accent: Color(0xFFF59E0B),
      soft: Color(0xFFFFF8EC),
      border: Color(0xFFFFE6B7),
    );
  }
  if (key.contains('support')) {
    return const _ActionPalette(
      accent: Color(0xFF8B5CF6),
      soft: Color(0xFFF7F2FF),
      border: Color(0xFFE5D9FF),
    );
  }
  if (key.contains('payment')) {
    return const _ActionPalette(
      accent: Color(0xFFEC4899),
      soft: Color(0xFFFFF0F7),
      border: Color(0xFFF9D7E8),
    );
  }
  return const _ActionPalette(
    accent: AppTheme.primaryRed,
    soft: Color(0xFFFDEEEF),
    border: Color(0xFFF7D4D9),
  );
}

class _ServicesPanel extends StatelessWidget {
  const _ServicesPanel({required this.services, required this.onOpen, required this.onBrowse});

  final List<HomeDashboardServiceSnapshot> services;
  final ValueChanged<HomeDashboardServiceSnapshot> onOpen;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border),
          boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFFDEEEF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.inbox_outlined, color: AppTheme.primaryRed, size: 28),
            ),
            const SizedBox(height: 14),
            const Text(
              'No active service yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Browse the catalogue and start from a clean flow instead of jumping through clutter.',
              style: TextStyle(fontSize: 12.5, height: 1.35, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onBrowse,
              child: const Text('Browse services'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < services.take(3).length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          _ServiceCard(service: services[index], onTap: () => onOpen(services[index])),
        ],
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onTap});

  final HomeDashboardServiceSnapshot service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(service.status);
    final progress = (service.progress * 100).round().clamp(0, 100);
    final subtitle = service.customerName.trim().isNotEmpty ? service.customerName : 'Ongoing case';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.border),
            boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 8))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_statusIcon(service.status), color: color, size: 20),
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
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ActionPill(label: _statusLabel(service.status), color: color),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: service.progress.clamp(0, 1),
                  backgroundColor: AppTheme.cardSoft,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '$progress% complete',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.textSecondary),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.activities, required this.onTrack});

  final List<HomeDashboardActivity> activities;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border),
          boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: const Text(
          'Recent activity will appear here once services start moving.',
          style: TextStyle(fontSize: 12.5, height: 1.35, color: AppTheme.textSecondary),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        children: [
          for (var index = 0; index < activities.length; index++) ...[
            if (index > 0) const Divider(height: 1, thickness: 1, color: AppTheme.border),
            _ActivityRow(activity: activities[index]),
          ],
          const Divider(height: 1, thickness: 1, color: AppTheme.border),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTrack,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.timeline_rounded, color: AppTheme.primaryRed, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Open full tracking view',
                      style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppTheme.primaryRed),
                ],
              ),
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
    final color = _activityColor(activity.status);
    final icon = _activityIcon(activity.status);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.subtitle,
                  style: const TextStyle(fontSize: 12.5, height: 1.35, color: AppTheme.textSecondary),
                ),
                if ((activity.createdAtLabel ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    activity.createdAtLabel!,
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized.contains('in progress')) return const Color(0xFF4F8DFD);
  if (normalized.contains('under review')) return const Color(0xFF17B890);
  if (normalized.contains('information')) return const Color(0xFFF59E0B);
  if (normalized.contains('completed')) return const Color(0xFF10B981);
  if (normalized.contains('pending')) return const Color(0xFF8B5CF6);
  return AppTheme.primaryRed;
}

String _statusLabel(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized.isEmpty) return 'Open';
  if (normalized.contains('in progress')) return 'In progress';
  if (normalized.contains('under review')) return 'Review';
  if (normalized.contains('information')) return 'Action';
  if (normalized.contains('completed')) return 'Done';
  if (normalized.contains('pending')) return 'Pending';
  return status;
}

IconData _statusIcon(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized.contains('in progress')) return Icons.trending_up_rounded;
  if (normalized.contains('under review')) return Icons.visibility_outlined;
  if (normalized.contains('information')) return Icons.info_outline_rounded;
  if (normalized.contains('completed')) return Icons.check_circle_outline_rounded;
  if (normalized.contains('pending')) return Icons.hourglass_bottom_rounded;
  return Icons.work_outline_rounded;
}

Color _activityColor(String? status) {
  final normalized = (status ?? '').trim().toLowerCase();
  if (normalized.contains('verified') || normalized.contains('approved') || normalized.contains('done')) {
    return const Color(0xFF10B981);
  }
  if (normalized.contains('review')) return const Color(0xFF4F8DFD);
  if (normalized.contains('required') || normalized.contains('information')) return const Color(0xFFF59E0B);
  if (normalized.contains('pending')) return const Color(0xFF8B5CF6);
  return AppTheme.primaryRed;
}

IconData _activityIcon(String? status) {
  final normalized = (status ?? '').trim().toLowerCase();
  if (normalized.contains('verified') || normalized.contains('approved') || normalized.contains('done')) return Icons.check_circle_rounded;
  if (normalized.contains('review')) return Icons.visibility_rounded;
  if (normalized.contains('required') || normalized.contains('information')) return Icons.priority_high_rounded;
  if (normalized.contains('pending')) return Icons.hourglass_top_rounded;
  return Icons.circle_rounded;
}
