import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/app_config/data/mobile_app_config.dart';
import '../features/app_config/data/mobile_app_config_repository.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_state.dart';
import '../features/documents/presentation/documents_screen.dart';
import '../features/documents/presentation/internal_document_review_screen.dart';
import '../features/home/data/home_dashboard_repository.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/service_catalogue/presentation/service_catalogue_screen.dart';
import '../features/service_requests/presentation/internal_service_track_screen.dart';
import '../features/service_requests/presentation/my_services_screen.dart';
import 'navigation/omc_bottom_nav.dart';
import 'navigation/omc_more_sheet.dart';
import 'navigation/omc_quick_actions_sheet.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({this.initialIndex = 0, super.key});

  final int initialIndex;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = _normalTabIndex(widget.initialIndex);
    if (widget.initialIndex == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMoreSheet();
      });
    }
  }

  int _normalTabIndex(int index) => index >= 0 && index <= 3 ? index : 0;

  void _selectTab(int index) {
    final capabilities = _currentCapabilities();
    if (_isInternal(capabilities)) {
      final path = switch (index) {
        0 => '/internal-workspace',
        1 => '/customers',
        2 => '/internal-workspace/service-cases',
        _ => '/internal-workspace',
      };
      context.go(path);
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
    setState(() => _currentIndex = index);
  }

  AuthCapabilities _currentCapabilities() {
    final profile = ref
        .read(profileSummaryProvider)
        .maybeWhen(data: (profile) => profile, orElse: () => null);
    return profile?.capabilities ??
        ref.read(authControllerProvider).capabilities;
  }

  bool _isInternal(AuthCapabilities capabilities) {
    return capabilities.canAccessInternalWorkspace || capabilities.isInternal;
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
    await ref.read(authControllerProvider.notifier).logout();
    ref.invalidate(profileSummaryProvider);
    if (!mounted) return;
    context.go('/login');
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
        allowed:
            capabilities.canViewPayments ||
            capabilities.canReviewPayments ||
            capabilities.isApproved ||
            capabilities.isInternal,
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
      onOpenInternalWorkspace: () => _openPath('/internal-workspace'),
      onOpenCustomers: () => _openPath('/customers'),
      onOpenTasks: () => _openPath('/tasks'),
      onCreateLead: () => _openPath('/leads?action=create'),
      onCreateTask: () => _openPath('/tasks?action=create'),
    );
  }

  void _showMoreSheet() {
    final authState = ref.read(authControllerProvider);
    final profile = ref
        .read(profileSummaryProvider)
        .maybeWhen(data: (profile) => profile, orElse: () => null);
    final mobileConfig =
        ref.read(mobileAppConfigProvider).value ?? MobileAppConfig.fallback;
    final capabilities = profile?.capabilities ?? authState.capabilities;
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
        allowed:
            capabilities.canViewCustomerDashboard ||
            capabilities.canAccessCustomerDashboard ||
            capabilities.canAccessInternalWorkspace,
        path: '/dashboard',
        capabilities: capabilities,
      ),
      onOpenDocuments: () => _openWhenAllowed(
        allowed: _canOpenDocuments(capabilities),
        path: '/documents',
        capabilities: capabilities,
      ),
      onOpenPayments: () => _openWhenAllowed(
        allowed:
            capabilities.canViewPayments ||
            capabilities.canReviewPayments ||
            capabilities.isApproved ||
            capabilities.isInternal,
        path: '/payments',
        capabilities: capabilities,
      ),
      onOpenNotifications: () => _openWhenAllowed(
        allowed:
            capabilities.canViewCustomerNotifications ||
            capabilities.isApproved ||
            capabilities.isInternal ||
            capabilities.canAccessInternalWorkspace,
        path: '/notifications',
        capabilities: capabilities,
      ),
      onOpenTaxCalculator: () => _openPath('/tax-calculator'),
      onOpenExpenseTracker: () => _openPath('/expense-tracker'),
      onOpenBudget: () => _openWhenAllowed(
        allowed: capabilities.isApproved,
        path: '/expense-budget',
        capabilities: capabilities,
      ),
      onOpenKnowledge: () => _openPath('/knowledge'),
      onOpenSupport: () => _openPath('/support'),
      onOpenProfile: () => _openWhenAllowed(
        allowed: !capabilities.isGuest,
        path: '/profile',
        capabilities: capabilities,
      ),
      onOpenSettings: () => _openWhenAllowed(
        allowed: !capabilities.isGuest,
        path: '/settings',
        capabilities: capabilities,
      ),
      onOpenInternalWorkspace: () => _openPath('/internal-workspace'),
      onOpenInternalCases: () => _openPath('/internal-workspace/service-cases'),
      onOpenCustomers: () => _openPath('/customers'),
      onOpenLeads: () => _openPath('/leads'),
      onOpenTasks: () => _openPath('/tasks'),
      onLogout: authState.status == AuthStatus.guest
          ? () => context.go('/login')
          : _logout,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final profileSummary = ref.watch(profileSummaryProvider);
    final profile = profileSummary.maybeWhen(
      data: (profile) => profile,
      orElse: () => null,
    );
    final capabilities = profile?.capabilities ?? authState.capabilities;
    final unreadNotifications =
        ref.watch(homeDashboardSummaryProvider).value?.unreadNotifications ?? 0;
    final canUseInternalTrack =
        capabilities.canAccessInternalWorkspace || capabilities.isInternal;
    final canUseInternalDocs =
        capabilities.canReviewDocuments ||
        capabilities.canAccessInternalWorkspace ||
        capabilities.isInternal;

    final screens = [
      HomeScreen(
        onOpenServices: () => _selectTab(1),
        onOpenCalculator: () => context.push('/tax-calculator'),
        onOpenSupport: () => context.push('/support'),
        onOpenNotifications: () => context.push('/notifications'),
      ),
      const ServiceCatalogueScreen(),
      canUseInternalTrack
          ? const InternalServiceTrackScreen()
          : const MyServicesScreen(),
      canUseInternalDocs
          ? const InternalDocumentReviewScreen()
          : const DocumentsScreen(),
    ];

    return Scaffold(
      extendBody: false,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: OmcBottomNav(
        selectedIndex: _currentIndex,
        notificationBadgeCount: unreadNotifications,
        onTabSelected: _selectTab,
        onQuickActions: _showQuickActionsSheet,
        onMore: _showMoreSheet,
        isInternal: _isInternal(capabilities),
      ),
    );
  }
}
