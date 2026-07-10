import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/app_config/data/mobile_app_config.dart';
import '../features/app_config/data/mobile_app_config_repository.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_state.dart';
import '../features/home/data/home_dashboard_repository.dart';
import '../features/profile/data/profile_repository.dart';
import 'navigation/omc_bottom_nav.dart';
import 'navigation/omc_more_sheet.dart';
import 'navigation/omc_quick_actions_sheet.dart';

class ShellNavScaffold extends ConsumerWidget {
  const ShellNavScaffold({
    required this.selectedIndex,
    required this.child,
    super.key,
  });

  final int selectedIndex;
  final Widget child;

  static const int homeIndex = 0;
  static const int servicesIndex = 1;
  static const int trackIndex = 2;
  static const int documentsIndex = 3;
  static const int moreIndex = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref
        .watch(profileSummaryProvider)
        .maybeWhen(data: (profile) => profile, orElse: () => null);
    final authState = ref.watch(authControllerProvider);
    final capabilities = profile?.capabilities ?? authState.capabilities;
    final unreadNotifications =
        ref.watch(homeDashboardSummaryProvider).value?.unreadNotifications ?? 0;

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: OmcBottomNav(
        selectedIndex: selectedIndex,
        notificationBadgeCount: unreadNotifications,
        onTabSelected: (index) => _openTab(context, capabilities, index),
        onQuickActions: () =>
            _showQuickActionsSheet(context, ref, capabilities),
        onMore: () => _showMoreSheet(context, ref),
      ),
    );
  }

  void _openTab(
    BuildContext context,
    AuthCapabilities capabilities,
    int index,
  ) {
    if (index == trackIndex && !_canOpenTrack(capabilities)) {
      _showLockedSnack(context, capabilities);
      return;
    }
    if (index == documentsIndex && !_canOpenDocuments(capabilities)) {
      _showLockedSnack(context, capabilities);
      return;
    }

    final path = switch (index) {
      homeIndex => '/home',
      servicesIndex => '/services',
      trackIndex => '/my-services',
      documentsIndex => '/documents',
      _ => '/home',
    };

    context.go(path);
  }

  void _showQuickActionsSheet(
    BuildContext context,
    WidgetRef ref,
    AuthCapabilities capabilities,
  ) {
    showOmcQuickActionsSheet(
      context: context,
      capabilities: capabilities,
      onOpenServices: () => context.go('/services'),
      onOpenDocuments: () => _openWhenAllowed(
        context: context,
        allowed: _canOpenDocuments(capabilities),
        path: '/documents',
        capabilities: capabilities,
      ),
      onOpenPayments: () => _openWhenAllowed(
        context: context,
        allowed:
            capabilities.canViewPayments ||
            capabilities.canReviewPayments ||
            capabilities.isApproved ||
            capabilities.isInternal,
        path: '/payments',
        capabilities: capabilities,
      ),
      onOpenTrack: () => _openWhenAllowed(
        context: context,
        allowed: _canOpenTrack(capabilities),
        path: '/my-services',
        capabilities: capabilities,
      ),
      onOpenSupport: () => context.go('/support'),
      onOpenTaxCalculator: () => context.go('/tax-calculator'),
      onOpenExpenseTracker: () => context.go('/expense-tracker'),
      onOpenProfile: () =>
          capabilities.isGuest ? context.go('/signup') : context.go('/profile'),
      onOpenKnowledge: () => context.go('/knowledge'),
      onOpenInternalWorkspace: () => context.go('/internal-workspace'),
      onOpenCustomers: () => context.go('/customers'),
      onOpenTasks: () => context.go('/tasks'),
    );
  }

  void _showMoreSheet(BuildContext context, WidgetRef ref) {
    final authState = ref.read(authControllerProvider);
    final profile = ref
        .read(profileSummaryProvider)
        .maybeWhen(data: (profile) => profile, orElse: () => null);
    final capabilities = profile?.capabilities ?? authState.capabilities;
    final mobileConfig =
        ref.read(mobileAppConfigProvider).value ?? MobileAppConfig.fallback;
    final unreadNotifications =
        ref.read(homeDashboardSummaryProvider).value?.unreadNotifications ?? 0;

    showOmcMoreSheet(
      context: context,
      features: mobileConfig.features,
      capabilities: capabilities,
      unreadNotifications: unreadNotifications,
      isGuest: authState.status == AuthStatus.guest,
      displayName: profile?.displayName ?? authState.displayName,
      companyName: profile?.companyName ?? authState.companyName,
      customerStatus: profile?.status ?? authState.customerStatus,
      avatarUrl: profile?.avatarUrl ?? authState.avatarUrl,
      onOpenDashboard: () => _openWhenAllowed(
        context: context,
        allowed:
            capabilities.canViewCustomerDashboard ||
            capabilities.canAccessCustomerDashboard ||
            capabilities.canAccessInternalWorkspace,
        path: '/dashboard',
        capabilities: capabilities,
      ),
      onOpenDocuments: () => _openWhenAllowed(
        context: context,
        allowed: _canOpenDocuments(capabilities),
        path: '/documents',
        capabilities: capabilities,
      ),
      onOpenPayments: () => _openWhenAllowed(
        context: context,
        allowed:
            capabilities.canViewPayments ||
            capabilities.canReviewPayments ||
            capabilities.isApproved ||
            capabilities.isInternal,
        path: '/payments',
        capabilities: capabilities,
      ),
      onOpenNotifications: () => _openWhenAllowed(
        context: context,
        allowed:
            capabilities.canViewCustomerNotifications ||
            capabilities.isApproved ||
            capabilities.isInternal ||
            capabilities.canAccessInternalWorkspace,
        path: '/notifications',
        capabilities: capabilities,
      ),
      onOpenTaxCalculator: () => context.go('/tax-calculator'),
      onOpenExpenseTracker: () => context.go('/expense-tracker'),
      onOpenBudget: () => _openWhenAllowed(
        context: context,
        allowed: capabilities.isApproved,
        path: '/expense-budget',
        capabilities: capabilities,
      ),
      onOpenKnowledge: () => context.go('/knowledge'),
      onOpenSupport: () => context.go('/support'),
      onOpenProfile: () => _openWhenAllowed(
        context: context,
        allowed: !capabilities.isGuest,
        path: '/profile',
        capabilities: capabilities,
      ),
      onOpenSettings: () => _openWhenAllowed(
        context: context,
        allowed: !capabilities.isGuest,
        path: '/settings',
        capabilities: capabilities,
      ),
      onOpenInternalWorkspace: () => context.go('/internal-workspace'),
      onOpenInternalCases: () =>
          context.go('/internal-workspace/service-cases'),
      onOpenCustomers: () => context.go('/customers'),
      onOpenLeads: () => context.go('/leads'),
      onOpenTasks: () => context.go('/tasks'),
      onLogout: authState.status == AuthStatus.guest
          ? () => context.go('/login')
          : () => _logout(context, ref),
    );
  }

  void _openWhenAllowed({
    required BuildContext context,
    required bool allowed,
    required String path,
    required AuthCapabilities capabilities,
  }) {
    if (!allowed) {
      _showLockedSnack(context, capabilities);
      return;
    }
    context.go(path);
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).logout();
    ref.invalidate(profileSummaryProvider);
    if (!context.mounted) return;
    context.go('/login');
  }

  bool _canOpenTrack(AuthCapabilities capabilities) {
    return capabilities.canTrackRequests ||
        capabilities.canViewCustomerDashboard ||
        capabilities.canAccessCustomerDashboard ||
        capabilities.isApproved ||
        capabilities.canAccessInternalWorkspace;
  }

  bool _canOpenDocuments(AuthCapabilities capabilities) {
    return capabilities.canViewDocuments ||
        capabilities.canReviewDocuments ||
        capabilities.isApproved ||
        capabilities.isInternal ||
        capabilities.canAccessInternalWorkspace;
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
}
