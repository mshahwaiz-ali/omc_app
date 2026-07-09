import 'package:flutter/material.dart';

import '../theme.dart';
import 'omc_nav_models.dart';

class OmcBottomNav extends StatelessWidget {
  const OmcBottomNav({
    required this.selectedIndex,
    required this.notificationBadgeCount,
    required this.onTabSelected,
    required this.onQuickActions,
    required this.onMore,
    super.key,
  });

  final int selectedIndex;
  final int notificationBadgeCount;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onQuickActions;
  final VoidCallback onMore;

  static const List<OmcBottomNavItem> _items = [
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
      label: 'Track',
      icon: Icons.timeline_outlined,
      activeIcon: Icons.timeline_rounded,
      shellIndex: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding > 0 ? 8 : 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border, width: 1),
            ),
            child: Row(
              children: [
                Expanded(child: _NavTab(item: _items[0], selectedIndex: selectedIndex, onSelected: onTabSelected)),
                Expanded(child: _NavTab(item: _items[1], selectedIndex: selectedIndex, onSelected: onTabSelected)),
                _CenterActionButton(onTap: onQuickActions),
                Expanded(child: _NavTab(item: _items[2], selectedIndex: selectedIndex, onSelected: onTabSelected)),
                Expanded(
                  child: _ActionTab(
                    label: 'More',
                    icon: Icons.more_horiz_rounded,
                    badgeCount: notificationBadgeCount,
                    isSelected: selectedIndex >= 3,
                    onTap: onMore,
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

class _CenterActionButton extends StatelessWidget {
  const _CenterActionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: AppTheme.primaryRed,
        borderRadius: BorderRadius.circular(18),
        elevation: 5,
        shadowColor: AppTheme.primaryRed.withValues(alpha: 0.24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: const SizedBox(
            width: 54,
            height: 54,
            child: Icon(Icons.add_rounded, color: Colors.white, size: 29),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.selectedIndex,
    required this.onSelected,
  });

  final OmcBottomNavItem item;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return _ActionTab(
      label: item.label,
      icon: selectedIndex == item.shellIndex ? item.activeIcon : item.icon,
      isSelected: selectedIndex == item.shellIndex,
      onTap: () => onSelected(item.shellIndex),
    );
  }
}

class _ActionTab extends StatelessWidget {
  const _ActionTab({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.primaryRed : AppTheme.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 54,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryRed.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSlide(
                offset: isSelected ? const Offset(0, -0.04) : Offset.zero,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, color: color, size: 21),
                    if (badgeCount > 0)
                      Positioned(top: -8, right: -12, child: _CompactBadge(count: badgeCount)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              AnimatedOpacity(
                opacity: isSelected ? 1 : 0.78,
                duration: const Duration(milliseconds: 160),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  ),
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
