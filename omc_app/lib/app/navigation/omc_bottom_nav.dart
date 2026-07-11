import 'package:flutter/material.dart';

import '../../core/widgets/omc_premium.dart';
import '../theme.dart';
import 'omc_nav_models.dart';

class OmcBottomNav extends StatelessWidget {
  const OmcBottomNav({
    required this.selectedIndex,
    required this.notificationBadgeCount,
    required this.onTabSelected,
    required this.onQuickActions,
    required this.onMore,
    this.isInternal = false,
    super.key,
  });

  final int selectedIndex;
  final int notificationBadgeCount;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onQuickActions;
  final VoidCallback onMore;
  final bool isInternal;

  static const List<OmcBottomNavItem> _customerItems = [
    OmcBottomNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      shellIndex: 0,
    ),
    OmcBottomNavItem(
      label: 'Services',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      shellIndex: 1,
    ),
    OmcBottomNavItem(
      label: 'Requests',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      shellIndex: 2,
    ),
  ];

  static const List<OmcBottomNavItem> _adminItems = [
    OmcBottomNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      shellIndex: 0,
    ),
    OmcBottomNavItem(
      label: 'Services',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      shellIndex: 1,
    ),
    OmcBottomNavItem(
      label: 'Cases',
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check_rounded,
      shellIndex: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final items = isInternal ? _adminItems : _customerItems;

    return Material(
      color: Colors.white,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Container(
          height: 72,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _NavTab(
                  item: items[0],
                  selected: selectedIndex == 0,
                  onTap: () => onTabSelected(0),
                ),
              ),
              Expanded(
                child: _NavTab(
                  item: items[1],
                  selected: selectedIndex == 1,
                  onTap: () => onTabSelected(1),
                ),
              ),
              _CenterActionButton(
                onTap: onQuickActions,
                isInternal: isInternal,
              ),
              Expanded(
                child: _NavTab(
                  item: items[2],
                  selected: selectedIndex == 2,
                  onTap: () => onTabSelected(2),
                ),
              ),
              Expanded(
                child: _MoreTab(
                  selected: selectedIndex >= 3,
                  badgeCount: notificationBadgeCount,
                  onTap: onMore,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterActionButton extends StatelessWidget {
  const _CenterActionButton({required this.onTap, required this.isInternal});

  final VoidCallback onTap;
  final bool isInternal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Semantics(
        button: true,
        label: isInternal ? 'Open admin quick actions' : 'Open quick actions',
        child: Material(
          color: OmcPremium.ink,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: OmcPremium.ink,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: OmcPremium.ink.withValues(alpha: 0.20),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(Icons.add_rounded, color: Colors.white, size: 27),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final OmcBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = selected ? item.activeIcon : item.icon;
    final color = selected ? OmcPremium.tax : AppTheme.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 58,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected
                ? OmcPremium.tax.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 180),
                scale: selected ? 1.05 : 1,
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreTab extends StatelessWidget {
  const _MoreTab({
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? OmcPremium.tax : AppTheme.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 58,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected
                ? OmcPremium.tax.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.more_horiz_rounded, color: color, size: 23),
                  if (badgeCount > 0)
                    Positioned(
                      top: -7,
                      right: -12,
                      child: _Badge(count: badgeCount),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'More',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 17),
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: OmcPremium.services,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}
