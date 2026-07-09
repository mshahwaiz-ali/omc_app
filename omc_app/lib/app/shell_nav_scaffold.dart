import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_state.dart';
import '../features/home/data/home_dashboard_repository.dart';
import '../features/profile/data/profile_repository.dart';
import 'theme.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileSummaryProvider).maybeWhen(
          data: (profile) => profile,
          orElse: () => null,
        );
    final authState = ref.watch(authControllerProvider);
    final capabilities = profile?.capabilities ?? authState.capabilities;
    final unreadNotifications =
        ref.watch(homeDashboardSummaryProvider).value?.unreadNotifications ?? 0;

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: _FloatingShellNav(
        selectedIndex: selectedIndex,
        items: _navItems,
        notificationBadgeCount: unreadNotifications,
        onSelected: (index) => _openTab(context, capabilities, index),
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
      moreIndex => '/more',
      _ => '/home',
    };

    context.go(path);
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
        capabilities.isApproved;
  }

  void _showLockedSnack(
    BuildContext context,
    AuthCapabilities capabilities,
  ) {
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
                    height: 30,
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
