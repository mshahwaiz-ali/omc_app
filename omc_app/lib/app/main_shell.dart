import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/premium_card.dart';
import '../features/app_config/data/mobile_app_config.dart';
import '../features/app_config/data/mobile_app_config_repository.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_state.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/documents/presentation/documents_screen.dart';
import '../features/home/data/home_dashboard_repository.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/service_catalogue/presentation/service_catalogue_screen.dart';
import '../features/service_requests/presentation/my_services_screen.dart';
import 'theme.dart';

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
    _currentIndex = widget.initialIndex;
  }

  static const List<_ShellNavItem> _navItems = [
    _ShellNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _ShellNavItem(
      label: 'Services',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
    ),
    _ShellNavItem(
      label: 'Track',
      icon: Icons.timeline_outlined,
      activeIcon: Icons.timeline_rounded,
    ),
    _ShellNavItem(
      label: 'Docs',
      icon: Icons.folder_copy_outlined,
      activeIcon: Icons.folder_copy_rounded,
    ),
    _ShellNavItem(
      label: 'More',
      icon: Icons.more_horiz_outlined,
      activeIcon: Icons.more_horiz_rounded,
    ),
  ];

  void _selectTab(int index) {
    final capabilities = _currentCapabilities();
    if (index == 2 && !_canOpenTrack(capabilities)) {
      _showLockedSnack(capabilities);
      return;
    }
    if (index == 3 && !_canOpenDocuments(capabilities)) {
      _showLockedSnack(capabilities);
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  AuthCapabilities _currentCapabilities() {
    final profile = ref
        .read(profileSummaryProvider)
        .maybeWhen(data: (profile) => profile, orElse: () => null);
    return profile?.capabilities ??
        ref.read(authControllerProvider).capabilities;
  }

  bool _canOpenTrack(AuthCapabilities capabilities) {
    return capabilities.canViewCustomerDashboard ||
        capabilities.canAccessInternalWorkspace;
  }

  bool _canOpenDocuments(AuthCapabilities capabilities) {
    return capabilities.canViewDocuments || capabilities.canReviewDocuments;
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
      return 'Your account is under review. OMC will enable this after approval.';
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final profileSummary = ref.watch(profileSummaryProvider);
    final mobileConfig =
        ref.watch(mobileAppConfigProvider).value ?? MobileAppConfig.fallback;
    final profile = profileSummary.maybeWhen(
      data: (profile) => profile,
      orElse: () => null,
    );
    final capabilities = profile?.capabilities ?? authState.capabilities;
    final unreadNotifications =
        ref.watch(homeDashboardSummaryProvider).value?.unreadNotifications ?? 0;

    final screens = [
      HomeScreen(
        onOpenServices: () => _selectTab(1),
        onOpenCalculator: () => context.push('/tax-calculator'),
        onOpenSupport: () => context.push('/support'),
        onOpenNotifications: () => context.push('/notifications'),
      ),
      const ServiceCatalogueScreen(),
      const MyServicesScreen(),
      const DocumentsScreen(),
      _MoreScreen(
        onOpenDashboard: () => _openWhenAllowed(
          allowed:
              capabilities.canViewCustomerDashboard ||
              capabilities.canAccessInternalWorkspace,
          path: '/dashboard',
          capabilities: capabilities,
        ),
        onOpenPayments: () => _openWhenAllowed(
          allowed:
              capabilities.canViewPayments || capabilities.canReviewPayments,
          path: '/payments',
          capabilities: capabilities,
        ),
        onOpenTaxCalculator: () => context.push('/tax-calculator'),
        onOpenSupport: () => context.push('/support'),
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
        onOpenNotifications: () => _openWhenAllowed(
          allowed:
              capabilities.canViewCustomerNotifications ||
              capabilities.canAccessInternalWorkspace,
          path: '/notifications',
          capabilities: capabilities,
        ),
        onOpenKnowledge: () => context.push('/knowledge'),
        onOpenExpenseTracker: () => _openWhenAllowed(
          allowed: capabilities.isApproved || capabilities.isInternal,
          path: '/expense-tracker',
          capabilities: capabilities,
        ),
        features: mobileConfig.features,
        displayName: profile?.displayName ?? authState.displayName,
        companyName: profile?.companyName ?? authState.companyName,
        customerStatus: profile?.status ?? authState.customerStatus,
        capabilities: capabilities,
        unreadNotifications: unreadNotifications,
        isGuest: authState.status == AuthStatus.guest,
        canAccessInternalWorkspace:
            capabilities.canAccessInternalWorkspace &&
            mobileConfig.features.internalWorkspaceEnabled,
        onOpenInternalWorkspace: () => context.push('/internal-workspace'),
        onLogout: authState.status == AuthStatus.guest
            ? () => context.go('/login')
            : _logout,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _FloatingShellNav(
        selectedIndex: _currentIndex,
        items: _navItems,
        notificationBadgeCount: unreadNotifications,
        onSelected: _selectTab,
      ),
    );
  }
}

class _FloatingShellNav extends StatelessWidget {
  const _FloatingShellNav({
    required this.selectedIndex,
    required this.items,
    required this.notificationBadgeCount,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<_ShellNavItem> items;
  final int notificationBadgeCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, bottomPadding > 0 ? 8 : 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: AppTheme.primaryRed.withValues(alpha: 0.10),
                blurRadius: 26,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            height: 76,
            padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.98),
                  const Color(0xFFFFF7F7).withValues(alpha: 0.96),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.92),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                for (int index = 0; index < items.length; index++)
                  Expanded(
                    child: _FloatingShellNavItem(
                      item: items[index],
                      isSelected: selectedIndex == index,
                      badgeCount: index == 4 ? notificationBadgeCount : 0,
                      onTap: () => onSelected(index),
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

class _FloatingShellNavItem extends StatelessWidget {
  const _FloatingShellNavItem({
    required this.item,
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
  });

  final _ShellNavItem item;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = isSelected ? AppTheme.primaryRed : AppTheme.textSecondary;
    final textColor = isSelected ? AppTheme.primaryRed : AppTheme.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF0E8E8) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.85),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: isSelected ? 36 : 30,
                    height: isSelected ? 30 : 30,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.82)
                          : AppTheme.primaryRed.withValues(alpha: 0.045),
                      borderRadius: BorderRadius.circular(13),
                      border: isSelected
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                              width: 1,
                            )
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: iconColor,
                      size: isSelected ? 19 : 18,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -7,
                      right: -9,
                      child: _CompactBadge(count: badgeCount),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: textColor,
                  fontSize: isSelected ? 10.7 : 10,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: -0.15,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen({
    required this.onOpenDashboard,
    required this.onOpenPayments,
    required this.onOpenTaxCalculator,
    required this.onOpenSupport,
    required this.onOpenProfile,
    required this.onOpenSettings,
    required this.onOpenNotifications,
    required this.onOpenKnowledge,
    required this.onOpenExpenseTracker,
    required this.features,
    this.displayName,
    this.companyName,
    this.customerStatus,
    required this.capabilities,
    required this.unreadNotifications,
    required this.isGuest,
    required this.canAccessInternalWorkspace,
    required this.onOpenInternalWorkspace,
    required this.onLogout,
  });

  final VoidCallback onOpenDashboard;
  final VoidCallback onOpenPayments;
  final VoidCallback onOpenTaxCalculator;
  final VoidCallback onOpenSupport;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenKnowledge;
  final VoidCallback onOpenExpenseTracker;
  final MobileFeatureConfig features;
  final String? displayName;
  final String? companyName;
  final String? customerStatus;
  final AuthCapabilities capabilities;
  final int unreadNotifications;
  final bool isGuest;
  final bool canAccessInternalWorkspace;
  final VoidCallback onOpenInternalWorkspace;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
        children: [
          _MoreHeader(
            displayName: displayName,
            companyName: companyName,
            customerStatus: customerStatus,
          ),
          if (capabilities.isGuest ||
              capabilities.isPending ||
              capabilities.isRejected) ...[
            const SizedBox(height: 12),
            _AccessStatusNote(capabilities: capabilities),
          ],
          const SizedBox(height: 18),
          _MoreGroup(
            title: 'Account',
            children: [
              _MoreTile(
                icon: Icons.person_outline_rounded,
                title: 'Profile',
                subtitle: 'Personal info and account details',
                onTap: onOpenProfile,
              ),
              _MoreTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: 'Service updates and tax alerts',
                badgeCount: unreadNotifications,
                onTap: onOpenNotifications,
              ),
              _MoreTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Theme, notifications and preferences',
                onTap: onOpenSettings,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MoreGroup(
            title: 'Services',
            children: [
              _MoreTile(
                icon: Icons.analytics_outlined,
                title: 'Dashboard',
                subtitle: 'Your service summary, documents and recent activity',
                onTap: onOpenDashboard,
              ),
              if (features.paymentsEnabled)
                _MoreTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Payments',
                  subtitle: 'Invoices, dues and receipt uploads',
                  onTap: onOpenPayments,
                ),
              if (features.taxCalculatorEnabled)
                _MoreTile(
                  icon: Icons.calculate_outlined,
                  title: 'Tax Calculator',
                  subtitle: 'Estimate salary tax quickly',
                  onTap: onOpenTaxCalculator,
                ),
              if (features.knowledgeEnabled)
                _MoreTile(
                  icon: Icons.menu_book_outlined,
                  title: 'Knowledge & News',
                  subtitle: 'Tax guides, FBR updates and OMC news',
                  onTap: onOpenKnowledge,
                ),
              if (features.expenseTrackerEnabled)
                _MoreTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Personal Expense Tracker',
                  subtitle: 'Track income, expenses and balance on this device',
                  onTap: onOpenExpenseTracker,
                ),
            ],
          ),
          if (features.supportEnabled) ...[
            const SizedBox(height: 16),
            _MoreGroup(
              title: 'Help',
              children: [
                _MoreTile(
                  icon: Icons.support_agent_outlined,
                  title: 'Support',
                  subtitle: 'Tickets, WhatsApp and contact channels',
                  onTap: onOpenSupport,
                ),
              ],
            ),
          ],
          if (canAccessInternalWorkspace) ...[
            const SizedBox(height: 16),
            _MoreGroup(
              title: 'Workspace',
              children: [
                _MoreTile(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Internal Workspace',
                  subtitle: 'Leads, customers, tasks and payments',
                  onTap: onOpenInternalWorkspace,
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: _MoreTile(
              icon: isGuest ? Icons.login_rounded : Icons.logout_rounded,
              title: isGuest ? 'Login' : 'Logout',
              subtitle: isGuest
                  ? 'Sign in to access your protected OMC workspace'
                  : 'Clear secure session and return to login',
              isDestructive: !isGuest,
              showChevron: false,
              onTap: onLogout,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreHeader extends StatelessWidget {
  const _MoreHeader({this.displayName, this.companyName, this.customerStatus});

  final String? displayName;
  final String? companyName;
  final String? customerStatus;

  String get _headerSubtitle {
    final company = _cleanLabel(companyName);
    final status = _cleanLabel(customerStatus);

    if (company != null && status != null) return '$company • $status';
    if (company != null) return company;
    if (status != null) return status;
    return 'Profile, preferences and business shortcuts.';
  }

  String? _cleanLabel(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryRed, AppTheme.darkRed],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryRed.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/logo_symbol_transparent.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.business_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _cleanLabel(displayName) ?? 'OMC Workspace',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _headerSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessStatusNote extends StatelessWidget {
  const _AccessStatusNote({required this.capabilities});

  final AuthCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final (icon, title, message) = switch (capabilities.accessState) {
      AccountAccessState.guest => (
        Icons.explore_outlined,
        'Guest mode',
        'Public services, knowledge, support contacts and tax tools are available.',
      ),
      AccountAccessState.pending => (
        Icons.hourglass_top_rounded,
        'Account under review',
        'OMC will enable requests, documents, payments and tickets after approval.',
      ),
      AccountAccessState.rejected => (
        Icons.block_rounded,
        'Approval required',
        'Protected services are unavailable for this account. Contact OMC support.',
      ),
      _ => (
        Icons.verified_user_outlined,
        'Approved access',
        'Protected services are enabled for this account.',
      ),
    };

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primaryRed, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreGroup extends StatelessWidget {
  const _MoreGroup({required this.title, required this.children});

  final String title;
  final List<_MoreTile> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const _DividerIndent(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
    this.showChevron = true,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool showChevron;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade700 : AppTheme.primaryRed;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -5,
              right: -7,
              child: _CompactBadge(count: badgeCount),
            ),
        ],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red.shade700 : AppTheme.textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 14.5,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: showChevron
          ? Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400)
          : null,
    );
  }
}

class _CompactBadge extends StatelessWidget {
  const _CompactBadge({required this.count});

  final int count;

  String get _label => count > 99 ? '99+' : count.toString();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        _label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _DividerIndent extends StatelessWidget {
  const _DividerIndent();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 74, endIndent: 16);
  }
}

class _ShellNavItem {
  const _ShellNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
