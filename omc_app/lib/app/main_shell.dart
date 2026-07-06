import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/premium_card.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/service_catalogue/presentation/service_catalogue_screen.dart';
import '../features/support/presentation/support_screen.dart';
import '../features/tax_calculator/presentation/tax_calculator_screen.dart';
import 'theme.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

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
      label: 'Calc',
      icon: Icons.calculate_outlined,
      activeIcon: Icons.calculate_rounded,
    ),
    _ShellNavItem(
      label: 'Support',
      icon: Icons.support_agent_outlined,
      activeIcon: Icons.support_agent_rounded,
    ),
    _ShellNavItem(
      label: 'More',
      icon: Icons.more_horiz_outlined,
      activeIcon: Icons.more_horiz_rounded,
    ),
  ];

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();

    if (!mounted) return;

    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onOpenServices: () => _selectTab(1),
        onOpenCalculator: () => _selectTab(2),
        onOpenSupport: () => _selectTab(3),
        onOpenNotifications: () => context.push('/notifications'),
      ),
      const ServiceCatalogueScreen(),
      const TaxCalculatorScreen(),
      const SupportScreen(),
      _MoreScreen(
        onOpenDashboard: () => context.push('/dashboard'),
        onOpenProfile: () => context.push('/profile'),
        onOpenSettings: () => context.push('/settings'),
        onOpenNotifications: () => context.push('/notifications'),
        onOpenKnowledge: () => context.push('/knowledge'),
        onOpenExpenseTracker: () => context.push('/expense-tracker'),
        onOpenInternalWorkspace: () => context.push('/internal-workspace'),
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _FloatingShellNav(
        selectedIndex: _currentIndex,
        items: _navItems,
        onSelected: _selectTab,
      ),
    );
  }
}

class _FloatingShellNav extends StatelessWidget {
  const _FloatingShellNav({
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<_ShellNavItem> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, bottomPadding > 0 ? 8 : 12),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: AppTheme.primaryRed.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              for (int index = 0; index < items.length; index++)
                Expanded(
                  child: _FloatingShellNavItem(
                    item: items[index],
                    isSelected: selectedIndex == index,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
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
    required this.onTap,
  });

  final _ShellNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Colors.white : AppTheme.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryRed, AppTheme.darkRed],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryRed.withValues(alpha: 0.20),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? item.activeIcon : item.icon,
                color: color,
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: isSelected ? 10.5 : 10,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: -0.1,
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
    required this.onOpenProfile,
    required this.onOpenSettings,
    required this.onOpenNotifications,
    required this.onOpenKnowledge,
    required this.onOpenExpenseTracker,
    required this.onOpenInternalWorkspace,
    required this.onLogout,
  });

  final VoidCallback onOpenDashboard;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenKnowledge;
  final VoidCallback onOpenExpenseTracker;
  final VoidCallback onOpenInternalWorkspace;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
        children: [
          const Text(
            'More',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Profile, preferences and workspace shortcuts.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MoreTile(
                  icon: Icons.analytics_outlined,
                  title: 'Dashboard',
                  subtitle: 'Cases, documents and service analytics',
                  onTap: onOpenDashboard,
                ),
                const _DividerIndent(),
                _MoreTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Profile',
                  subtitle: 'Personal info and account details',
                  onTap: onOpenProfile,
                ),
                const _DividerIndent(),
                _MoreTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle: 'Service updates and tax alerts',
                  onTap: onOpenNotifications,
                ),
                const _DividerIndent(),
                _MoreTile(
                  icon: Icons.menu_book_outlined,
                  title: 'Knowledge & News',
                  subtitle: 'Tax guides, FBR updates and OMC news',
                  onTap: onOpenKnowledge,
                ),
                const _DividerIndent(),
                _MoreTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Expense Tracker',
                  subtitle: 'Track income, expenses and balance locally',
                  onTap: onOpenExpenseTracker,
                ),
                const _DividerIndent(),
                _MoreTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  subtitle: 'Theme, notifications and preferences',
                  onTap: onOpenSettings,
                ),
                const _DividerIndent(),
                _MoreTile(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Internal Workspace',
                  subtitle: 'Leads, customers, tasks and payments',
                  onTap: onOpenInternalWorkspace,
                ),
                const _DividerIndent(),
                _MoreTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  subtitle: 'Clear secure session and return to login',
                  isDestructive: true,
                  onTap: onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade700 : AppTheme.primaryRed;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w900,
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
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
    );
  }
}

class _DividerIndent extends StatelessWidget {
  const _DividerIndent();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 78, endIndent: 18);
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
