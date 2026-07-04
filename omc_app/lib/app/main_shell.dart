import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/premium_card.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/service_catalogue/presentation/service_catalogue_screen.dart';
import '../features/support/presentation/support_screen.dart';
import 'theme.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

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
      const _PlaceholderScreen(
        title: 'Calculator',
        subtitle: 'Salary and business tax estimates are next in the roadmap.',
        icon: Icons.calculate_rounded,
      ),
      const SupportScreen(),
      _MoreScreen(
        onOpenProfile: () => context.push('/profile'),
        onOpenSettings: () => context.push('/settings'),
        onOpenNotifications: () => context.push('/notifications'),
        onOpenInternalWorkspace: () => context.push('/internal-workspace'),
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Services',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate_rounded),
            label: 'Calculator',
          ),
          NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent_rounded),
            label: 'Support',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen({
    required this.onOpenProfile,
    required this.onOpenSettings,
    required this.onOpenNotifications,
    required this.onOpenInternalWorkspace,
    required this.onLogout,
  });

  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenInternalWorkspace;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const Text(
            'More',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
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

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
