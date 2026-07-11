import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/widgets/omc_identity_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../profile/data/profile_repository.dart';
import '../data/home_dashboard_repository.dart';
import '../data/mobile_quick_actions_repository.dart';

const Color _taxBlue = Color(0xFF2F6BFF);
const Color _paymentsGreen = Color(0xFF17B890);
const Color _documentsIndigo = Color(0xFF5B7CFA);
const Color _servicesRose = Color(0xFFE11D48);
const Color _trackTeal = Color(0xFF14B8A6);
const Color _leadsPurple = Color(0xFF8B5CF6);
const Color _tasksOrange = Color(0xFFF59E0B);
const Color _neutralSlate = Color(0xFF64748B);

const Color _taxBlueSoft = Color(0xFFF0F6FF);
const Color _paymentsGreenSoft = Color(0xFFF0FBF8);
const Color _documentsIndigoSoft = Color(0xFFF2F5FF);
const Color _servicesRoseSoft = Color(0xFFFDEEEF);
const Color _trackTealSoft = Color(0xFFEFFCF9);
const Color _leadsPurpleSoft = Color(0xFFF7F2FF);
const Color _tasksOrangeSoft = Color(0xFFFFF8EC);
const Color _neutralSoft = Color(0xFFF5F7FC);

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
    final quickActionsAsync = ref.watch(mobileQuickActionsProvider);

    final mode = _HomeMode.fromCapabilities(capabilities);
    final dashboardAsync = mode.isInternal || mode.isCustomer
        ? ref.watch(homeDashboardSummaryProvider)
        : const AsyncValue<HomeDashboardSummary>.data(
            HomeDashboardSummary.empty(),
          );

    final summary = dashboardAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const HomeDashboardSummary.empty(),
    );
    final profile = profileAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final displayName =
        profile?.displayName ??
        authState.displayName ??
        _displayNameFromUserId(authState.userId);
    final avatarUrl = _resolveAvatarUrl(
      profile?.avatarUrl ?? authState.avatarUrl,
    );

    final quickActions = mode.isInternal
        ? _internalQuickActions(
            quickActionsAsync.maybeWhen(
              data: (value) => value,
              orElse: () => const [],
            ),
          )
        : _customerQuickActions();

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
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: OmcIdentityHeader(
                        displayName: displayName,
                        avatarUrl: avatarUrl,
                        unreadNotifications: summary.unreadNotifications,
                        onNotifications: () => _openNotifications(
                          context,
                          capabilities,
                          onOpenNotifications,
                        ),
                        onAvatar: () => context.push('/profile'),
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
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child:
                          mode.isCustomer && summary.serviceSnapshots.isNotEmpty
                          ? _CustomerServiceFocusCard(
                              service: summary.serviceSnapshots.first,
                              nextAction: summary.nextAction,
                              onOpenService: () => _goAllowed(
                                context,
                                '/my-services/${Uri.encodeComponent(summary.serviceSnapshots.first.id)}',
                                capabilities,
                                'can_track_requests',
                              ),
                              onPrimaryAction: () {
                                final action = summary.nextAction;
                                if (action != null &&
                                    action.route.trim().isNotEmpty) {
                                  context.push(
                                    action.route.startsWith('/')
                                        ? action.route
                                        : '/${action.route}',
                                  );
                                  return;
                                }

                                _goAllowed(
                                  context,
                                  '/my-services/${Uri.encodeComponent(summary.serviceSnapshots.first.id)}',
                                  capabilities,
                                  'can_track_requests',
                                );
                              },
                            )
                          : _BannerCard(
                              mode: mode,
                              onPrimary: () =>
                                  _bannerAction(context, capabilities, mode),
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
                        actions: quickActions,
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
                        title: mode.isInternal
                            ? 'Operations Summary'
                            : 'Today\'s Summary',
                        actionLabel: mode.isInternal
                            ? 'Open queue'
                            : 'View all',
                        onTap: mode.isInternal
                            ? () => context.go('/internal-workspace')
                            : null,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: mode.isInternal
                          ? _InternalSummaryGrid(summary: summary)
                          : _CustomerSummaryGrid(
                              summary: summary,
                              guestMode: mode.isGuest,
                            ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _CTASection(
                        mode: mode,
                        onOpen: () => _ctaAction(context, mode, capabilities),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: _SectionTitle(
                        title: mode.isInternal
                            ? 'Review Queue'
                            : 'Your Services in Progress',
                        actionLabel: mode.isInternal ? 'Workspace' : 'View all',
                        onTap: mode.isInternal
                            ? () => context.go('/internal-workspace')
                            : () => _goAllowed(
                                context,
                                '/my-services',
                                capabilities,
                                'can_track_requests',
                              ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: mode.isInternal
                          ? _ServiceList(
                              items: summary.serviceSnapshots,
                              onTap: (id) => context.push(
                                '/internal-workspace/service-cases/$id',
                              ),
                            )
                          : _ServiceList(
                              items: summary.serviceSnapshots,
                              onTap: (id) => _goAllowed(
                                context,
                                '/my-services/${Uri.encodeComponent(id)}',
                                capabilities,
                                'can_track_requests',
                              ),
                            ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: _SectionTitle(
                        title: 'Recent Activity',
                        actionLabel: mode.isInternal ? 'Open queue' : 'Track',
                        onTap: mode.isInternal
                            ? () => context.go('/internal-workspace')
                            : () => _goAllowed(
                                context,
                                '/my-services',
                                capabilities,
                                'can_track_requests',
                              ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    sliver: SliverToBoxAdapter(
                      child: _ActivityList(
                        activities: summary.recentActivity
                            .take(5)
                            .toList(growable: false),
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

  List<MobileQuickAction> _internalQuickActions(
    List<MobileQuickAction> backendActions,
  ) {
    final fallback = <MobileQuickAction>[
      const MobileQuickAction(
        id: 'internal-docs',
        title: 'Review Docs',
        subtitle: 'Queue',
        iconKey: 'documents',
        targetType: MobileQuickActionTargetType.route,
        targetValue: '/internal-workspace/documents',
        requiredCapability: 'can_review_documents',
        sortOrder: 10,
      ),
      const MobileQuickAction(
        id: 'internal-payments',
        title: 'Review Payments',
        subtitle: 'Queue',
        iconKey: 'payments',
        targetType: MobileQuickActionTargetType.route,
        targetValue: '/internal-workspace/payments',
        requiredCapability: 'can_review_payments',
        sortOrder: 20,
      ),
      const MobileQuickAction(
        id: 'internal-customers',
        title: 'Customers',
        subtitle: 'Workspace',
        iconKey: 'dashboard',
        targetType: MobileQuickActionTargetType.route,
        targetValue: '/internal-workspace/customers',
        requiredCapability: 'can_manage_customers',
        sortOrder: 30,
      ),
      const MobileQuickAction(
        id: 'internal-leads',
        title: 'Leads',
        subtitle: 'Pipeline',
        iconKey: 'leads',
        targetType: MobileQuickActionTargetType.route,
        targetValue: '/leads',
        requiredCapability: 'can_manage_leads',
        sortOrder: 40,
      ),
      const MobileQuickAction(
        id: 'internal-tasks',
        title: 'Tasks',
        subtitle: 'Today',
        iconKey: 'tasks',
        targetType: MobileQuickActionTargetType.route,
        targetValue: '/tasks',
        requiredCapability: 'can_manage_tasks',
        sortOrder: 50,
      ),
    ];
    final merged = <MobileQuickAction>[...backendActions, ...fallback]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return merged.take(5).toList(growable: false);
  }

  List<MobileQuickAction> _customerQuickActions() {
    return const [
      MobileQuickAction(
        id: 'customer-services',
        title: 'My Services',
        subtitle: 'Track',
        iconKey: 'services',
        targetType: MobileQuickActionTargetType.route,
        targetValue: '/my-services',
        requiredCapability: 'can_track_requests',
        sortOrder: 10,
      ),
      MobileQuickAction(
        id: 'customer-docs',
        title: 'Documents',
        subtitle: 'Files',
        iconKey: 'documents',
        targetType: MobileQuickActionTargetType.route,
        targetValue: '/documents',
        requiredCapability: 'can_view_documents',
        sortOrder: 20,
      ),
      MobileQuickAction(
        id: 'customer-payments',
        title: 'Payments',
        subtitle: 'Billing',
        iconKey: 'payments',
        targetType: MobileQuickActionTargetType.route,
        targetValue: '/payments',
        requiredCapability: 'can_view_payments',
        sortOrder: 30,
      ),
      MobileQuickAction(
        id: 'tax-calculator',
        title: 'Tax Calc',
        subtitle: 'Estimate',
        iconKey: 'calculator',
        targetType: MobileQuickActionTargetType.feature,
        targetValue: 'calculator',
        requiredCapability: 'can_use_tax_calculator',
        sortOrder: 40,
      ),
      MobileQuickAction(
        id: 'expense-tracker',
        title: 'Expense Tracker',
        subtitle: 'Manage',
        iconKey: 'expense',
        targetType: MobileQuickActionTargetType.route,
        targetValue: '/expense-tracker',
        sortOrder: 50,
      ),
    ];
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
        context.push(
          action.targetValue.startsWith('/') ? action.targetValue : '/services',
        );
        return;
      case MobileQuickActionTargetType.feature:
        final key = action.targetValue.trim().toLowerCase();
        if (key == 'calculator') {
          if (onOpenCalculator != null) {
            onOpenCalculator();
          } else {
            context.push('/tax-calculator');
          }
          return;
        }
        if (key == 'services') {
          if (onOpenServices != null) {
            onOpenServices();
          } else {
            context.go('/services');
          }
          return;
        }
        if (key == 'support') {
          if (onOpenSupport != null) {
            onOpenSupport();
          } else {
            context.go('/support');
          }
          return;
        }
        context.go('/services');
        return;
      case MobileQuickActionTargetType.service:
        if (onOpenServices != null) {
          onOpenServices();
        } else {
          context.go('/services');
        }
        return;
      case MobileQuickActionTargetType.externalUrl:
        final uri = Uri.tryParse(action.targetValue);
        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
    }
  }

  bool _isActionAllowed(
    MobileQuickAction action,
    AuthCapabilities capabilities,
  ) {
    final required = action.requiredCapability?.trim();
    if (required == null || required.isEmpty) return true;
    return switch (required) {
      'can_view_documents' =>
        capabilities.canViewDocuments ||
            capabilities.isApproved ||
            capabilities.isInternal,
      'can_track_requests' =>
        capabilities.canTrackRequests ||
            capabilities.canViewCustomerDashboard ||
            capabilities.canAccessCustomerDashboard ||
            capabilities.isApproved ||
            capabilities.canAccessInternalWorkspace,
      'can_view_payments' =>
        capabilities.canViewPayments ||
            capabilities.canReviewPayments ||
            capabilities.isApproved ||
            capabilities.isInternal,
      'can_review_documents' =>
        capabilities.canReviewDocuments ||
            capabilities.canAccessInternalWorkspace,
      'can_review_payments' =>
        capabilities.canReviewPayments ||
            capabilities.canAccessInternalWorkspace,
      'can_manage_customers' =>
        capabilities.canManageCustomers ||
            capabilities.canAccessInternalWorkspace,
      'can_manage_leads' =>
        capabilities.canManageLeads || capabilities.canAccessInternalWorkspace,
      'can_manage_tasks' =>
        capabilities.canManageTasks || capabilities.canAccessInternalWorkspace,
      'can_use_tax_calculator' => capabilities.canUseTaxCalculator,
      _ => true,
    };
  }

  void _openNotifications(
    BuildContext context,
    AuthCapabilities capabilities,
    VoidCallback? callback,
  ) {
    final allowed =
        capabilities.canViewCustomerNotifications ||
        capabilities.isApproved ||
        capabilities.isInternal ||
        capabilities.canAccessInternalWorkspace ||
        capabilities.isGuest;
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

  void _goAllowed(
    BuildContext context,
    String route,
    AuthCapabilities capabilities,
    String capability,
  ) {
    if (!_isAllowed(capability, capabilities)) {
      _showLockedSnack(context, capabilities);
      return;
    }
    context.push(route);
  }

  bool _isAllowed(String capability, AuthCapabilities capabilities) {
    return switch (capability) {
      'can_view_documents' =>
        capabilities.canViewDocuments ||
            capabilities.isApproved ||
            capabilities.isInternal,
      'can_track_requests' =>
        capabilities.canTrackRequests ||
            capabilities.canViewCustomerDashboard ||
            capabilities.canAccessCustomerDashboard ||
            capabilities.isApproved ||
            capabilities.canAccessInternalWorkspace,
      'can_view_payments' =>
        capabilities.canViewPayments ||
            capabilities.canReviewPayments ||
            capabilities.isApproved ||
            capabilities.isInternal,
      'can_review_documents' =>
        capabilities.canReviewDocuments ||
            capabilities.canAccessInternalWorkspace,
      'can_review_payments' =>
        capabilities.canReviewPayments ||
            capabilities.canAccessInternalWorkspace,
      'can_manage_customers' =>
        capabilities.canManageCustomers ||
            capabilities.canAccessInternalWorkspace,
      'can_manage_leads' =>
        capabilities.canManageLeads || capabilities.canAccessInternalWorkspace,
      'can_manage_tasks' =>
        capabilities.canManageTasks || capabilities.canAccessInternalWorkspace,
      _ => true,
    };
  }

  void _ctaAction(
    BuildContext context,
    _HomeMode mode,
    AuthCapabilities capabilities,
  ) {
    if (mode.isInternal) {
      context.go('/internal-workspace');
    } else if (capabilities.isGuest) {
      context.push('/signup');
    } else {
      context.push('/profile');
    }
  }

  void _bannerAction(
    BuildContext context,
    AuthCapabilities capabilities,
    _HomeMode mode,
  ) {
    if (mode.isInternal) {
      context.go('/internal-workspace');
    } else if (capabilities.isGuest) {
      context.push('/signup');
    } else if (capabilities.isPending) {
      context.go('/under-review');
    } else {
      context.push('/profile');
    }
  }

  void _showLockedSnack(BuildContext context, AuthCapabilities capabilities) {
    final message = capabilities.isGuest
        ? 'Some actions are locked for guests. Create an account to unlock them.'
        : capabilities.isPending
        ? 'Your account is under review.'
        : capabilities.isRejected
        ? 'This action is unavailable for this account.'
        : 'This action is not available right now.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
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
    return ApiConfig.resolveFileUrl(value);
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
    if (capabilities.isInternal || capabilities.canAccessInternalWorkspace) {
      return internal;
    }
    if (capabilities.isGuest ||
        capabilities.isPending ||
        capabilities.isRejected) {
      return guest;
    }
    return customer;
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF9FBFE), Color(0xFFF5F7FC), Color(0xFFF8F9FC)],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

// Retained while older role layouts are migrated to OmcIdentityHeader.
// ignore: unused_element
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
    final greeting = hour < 12
        ? 'Good morning,'
        : hour < 17
        ? 'Good afternoon,'
        : 'Good evening,';
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
              const SizedBox(height: 3),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _HeaderIconButton(
          unreadNotifications: unreadNotifications,
          onTap: onNotifications,
        ),
        const SizedBox(width: 10),
        _AvatarBadge(avatarUrl: avatarUrl, name: displayName),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.unreadNotifications,
    required this.onTap,
  });
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
          children: [
            const SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                Icons.notifications_none_rounded,
                size: 22,
                color: AppTheme.textPrimary,
              ),
            ),
            if (unreadNotifications > 0)
              Positioned(
                right: 6,
                top: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: _servicesRose,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    unreadNotifications > 9
                        ? '9+'
                        : unreadNotifications.toString(),
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
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: avatarUrl == null
            ? Container(
                color: _avatarColor(name).withValues(alpha: 0.12),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _avatarColor(name),
                  ),
                ),
              )
            : Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => Container(
                  color: _avatarColor(name).withValues(alpha: 0.12),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _avatarColor(name),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Color _avatarColor(String name) {
    final colors = [
      _servicesRose,
      _documentsIndigo,
      _paymentsGreen,
      _trackTeal,
      _leadsPurple,
      _tasksOrange,
    ];
    final source = name.trim().isEmpty ? 'OMC' : name.trim();
    final index =
        source.codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
        colors.length;
    return colors[index];
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
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: const [
              Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search services, documents, invoices...',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _FilterChip(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _neutralSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.tune_rounded,
          size: 18,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _CustomerServiceFocusCard extends StatelessWidget {
  const _CustomerServiceFocusCard({
    required this.service,
    required this.nextAction,
    required this.onOpenService,
    required this.onPrimaryAction,
  });

  final HomeDashboardServiceSnapshot service;
  final HomeDashboardNextAction? nextAction;
  final VoidCallback onOpenService;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final statusTone = _statusTone(service.status);
    final progress = service.progress.clamp(0.0, 1.0);
    final progressPercent = (progress * 100).round();
    final missingDocuments = service.documentSummary.missing;
    final actionTitle = _actionTitle;
    final actionLabel = _actionButtonLabel;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpenService,
            borderRadius: BorderRadius.circular(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: statusTone.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.business_center_outlined,
                    color: statusTone,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.title.isEmpty
                            ? 'Active OMC Service'
                            : service.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        service.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: statusTone.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    service.status.isEmpty ? 'In Progress' : service.status,
                    style: TextStyle(
                      color: statusTone,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFF0F1F4),
                    valueColor: AlwaysStoppedAnimation<Color>(statusTone),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$progressPercent%',
                style: TextStyle(
                  color: statusTone,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: const Color(0xFFFAFAFB),
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              onTap: onOpenService,
              borderRadius: BorderRadius.circular(15),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: statusTone.withValues(alpha: 0.09),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: statusTone,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        actionTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12.5,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (missingDocuments > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '$missingDocuments document'
                        '${missingDocuments == 1 ? '' : 's'} missing',
                        style: TextStyle(
                          color: statusTone,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(width: 3),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: statusTone,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: onPrimaryAction,
              style: FilledButton.styleFrom(
                elevation: 0,
                backgroundColor: AppTheme.primaryRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(_actionIcon, size: 20),
              label: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _actionTitle {
    final title = nextAction?.title.trim() ?? '';
    final subtitle = nextAction?.subtitle.trim() ?? '';

    if (title.isNotEmpty && subtitle.isNotEmpty) {
      return '$title: $subtitle';
    }
    if (title.isNotEmpty) return title;
    if (service.documentSummary.missing > 0) {
      return 'Next step: Upload the required document';
    }

    return 'Open this service to view the next step';
  }

  String get _actionButtonLabel {
    final configured = nextAction?.buttonLabel.trim() ?? '';
    if (configured.isNotEmpty) return configured;

    if (service.documentSummary.missing > 0) {
      return 'Upload document';
    }

    return 'View service';
  }

  IconData get _actionIcon {
    final type = nextAction?.type.toLowerCase().trim() ?? '';

    if (type.contains('document') || service.documentSummary.missing > 0) {
      return Icons.upload_file_outlined;
    }
    if (type.contains('payment')) return Icons.payments_outlined;

    return Icons.arrow_forward_rounded;
  }

  Color _statusTone(String status) {
    final normalized = status.toLowerCase().trim();

    if (normalized.contains('review') ||
        normalized.contains('pending') ||
        normalized.contains('waiting')) {
      return const Color(0xFFF97316);
    }

    if (normalized.contains('complete') ||
        normalized.contains('approved') ||
        normalized.contains('paid')) {
      return const Color(0xFF159447);
    }

    return AppTheme.primaryRed;
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.mode, required this.onPrimary});
  final _HomeMode mode;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final tone = mode.isGuest
        ? _tasksOrange
        : mode.isInternal
        ? _leadsPurple
        : _taxBlue;
    final title = mode.isGuest
        ? 'Guest access'
        : mode.isInternal
        ? 'Internal workspace'
        : 'Profile under review';
    final message = mode.isGuest
        ? 'Browse public services now. Sign up to unlock tracking, documents, payments, and case history.'
        : mode.isInternal
        ? 'Operations mode. Review documents, payments, leads, and tasks from one place.'
        : 'Your account is active. Complete your profile to unlock the full dashboard.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
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
            child: Icon(
              mode.isInternal
                  ? Icons.admin_panel_settings_rounded
                  : Icons.verified_outlined,
              color: tone,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
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
            child: Text(mode.isGuest ? 'Sign up' : 'View Status'),
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
              foregroundColor: _taxBlue,
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
    // Do not expose inaccessible destinations as disabled tiles.
    // Guest and pending modes only see actions their capabilities permit.
    final visible = actions
        .where((action) => _isAllowed(action, capabilities))
        .take(5)
        .toList(growable: false);
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
      'can_view_documents' =>
        capabilities.canViewDocuments ||
            capabilities.isApproved ||
            capabilities.isInternal,
      'can_track_requests' =>
        capabilities.canTrackRequests ||
            capabilities.canViewCustomerDashboard ||
            capabilities.canAccessCustomerDashboard ||
            capabilities.isApproved ||
            capabilities.canAccessInternalWorkspace,
      'can_view_payments' =>
        capabilities.canViewPayments ||
            capabilities.canReviewPayments ||
            capabilities.isApproved ||
            capabilities.isInternal,
      'can_review_documents' =>
        capabilities.canReviewDocuments ||
            capabilities.canAccessInternalWorkspace,
      'can_review_payments' =>
        capabilities.canReviewPayments ||
            capabilities.canAccessInternalWorkspace,
      'can_manage_customers' =>
        capabilities.canManageCustomers ||
            capabilities.canAccessInternalWorkspace,
      'can_manage_leads' =>
        capabilities.canManageLeads || capabilities.canAccessInternalWorkspace,
      'can_manage_tasks' =>
        capabilities.canManageTasks || capabilities.canAccessInternalWorkspace,
      'can_use_tax_calculator' => capabilities.canUseTaxCalculator,
      _ => true,
    };
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.action,
    required this.locked,
    required this.onTap,
  });
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
                      decoration: BoxDecoration(
                        color: palette.soft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _iconForActionKey(action.iconKey),
                        color: palette.accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action.title,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.8,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        height: 1.08,
                      ),
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
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 10,
                        color: AppTheme.textMuted,
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
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: 20,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'More',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.8,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  height: 1.08,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CTASection extends StatelessWidget {
  const _CTASection({required this.mode, required this.onOpen});
  final _HomeMode mode;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final title = mode.isGuest
        ? 'Create your account'
        : mode.isInternal
        ? 'Open internal workspace'
        : 'Complete your profile';
    final subtitle = mode.isGuest
        ? 'Unlock documents, tracking, receipts, and case history.'
        : mode.isInternal
        ? 'Jump into leads, tasks, document review, and payments.'
        : 'Get full access to all features and sync your data across devices.';
    final button = mode.isGuest
        ? 'Sign up now'
        : mode.isInternal
        ? 'Open workspace'
        : 'Complete now';
    final iconColor = mode.isGuest
        ? _taxBlue
        : mode.isInternal
        ? _leadsPurple
        : _paymentsGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  iconColor.withValues(alpha: 0.14),
                  iconColor.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              mode.isInternal
                  ? Icons.admin_panel_settings_rounded
                  : Icons.verified_user_rounded,
              color: iconColor,
              size: 28,
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
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.4,
                    height: 1.35,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    minimumSize: const Size(0, 0),
                  ),
                  onPressed: onOpen,
                  child: Text(button),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem {
  const _MetricItem(this.label, this.value, this.icon, this.accent, this.soft);
  final String label;
  final int value;
  final IconData icon;
  final Color accent;
  final Color soft;
}

class _InternalSummaryGrid extends StatelessWidget {
  const _InternalSummaryGrid({required this.summary});
  final HomeDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final ops = summary.operationsSummary;
    return _StatsGrid(
      items: [
        _MetricItem(
          'Open Leads',
          ops.openLeads,
          Icons.campaign_outlined,
          _leadsPurple,
          _leadsPurpleSoft,
        ),
        _MetricItem(
          'Customers',
          ops.activeCustomers,
          Icons.people_alt_outlined,
          _taxBlue,
          _taxBlueSoft,
        ),
        _MetricItem(
          'Tasks',
          ops.pendingTasks,
          Icons.task_alt_rounded,
          _tasksOrange,
          _tasksOrangeSoft,
        ),
        _MetricItem(
          'Payments',
          ops.pendingPayments,
          Icons.payments_outlined,
          _paymentsGreen,
          _paymentsGreenSoft,
        ),
      ],
    );
  }
}

class _CustomerSummaryGrid extends StatelessWidget {
  const _CustomerSummaryGrid({required this.summary, required this.guestMode});
  final HomeDashboardSummary summary;
  final bool guestMode;

  @override
  Widget build(BuildContext context) {
    if (guestMode &&
        summary.activeCases == 0 &&
        summary.pendingDocuments == 0 &&
        summary.paymentsDue == 0 &&
        summary.unreadNotifications == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Text(
          'Guest dashboard is limited. Create an account to unlock case tracking, documents, payments, and live activity.',
          style: TextStyle(
            fontSize: 12.4,
            height: 1.35,
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    return _StatsGrid(
      items: [
        _MetricItem(
          'Active Services',
          summary.activeCases,
          Icons.work_outline_rounded,
          _servicesRose,
          _servicesRoseSoft,
        ),
        _MetricItem(
          'Documents',
          summary.pendingDocuments,
          Icons.description_outlined,
          _documentsIndigo,
          _documentsIndigoSoft,
        ),
        _MetricItem(
          'Payments',
          summary.paymentsDue,
          Icons.payments_outlined,
          _paymentsGreen,
          _paymentsGreenSoft,
        ),
        _MetricItem(
          'Notifications',
          summary.unreadNotifications,
          Icons.notifications_none_rounded,
          _neutralSlate,
          _neutralSoft,
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.items});
  final List<_MetricItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.34,
      ),
      itemBuilder: (_, index) => _MetricCard(item: items[index]),
    );
  }
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
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
                  color: item.soft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.icon, color: item.accent, size: 19),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: item.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Live',
                  style: TextStyle(
                    color: item.accent,
                    fontSize: 9.8,
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
              fontSize: 12.4,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
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
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.20 + (index * 0.08)),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _ServiceList extends StatelessWidget {
  const _ServiceList({required this.items, required this.onTap});
  final List<HomeDashboardServiceSnapshot> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Text(
          'No active service yet.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < items.take(3).length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _ServiceCard(service: items[i], onTap: () => onTap(items[i].id)),
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
    final family = _paletteForFamily(
      service.colorFamily ?? _inferFamily('${service.title} ${service.status}'),
    );
    final progress = (service.progress * 100).round().clamp(0, 100);
    final statusTone = _statusTone(service.status);
    final progressColor = _progressColor(service.progress, service.status);
    final subtitle = service.customerName.trim().isNotEmpty
        ? service.customerName
        : 'Ongoing case';

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
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: family.soft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _statusIcon(service.status),
                      color: family.accent,
                      size: 20,
                    ),
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
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ActionPill(
                    label: _statusLabel(service.status),
                    color: statusTone,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ProgressBar(progress: service.progress, color: progressColor),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '$progress% complete',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: family.accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: AppTheme.cardSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0, 1),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _progressStartColor(progress),
                  _progressEndColor(progress),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activities});
  final List<HomeDashboardActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Text(
          'Recent activity will appear here.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < activities.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: AppTheme.border),
            _ActivityItem(activity: activities[i]),
          ],
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.activity});
  final HomeDashboardActivity activity;

  @override
  Widget build(BuildContext context) {
    final family = _paletteForFamily(
      activity.colorFamily ??
          _inferFamily(
            '${activity.title} ${activity.status ?? ''} ${activity.subtitle}',
          ),
    );
    final dot = _activityTone(activity.status, family.accent);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: family.soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _activityIcon(activity.status),
              color: family.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if ((activity.createdAtLabel ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
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
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
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

class _ColorPalette {
  const _ColorPalette({required this.accent, required this.soft});
  final Color accent;
  final Color soft;
}

_ColorPalette _paletteForAction(MobileQuickAction action) {
  final key = '${action.iconKey} ${action.title}'.toLowerCase();
  if (key.contains('payment') || key.contains('receipt')) {
    return const _ColorPalette(
      accent: _paymentsGreen,
      soft: _paymentsGreenSoft,
    );
  }
  if (key.contains('document')) {
    return const _ColorPalette(
      accent: _documentsIndigo,
      soft: _documentsIndigoSoft,
    );
  }
  if (key.contains('track') || key.contains('review')) {
    return const _ColorPalette(accent: _trackTeal, soft: _trackTealSoft);
  }
  if (key.contains('lead')) {
    return const _ColorPalette(accent: _leadsPurple, soft: _leadsPurpleSoft);
  }
  if (key.contains('task')) {
    return const _ColorPalette(accent: _tasksOrange, soft: _tasksOrangeSoft);
  }
  if (key.contains('notification')) {
    return const _ColorPalette(accent: _neutralSlate, soft: _neutralSoft);
  }
  if (key.contains('service')) {
    return const _ColorPalette(accent: _servicesRose, soft: _servicesRoseSoft);
  }
  if (key.contains('tax') ||
      key.contains('gst') ||
      key.contains('calculator') ||
      key.contains('ntn')) {
    return const _ColorPalette(accent: _taxBlue, soft: _taxBlueSoft);
  }
  return const _ColorPalette(accent: _taxBlue, soft: _taxBlueSoft);
}

_ColorPalette _paletteForFamily(String? family) {
  final normalized = family?.trim().toLowerCase() ?? '';
  if (normalized.contains('payment')) {
    return const _ColorPalette(
      accent: _paymentsGreen,
      soft: _paymentsGreenSoft,
    );
  }
  if (normalized.contains('document')) {
    return const _ColorPalette(
      accent: _documentsIndigo,
      soft: _documentsIndigoSoft,
    );
  }
  if (normalized.contains('track')) {
    return const _ColorPalette(accent: _trackTeal, soft: _trackTealSoft);
  }
  if (normalized.contains('lead')) {
    return const _ColorPalette(accent: _leadsPurple, soft: _leadsPurpleSoft);
  }
  if (normalized.contains('task')) {
    return const _ColorPalette(accent: _tasksOrange, soft: _tasksOrangeSoft);
  }
  if (normalized.contains('notification')) {
    return const _ColorPalette(accent: _neutralSlate, soft: _neutralSoft);
  }
  if (normalized.contains('service')) {
    return const _ColorPalette(accent: _servicesRose, soft: _servicesRoseSoft);
  }
  if (normalized.contains('tax') ||
      normalized.contains('gst') ||
      normalized.contains('calculator') ||
      normalized.contains('ntn')) {
    return const _ColorPalette(accent: _taxBlue, soft: _taxBlueSoft);
  }
  return const _ColorPalette(accent: _taxBlue, soft: _taxBlueSoft);
}

Color _statusTone(String? status) {
  final normalized = (status ?? '').trim().toLowerCase();
  if (normalized.contains('open')) return _servicesRose;
  if (normalized.contains('in progress')) return _taxBlue;
  if (normalized.contains('under review')) return _paymentsGreen;
  if (normalized.contains('completed')) return _paymentsGreen;
  if (normalized.contains('waiting')) return _leadsPurple;
  if (normalized.contains('pending')) return _tasksOrange;
  if (normalized.contains('rejected') || normalized.contains('cancelled')) {
    return const Color(0xFFDC2626);
  }
  return _servicesRose;
}

Color _activityTone(String? status, Color fallback) {
  final normalized = (status ?? '').trim().toLowerCase();
  if (normalized.contains('verified') ||
      normalized.contains('approved') ||
      normalized.contains('done')) {
    return _paymentsGreen;
  }
  if (normalized.contains('review')) return _taxBlue;
  if (normalized.contains('required') || normalized.contains('information')) {
    return _tasksOrange;
  }
  if (normalized.contains('pending')) return _leadsPurple;
  if (normalized.contains('rejected') || normalized.contains('blocked')) {
    return const Color(0xFFDC2626);
  }
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
  if (normalized.contains('rejected') ||
      normalized.contains('cancelled') ||
      normalized.contains('blocked')) {
    return const Color(0xFFDC2626);
  }
  if (normalized.contains('completed')) return const Color(0xFF16A34A);
  if (progress <= 0.35) return const Color(0xFF8B5A2B);
  if (progress <= 0.7) return const Color(0xFFF59E0B);
  return const Color(0xFF16A34A);
}

String _inferFamily(String text) {
  final normalized = text.toLowerCase();
  if (normalized.contains('payment') ||
      normalized.contains('receipt') ||
      normalized.contains('invoice') ||
      normalized.contains('bill')) {
    return 'Payments';
  }
  if (normalized.contains('document') ||
      normalized.contains('doc ') ||
      normalized.contains('docs') ||
      normalized.contains('uploaded')) {
    return 'Documents';
  }
  if (normalized.contains('track') ||
      normalized.contains('review') ||
      normalized.contains('progress') ||
      normalized.contains('status')) {
    return 'Track';
  }
  if (normalized.contains('lead')) return 'Leads';
  if (normalized.contains('task') ||
      normalized.contains('todo') ||
      normalized.contains('action needed')) {
    return 'Tasks';
  }
  if (normalized.contains('notification') ||
      normalized.contains('alert') ||
      normalized.contains('message')) {
    return 'Notifications';
  }
  if (normalized.contains('tax') ||
      normalized.contains('gst') ||
      normalized.contains('ntn') ||
      normalized.contains('calculator')) {
    return 'Tax';
  }
  return 'Services';
}

IconData _iconForActionKey(String key) {
  final normalized = key
      .trim()
      .toLowerCase()
      .replaceAll('_', '-')
      .replaceAll(' ', '-');
  return switch (normalized) {
    'tax-return' => Icons.receipt_long_outlined,
    'ntn' => Icons.badge_outlined,
    'gst' => Icons.request_quote_outlined,
    'documents' => Icons.description_outlined,
    'track' => Icons.track_changes_rounded,
    'calculator' => Icons.calculate_outlined,
    'support' => Icons.support_agent_rounded,
    'payments' => Icons.payments_outlined,
    'message' => Icons.support_agent_rounded,
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
  if (normalized.contains('verified') ||
      normalized.contains('approved') ||
      normalized.contains('done')) {
    return Icons.check_circle_rounded;
  }
  if (normalized.contains('review')) return Icons.visibility_rounded;
  if (normalized.contains('required') || normalized.contains('information')) {
    return Icons.priority_high_rounded;
  }
  if (normalized.contains('pending')) return Icons.hourglass_top_rounded;
  if (normalized.contains('rejected') || normalized.contains('blocked')) {
    return Icons.block_rounded;
  }
  return Icons.circle_rounded;
}

IconData _statusIcon(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized.contains('in progress')) return Icons.trending_up_rounded;
  if (normalized.contains('under review')) return Icons.visibility_outlined;
  if (normalized.contains('information')) return Icons.info_outline_rounded;
  if (normalized.contains('completed')) {
    return Icons.check_circle_outline_rounded;
  }
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
