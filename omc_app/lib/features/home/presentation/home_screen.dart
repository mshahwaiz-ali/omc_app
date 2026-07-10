import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            HomeDashboardSummary.empty(fallbackMessage: _accessMessage(capabilities)),
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
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
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
                    sliver: SliverToBoxAdapter(child: _SearchBar(onTap: () => context.push('/services'))),
                  ),
                  if (showAccessBanner)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _AccessBanner(capabilities: capabilities, onPrimary: () => _goProfile(context, capabilities)),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: _SectionTitle(title: 'Quick Actions', actionLabel: 'View all', onTap: () => context.go('/more')),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        onMore: () => context.go('/more'),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: _SectionTitle(
                        title: 'Today\'s Summary',
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
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.34,
                      ),
                      delegate: SliverChildListDelegate.fixed(
                        _metricCards(summary).map((item) => _MetricCard(item: item)).toList(growable: false),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _ProfileCompletionCard(onOpen: () => _goProfile(context, capabilities)),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: _SectionTitle(
                        title: summary.serviceSnapshots.isEmpty ? 'Start something new' : 'Your Services in Progress',
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
                        title: 'Recent Activity',
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
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
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
        .where((action) => action.title.trim().toLowerCase() != 'more')
        .where((action) => allowInternal || action.requiredCapability != 'can_manage_customers')
        .toList(growable: false);

    filtered.sort((left, right) {
      final byOrder = left.sortOrder.compareTo(right.sortOrder);
      if (byOrder != 0) return byOrder;
      return left.title.compareTo(right.title);
    });

    return filtered.take(5).toList(growable: false);
  }

  List<_MetricItem> _metricCards(HomeDashboardSummary summary) {
    return [
      _MetricItem(
        label: 'Active Services',
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
        label: 'Payments Due',
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
      'can_track_requests' =>
        capabilities.canTrackRequests || capabilities.canViewCustomerDashboard || capabilities.canAccessCustomerDashboard || capabilities.isApproved || capabilities.canAccessInternalWorkspace,
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
          behavior: SnackBarBehavior.floating,
          content: Text(_accessMessage(capabilities)),
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
            colors: [Color(0xFFF9FBFE), Color(0xFFF5F7FC), Color(0xFFF8F9FC)],
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
    final greeting = hour < 12 ? 'Good morning,' : hour < 17 ? 'Good afternoon,' : 'Good evening,';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: const TextStyle(fontSize: 13, height: 1.2, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
              const SizedBox(height: 3),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 26, height: 1.05, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.45),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
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
            const SizedBox(width: 46, height: 46, child: Icon(Icons.notifications_none_rounded, size: 22, color: AppTheme.textPrimary)),
            if (unreadNotifications > 0)
              Positioned(
                right: 6,
                top: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFE11D48), borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    unreadNotifications > 9 ? '9+' : unreadNotifications.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
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
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: ClipOval(
        child: avatarUrl == null
            ? Container(
                color: const Color(0xFFF3F4F6),
                alignment: Alignment.center,
                child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
              )
            : Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFF3F4F6),
                    alignment: Alignment.center,
                    child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
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
          padding: const EdgeInsets.symmetric(horizontal: 14),
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
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: AppTheme.cardSoft, borderRadius: BorderRadius.circular(12)),
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
    final title = capabilities.isRejected ? 'Profile blocked' : capabilities.isPending ? 'Profile under review' : 'Guest access';
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
            decoration: BoxDecoration(color: tone.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
            child: Icon(capabilities.isRejected ? Icons.block_rounded : Icons.verified_outlined, color: tone),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
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
            child: const Text('View Status'),
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.2),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryRed, textStyle: const TextStyle(fontWeight: FontWeight.w800)),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.actions,
    required this.capabilities,
    required this.onTap,
    required this.onMore,
  });

  final List<MobileQuickAction> actions;
  final AuthCapabilities capabilities;
  final ValueChanged<MobileQuickAction> onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final visible = actions.take(5).toList(growable: false);
    return SizedBox(
      height: 112,
      child: Row(
        children: [
          for (var index = 0; index < 5; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: index < visible.length
                  ? _ActionTile(
                      action: visible[index],
                      allowed: _isAllowed(visible[index], capabilities),
                      onTap: () => onTap(visible[index]),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(child: _MoreTile(onTap: onMore)),
        ],
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.allowed, required this.onTap});

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
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: allowed ? palette.border : AppTheme.border),
              boxShadow: const [BoxShadow(color: Color(0x080F172A), blurRadius: 14, offset: Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: palette.soft, borderRadius: BorderRadius.circular(12)),
                  child: Icon(_iconForActionKey(action.iconKey), color: palette.accent, size: 18),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Center(
                    child: Text(
                      action.title,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.08),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
            boxShadow: const [BoxShadow(color: Color(0x080F172A), blurRadius: 14, offset: Offset(0, 8))],
          ),
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: const Color(0xFFF5F7FC), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.more_horiz_rounded, size: 20, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Expanded(
                child: Center(
                  child: Text('More', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.8, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCompletionCard extends StatelessWidget {
  const _ProfileCompletionCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEFFBF4), Color(0xFFD7FBEA)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(left: 10, top: 9, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(5)))),
                Positioned(right: 11, bottom: 10, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(5)))),
                const Icon(Icons.verified_user_rounded, size: 28, color: Color(0xFF17B890)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Complete your profile', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                const Text('Get full access to all features and sync your data across devices.', style: TextStyle(fontSize: 12.4, height: 1.35, color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF17B890),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    minimumSize: const Size(0, 0),
                  ),
                  onPressed: onOpen,
                  child: const Text('Complete Now'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}

class _MetricItem {
  const _MetricItem({required this.label, required this.value, required this.icon, required this.accent, required this.hint});

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
              Container(width: 34, height: 34, decoration: BoxDecoration(color: item.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)), child: Icon(item.icon, color: item.accent, size: 19)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(color: item.accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
                child: Text(item.hint, style: TextStyle(color: item.accent, fontSize: 9.8, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const Spacer(),
          Text(item.value.toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.6)),
          const SizedBox(height: 2),
          Text(item.label, style: const TextStyle(fontSize: 12.4, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          _TrendLine(color: item.accent),
        ],
      ),
    );
  }
}

class _TrendLine extends StatelessWidget {
  const _TrendLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        5,
        (index) => Container(
          width: 18 + (index.isEven ? 4 : 0),
          height: 3,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.20 + (index * 0.08)), borderRadius: BorderRadius.circular(999)),
        ),
      ),
    );
  }
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
            Container(width: 54, height: 54, decoration: BoxDecoration(color: const Color(0xFFFDEEEF), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.inbox_outlined, color: AppTheme.primaryRed, size: 28)),
            const SizedBox(height: 14),
            const Text('No active service yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            const Text('Browse the catalogue and start from a clean flow instead of jumping through clutter.', style: TextStyle(fontSize: 12.5, height: 1.35, color: AppTheme.textSecondary)),
            const SizedBox(height: 14),
            FilledButton(onPressed: onBrowse, child: const Text('Browse services')),
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
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Icon(_statusIcon(service.status), color: color, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(service.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                        const SizedBox(height: 2),
                        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
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
                  Text('$progress% complete', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
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
        child: const Text('Recent activity will appear here once services start moving.', style: TextStyle(fontSize: 12.5, height: 1.35, color: AppTheme.textSecondary)),
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
                  Expanded(child: Text('Open full tracking view', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary))),
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
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(activity.subtitle, style: const TextStyle(fontSize: 12.5, height: 1.35, color: AppTheme.textSecondary)),
                if ((activity.createdAtLabel ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(activity.createdAtLabel!, style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ],
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
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
    return const _ActionPalette(accent: Color(0xFF4F8DFD), soft: Color(0xFFF0F6FF), border: Color(0xFFD9E7FF));
  }
  if (key.contains('track')) {
    return const _ActionPalette(accent: Color(0xFF17B890), soft: Color(0xFFF0FBF8), border: Color(0xFFD7F4EC));
  }
  if (key.contains('calc')) {
    return const _ActionPalette(accent: Color(0xFFF59E0B), soft: Color(0xFFFFF8EC), border: Color(0xFFFFE6B7));
  }
  if (key.contains('support')) {
    return const _ActionPalette(accent: Color(0xFF8B5CF6), soft: Color(0xFFF7F2FF), border: Color(0xFFE5D9FF));
  }
  if (key.contains('payment')) {
    return const _ActionPalette(accent: Color(0xFFEC4899), soft: Color(0xFFFFF0F7), border: Color(0xFFF9D7E8));
  }
  return const _ActionPalette(accent: AppTheme.primaryRed, soft: Color(0xFFFDEEEF), border: Color(0xFFF7D4D9));
}

IconData _iconForActionKey(String key) {
  final normalized = key.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
  return switch (normalized) {
    'tax-return' => Icons.receipt_long_outlined,
    'ntn' => Icons.badge_outlined,
    'gst' => Icons.request_quote_outlined,
    'documents' => Icons.description_outlined,
    'track' => Icons.track_changes_rounded,
    'calculator' => Icons.calculate_outlined,
    'support' => Icons.support_agent_rounded,
    'payments' => Icons.payments_outlined,
    'message' => Icons.chat_bubble_outline_rounded,
    'knowledge' => Icons.lightbulb_outline_rounded,
    'services' => Icons.grid_view_rounded,
    'notifications' => Icons.notifications_none_rounded,
    'dashboard' => Icons.dashboard_outlined,
    _ => Icons.apps_rounded,
  };
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
  if (normalized.contains('in progress')) return 'In Progress';
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
  if (normalized.contains('verified') || normalized.contains('approved') || normalized.contains('done')) return const Color(0xFF10B981);
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
