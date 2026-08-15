import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/app_config/data/mobile_app_config.dart';
import '../features/app_config/data/mobile_app_config_repository.dart';
import '../features/app_config/presentation/app_brand_registry.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_state.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/profile/data/profile_repository.dart';
import 'navigation/app_back_navigation_guard.dart';
import 'navigation/omc_bottom_nav.dart';
import 'navigation/omc_more_sheet.dart';
import 'navigation/omc_quick_actions_sheet.dart';
import 'providers/effective_capabilities_provider.dart';
import 'route_access_policy.dart';
import '../core/resilience/app_failure.dart';
import '../core/forms/dirty_form_controller.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({
    required this.navigationShell,
    this.showAccessDeniedNotice = false,
    this.showMoreOnLoad = false,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final bool showAccessDeniedNotice;
  final bool showMoreOnLoad;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _isMoreSheetOpen = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    if (widget.showMoreOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMoreSheet(fromRoute: true);
      });
    }
    if (widget.showAccessDeniedNotice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLockedSnack(_currentCapabilities());
      });
    }
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.showMoreOnLoad && widget.showMoreOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMoreSheet(fromRoute: true);
      });
    }

    if (!oldWidget.showAccessDeniedNotice && widget.showAccessDeniedNotice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLockedSnack(_currentCapabilities());
      });
    }
  }

  Future<void> _selectTab(int index) async {
    final capabilities = _currentCapabilities();
    if (_isInternal(capabilities) &&
        index == 2 &&
        !_canOpenInternalCases(capabilities)) {
      _showLockedSnack(capabilities);
      return;
    }
    if (index == 2 && !_canOpenTrack(capabilities)) {
      _showLockedSnack(capabilities);
      return;
    }
    if (index == 3 && !_canOpenDocuments(capabilities)) {
      _showLockedSnack(capabilities);
      return;
    }
    if (!await confirmDiscardActiveForm(context, ref) || !mounted) return;
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  AuthCapabilities _currentCapabilities() {
    return ref.read(effectiveCapabilitiesProvider);
  }

  bool _isInternal(AuthCapabilities capabilities) {
    return capabilities.canAccessInternalWorkspace;
  }

  bool _canOpenTrack(AuthCapabilities capabilities) {
    return canAccessRoute('/track', capabilities);
  }

  bool _canOpenDocuments(AuthCapabilities capabilities) {
    return canAccessRoute('/documents', capabilities);
  }

  bool _canOpenInternalCases(AuthCapabilities capabilities) {
    return capabilities.canViewAllServiceCases ||
        capabilities.canViewRelevantServiceCases ||
        capabilities.canViewAssignedServiceCases;
  }

  void _openWhenAllowed({
    required bool allowed,
    required String path,
    required AuthCapabilities capabilities,
  }) {
    if (!allowed) {
      _showLockedSnack(capabilities);
      return;
    }
    context.push(path);
  }

  void _showLockedSnack(AuthCapabilities capabilities) {
    if (!mounted) return;
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

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    _isLoggingOut = true;
    try {
      await ref.read(authControllerProvider.notifier).logout();
      ref.invalidate(profileSummaryProvider);

      // GoRouter observes AuthController and redirects unauthenticated users.
      // Do not issue a second navigation during the same logout transition.
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Logout incomplete',
        fallbackMessage:
            'The session could not be cleared right now. Please try again.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      _isLoggingOut = false;
    }
  }

  void _openPath(String path) => context.push(path);

  void _showQuickActionsSheet() {
    final capabilities = _currentCapabilities();
    showOmcQuickActionsSheet(
      context: context,
      capabilities: capabilities,
      onOpenServices: () => _openPath('/services'),
      onOpenDocuments: () => _openWhenAllowed(
        allowed: _canOpenDocuments(capabilities),
        path: '/documents',
        capabilities: capabilities,
      ),
      onOpenPayments: () => _openWhenAllowed(
        allowed: canAccessRoute('/payments', capabilities),
        path: '/payments',
        capabilities: capabilities,
      ),
      onOpenTrack: () => _openWhenAllowed(
        allowed: _canOpenTrack(capabilities),
        path: '/my-services',
        capabilities: capabilities,
      ),
      onOpenSupport: () => _openPath('/support'),
      onOpenTaxCalculator: () => _openPath('/tax-calculator'),
      onOpenExpenseTracker: () => _openPath('/expense-tracker'),
      onOpenProfile: () =>
          capabilities.isGuest ? _openPath('/signup') : _openPath('/profile'),
      onOpenKnowledge: () => _openPath('/knowledge'),
      onOpenInternalWorkspace: () => _openWhenAllowed(
        allowed: capabilities.canAccessInternalWorkspace,
        path: '/internal-workspace',
        capabilities: capabilities,
      ),
      onOpenCustomers: () => _openWhenAllowed(
        allowed: canAccessRoute('/customers', capabilities),
        path: '/customers',
        capabilities: capabilities,
      ),
      onOpenTasks: () => _openWhenAllowed(
        allowed: canAccessRoute('/tasks', capabilities),
        path: '/tasks',
        capabilities: capabilities,
      ),
      onCreateLead: () => _openWhenAllowed(
        allowed: capabilities.canManageLeads,
        path: '/leads?action=create',
        capabilities: capabilities,
      ),
    );
  }

  Future<void> _showMoreSheet({bool fromRoute = false}) async {
    if (_isMoreSheetOpen) return;
    _isMoreSheetOpen = true;

    final authState = ref.read(authControllerProvider);
    final profile = ref
        .read(profileSummaryProvider)
        .maybeWhen(data: (profile) => profile, orElse: () => null);
    final mobileConfig =
        ref.read(mobileAppConfigProvider).value ?? MobileAppConfig.fallback;
    final capabilities = ref.read(effectiveCapabilitiesProvider);
    final unreadNotifications =
        ref.read(unreadNotificationsProvider).value ?? 0;

    var actionSelected = false;
    try {
      actionSelected = await showOmcMoreSheet(
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
          allowed: canAccessRoute('/dashboard', capabilities),
          path: '/dashboard',
          capabilities: capabilities,
        ),
        onOpenDocuments: () => _openWhenAllowed(
          allowed: _canOpenDocuments(capabilities),
          path: '/documents',
          capabilities: capabilities,
        ),
        onOpenPayments: () => _openWhenAllowed(
          allowed: canAccessRoute('/payments', capabilities),
          path: '/payments',
          capabilities: capabilities,
        ),
        onOpenNotifications: () => _openWhenAllowed(
          allowed: canAccessRoute('/notifications', capabilities),
          path: '/notifications',
          capabilities: capabilities,
        ),
        onOpenTaxCalculator: () => _openPath('/tax-calculator'),
        onOpenExpenseTracker: () => _openPath('/expense-tracker'),
        onOpenBudget: () => _openWhenAllowed(
          allowed: canAccessRoute('/expense-budget', capabilities),
          path: '/expense-budget',
          capabilities: capabilities,
        ),
        onOpenKnowledge: () => _openPath('/knowledge'),
        onOpenSupport: () => _openPath('/support'),
        onOpenProfile: () => _openWhenAllowed(
          allowed: canAccessRoute('/profile', capabilities),
          path: '/profile',
          capabilities: capabilities,
        ),
        onOpenSettings: () => _openWhenAllowed(
          allowed: canAccessRoute('/settings', capabilities),
          path: '/settings',
          capabilities: capabilities,
        ),
        onOpenInternalWorkspace: () => _openWhenAllowed(
          allowed: capabilities.canAccessInternalWorkspace,
          path: '/internal-workspace',
          capabilities: capabilities,
        ),
        onOpenCustomers: () => _openWhenAllowed(
          allowed: canAccessRoute('/customers', capabilities),
          path: '/customers',
          capabilities: capabilities,
        ),
        onOpenMyReferrals: () => _openWhenAllowed(
          allowed: canAccessRoute('/my-referrals', capabilities),
          path: '/my-referrals',
          capabilities: capabilities,
        ),
        onOpenLeads: () => _openWhenAllowed(
          allowed: canAccessRoute('/leads', capabilities),
          path: '/leads',
          capabilities: capabilities,
        ),
        onOpenTasks: () => _openWhenAllowed(
          allowed: canAccessRoute('/tasks', capabilities),
          path: '/tasks',
          capabilities: capabilities,
        ),
        onLogout: authState.status == AuthStatus.guest
            ? () => context.go('/login')
            : _logout,
      );
    } finally {
      _isMoreSheetOpen = false;
    }

    if (!mounted || !fromRoute || actionSelected) return;
    final state = GoRouterState.of(context);
    if (state.uri.path == '/more') {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(effectiveCapabilitiesProvider);
    final unreadNotifications =
        ref.watch(unreadNotificationsProvider).value ?? 0;
    final mobileConfig =
        ref.watch(mobileAppConfigProvider).value ?? MobileAppConfig.fallback;
    final primaryColor = appPrimaryColorFor(
      mobileConfig.branding.primaryColorFamily,
    );
    return AppBackNavigationGuard(
      fallbackLocation: '/home',
      child: Scaffold(
        extendBody: false,
        body: widget.navigationShell,
        bottomNavigationBar: OmcBottomNav(
          selectedIndex: widget.navigationShell.currentIndex,
          notificationBadgeCount: unreadNotifications,
          primaryColor: primaryColor,
          onTabSelected: _selectTab,
          onQuickActions: _showQuickActionsSheet,
          onMore: _showMoreSheet,
          isInternal: _isInternal(capabilities),
        ),
      ),
    );
  }
}
