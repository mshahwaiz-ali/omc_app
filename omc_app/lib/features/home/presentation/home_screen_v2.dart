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

const Color _kTaxBlue = Color(0xFF2F6BFF);
const Color _kPaymentsGreen = Color(0xFF17B890);
const Color _kDocumentsIndigo = Color(0xFF5B7CFA);
const Color _kServicesRose = Color(0xFFE11D48);
const Color _kTrackTeal = Color(0xFF14B8A6);
const Color _kLeadsPurple = Color(0xFF8B5CF6);
const Color _kTasksOrange = Color(0xFFF59E0B);
const Color _kNotificationsSlate = Color(0xFF64748B);

const Color _kTaxBlueSoft = Color(0xFFF0F6FF);
const Color _kPaymentsGreenSoft = Color(0xFFF0FBF8);
const Color _kDocumentsIndigoSoft = Color(0xFFF2F5FF);
const Color _kServicesRoseSoft = Color(0xFFFDEEEF);
const Color _kTrackTealSoft = Color(0xFFEFFCF9);
const Color _kLeadsPurpleSoft = Color(0xFFF7F2FF);
const Color _kTasksOrangeSoft = Color(0xFFFFF8EC);
const Color _kNotificationsSlateSoft = Color(0xFFF5F7FC);
const Color _kNeutralSoft = Color(0xFFF5F7FC);

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
    final showAccessBanner = capabilities.isGuest || capabilities.isPending || capabilities.isRejected;

    final actions = _visibleActions(
      actionsAsync.maybeWhen(data: (value) => value, orElse: () => fallbackMobileQuickActions),
      capabilities.canAccessInternalWorkspace,
    );

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
                        child: _AccessBanner(
                          capabilities: capabilities,
                          onPrimary: () => _goProfile(context, capabilities),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: _SectionTitle(
                        title: 'Quick Actions',
                        actionLabel: 'View all',
                        onTap: () => context.go('/more'),
                      ),
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
        accent: _kServicesRose,
        soft: _kServicesRoseSoft,
        hint: 'Live cases',
      ),
      _MetricItem(
        label: 'Documents',
        value: summary.pendingDocuments,
        icon: Icons.description_outlined,
        accent: _kDocumentsIndigo,
        soft: _kDocumentsIndigoSoft,
        hint: 'Pending review',
      ),
      _MetricItem(
        label: 'Payments Due',
        value: summary.paymentsDue,
        icon: Icons.payments_outlined,
        accent: _kPaymentsGreen,
        soft: _kPaymentsGreenSoft,
        hint: 'Action needed',
      ),
      _MetricItem(
        label: 'Notifications',
        value: summary.unreadNotifications,
        icon: Icons.notifications_none_rounded,
        accent: _kNotificationsSlate,
        soft: _kNotificationsSlateSoft,
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

class _HomeMode {
  const _HomeMode._(this.value);

  final String value;

  static const internal = _HomeMode._('internal');
  static const customer = _HomeMode._('customer');
  static const guest = _HomeMode._('guest');

  bool get isInternal => identical(this, internal);
  bool get isCustomer => identical(this, customer);
  bool get isGuest => identical(this, guest);

  static _HomeMode fromCapabilities(AuthCapabilities capabilities) {
    if (capabilities.isInternal || capabilities.canAccessInternalWorkspace) return internal;
    if (capabilities.isGuest || capabilities.isPending || capabilities.isRejected) return guest;
    return customer;
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

class _Header extends StatelessWidget {
  const _Header({
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
              Text(
                greeting,
                style: const TextStyle(fontSize: 13, height: 1.2, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
              ),
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
            const SizedBox(
              width: 46,
              height: 46,
              child: Icon(Icons.notifications_none_rounded, size: 22, color: AppTheme.textPrimary),
            ),
            if (unreadNotifications > 0)
              Positioned(
                right: 6,
                top: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: _kServicesRose, borderRadius: BorderRadius.circular(999)),
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
                decoration: BoxDecoration(color: _kNeutralSoft, borderRadius: BorderRadius.circular(12)),
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
        ? _kTasksOrange
        : capabilities.isRejected
            ? _kServicesRose
            : _kTaxBlue;
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
              foregroundColor: _kTaxBlue,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
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
      height: 88,
      child: Row(
        children: [
          for (var index = 0; index < 5; index++) ...[
            if (index > 0) const SizedBox(width: 10),
            Expanded(
              child: index < visible.length
                  ? _ActionTile(
                      action: visible[index],
                      locked: !_isAllowed(visible[index], capabilities),
                      onTap: () => onTap(visible[index]),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
          const SizedBox(width: 10),
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
      'can_review_documents' => capabilities.canReviewDocuments || capabilities.canAccessInternalWorkspace,
      'can_review_payments' => capabilities.canReviewPayments || capabilities.canAccessInternalWorkspace,
      'can_manage_customers' => capabilities.canManageCustomers || capabilities.canAccessInternalWorkspace,
      'can_manage_leads' => capabilities.canManageLeads || capabilities.canAccessInternalWorkspace,
      'can_manage_tasks' => capabilities.canManageTasks || capabilities.canAccessInternalWorkspace,
      'can_use_tax_calculator' => capabilities.canUseTaxCalculator,
      _ => true,
    };
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.locked, required this.onTap});

  final MobileQuickAction action;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForAction(action);

    return Opacity(
      opacity: locked ? 0.62 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: palette.soft, borderRadius: BorderRadius.circular(12)),
                      child: Icon(_iconForActionKey(action.iconKey), color: palette.accent, size: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action.title,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.08),
                    ),
                  ],
                ),
                if (locked)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 4, offset: Offset(0, 2))]),
                      child: const Icon(Icons.lock_rounded, size: 10, color: AppTheme.textMuted),
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
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: Icon(Icons.more_horiz_rounded, size: 20, color: AppTheme.textPrimary),
              ),
              SizedBox(height: 8),
              Flexible(
                child: Text(
                  'More',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.8, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorPalette {
  const _ColorPalette({required this.accent, required this.soft});
  final Color accent;
  final Color soft;
}

_ColorPalette _paletteForAction(MobileQuickAction action) {
  final key = '${action.iconKey} ${action.title}'.toLowerCase();
  if (key.contains('payment') || key.contains('receipt')) return const _ColorPalette(accent: _kPaymentsGreen, soft: _kPaymentsGreenSoft);
  if (key.contains('document')) return const _ColorPalette(accent: _kDocumentsIndigo, soft: _kDocumentsIndigoSoft);
  if (key.contains('track') || key.contains('review')) return const _ColorPalette(accent: _kTrackTeal, soft: _kTrackTealSoft);
  if (key.contains('lead')) return const _ColorPalette(accent: _kLeadsPurple, soft: _kLeadsPurpleSoft);
  if (key.contains('task')) return const _ColorPalette(accent: _kTasksOrange, soft: _kTasksOrangeSoft);
  if (key.contains('notification')) return const _ColorPalette(accent: _kNotificationsSlate, soft: _kNotificationsSlateSoft);
  if (key.contains('service')) return const _ColorPalette(accent: _kServicesRose, soft: _kServicesRoseSoft);
  if (key.contains('tax') || key.contains('gst') || key.contains('calculator') || key.contains('ntn')) return const _ColorPalette(accent: _kTaxBlue, soft: _kTaxBlueSoft);
  return const _ColorPalette(accent: _kTaxBlue, soft: _kTaxBlueSoft);
}

Color _statusTone(String? status) {
  final normalized = (status ?? '').trim().toLowerCase();
  if (normalized.contains('open')) return _kServicesRose;
  if (normalized.contains('in progress')) return _kTaxBlue;
  if (normalized.contains('under review')) return _kPaymentsGreen;
  if (normalized.contains('completed')) return _kPaymentsGreen;
  if (normalized.contains('waiting')) return _kLeadsPurple;
  if (normalized.contains('pending')) return _kTasksOrange;
  if (normalized.contains('rejected') || normalized.contains('cancelled')) return const Color(0xFFDC2626);
  return _kServicesRose;
}

Color _activityTone(String? status, Color fallback) {
  final normalized = (status ?? '').trim().toLowerCase();
  if (normalized.contains('verified') || normalized.contains('approved') || normalized.contains('done')) return _kPaymentsGreen;
  if (normalized.contains('review')) return _kTaxBlue;
  if (normalized.contains('required') || normalized.contains('information')) return _kTasksOrange;
  if (normalized.contains('pending')) return _kLeadsPurple;
  if (normalized.contains('rejected') || normalized.contains('blocked')) return const Color(0xFFDC2626);
  return fallback;
}

Color _progressStartColor(double progress) {
  if (progress <= 0.35) return const Color(0xFF8B5A2B);
  if (progress <= 0.7) return const Color(0xFFD97706);
  return const Color(0xFFF59E0B);
}

Color _progressEndColor(double progress) {
  if (progress <= 0.35) return const Color(0xFFD97706);
  if (progress <= 0.7) return const Color(0xFFF59E0B);
  return const Color(0xFF16A34A);
}

Color _progressColor(double progress, String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized.contains('rejected') || normalized.contains('cancelled') || normalized.contains('blocked')) return const Color(0xFFDC2626);
  if (normalized.contains('completed')) return const Color(0xFF16A34A);
  if (progress <= 0.35) return const Color(0xFF8B5A2B);
  if (progress <= 0.7) return const Color(0xFFF59E0B);
  return const Color(0xFF16A34A);
}

String _inferFamily(String text) {
  final normalized = text.toLowerCase();
  if (normalized.contains('payment') || normalized.contains('receipt') || normalized.contains('invoice') || normalized.contains('bill')) return 'Payments';
  if (normalized.contains('document') || normalized.contains('doc ') || normalized.contains('docs') || normalized.contains('uploaded')) return 'Documents';
  if (normalized.contains('track') || normalized.contains('review') || normalized.contains('progress') || normalized.contains('status')) return 'Track';
  if (normalized.contains('lead')) return 'Leads';
  if (normalized.contains('task') || normalized.contains('todo') || normalized.contains('action needed')) return 'Tasks';
  if (normalized.contains('notification') || normalized.contains('alert') || normalized.contains('message')) return 'Notifications';
  if (normalized.contains('tax') || normalized.contains('gst') || normalized.contains('ntn') || normalized.contains('calculator')) return 'Tax';
  return 'Services';
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
    'leads' => Icons.apps_rounded,
    'tasks' => Icons.task_alt_rounded,
    _ => Icons.apps_rounded,
  };
}

IconData _activityIcon(String? status) {
  final normalized = (status ?? '').trim().toLowerCase();
  if (normalized.contains('verified') || normalized.contains('approved') || normalized.contains('done')) return Icons.check_circle_rounded;
  if (normalized.contains('review')) return Icons.visibility_rounded;
  if (normalized.contains('required') || normalized.contains('information')) return Icons.priority_high_rounded;
  if (normalized.contains('pending')) return Icons.hourglass_top_rounded;
  if (normalized.contains('rejected') || normalized.contains('blocked')) return Icons.block_rounded;
  return Icons.circle_rounded;
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

String _statusLabel(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized.isEmpty) return 'Open';
  if (normalized.contains('in progress')) return 'In Progress';
  if (normalized.contains('under review')) return 'Review';
  if (normalized.contains('information')) return 'Action';
  if (normalized.contains('completed')) return 'Done';
  if (normalized.contains('pending')) return 'Pending';
  if (normalized.contains('rejected')) return 'Rejected';
  return status;
}
