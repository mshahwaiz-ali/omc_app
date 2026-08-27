import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/interaction/app_feedback.dart';
import '../../core/diagnostics/omc_widget_keys.dart';
import '../../core/widgets/omc_premium.dart';
import '../design_tokens.dart';
import '../theme.dart';
import 'omc_nav_models.dart';

class OmcBottomNav extends StatelessWidget {
  const OmcBottomNav({
    required this.selectedIndex,
    required this.notificationBadgeCount,
    required this.onTabSelected,
    required this.onQuickActions,
    required this.onMore,
    required this.primaryColor,
    this.onAccentColor,
    this.isInternal = false,
    super.key,
  });

  final int selectedIndex;
  final int notificationBadgeCount;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onQuickActions;
  final VoidCallback onMore;
  final Color primaryColor;
  final Color? onAccentColor;
  final bool isInternal;

  static const _customerItems = <OmcBottomNavItem>[
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

  static const _adminItems = <OmcBottomNavItem>[
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
    final readableForeground =
        onAccentColor ??
        (ThemeData.estimateBrightnessForColor(primaryColor) == Brightness.dark
            ? Colors.white
            : const Color(0xFF111827));

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final scaleGrowth = (textScale - 1).clamp(0.0, 2.0).toDouble();
    final extraHeight = scaleGrowth * 14;
    final navigationHeight = 72 + extraHeight;
    final tabHeight = 58 + extraHeight;

    return Material(
      color: Colors.white,
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          key: const ValueKey('omc_bottom_nav_surface'),
          height: navigationHeight,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: AppTheme.border)),
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
                  accentColor: primaryColor,
                  height: tabHeight,
                  semanticsOrder: 0,
                  onTap: () => onTabSelected(0),
                ),
              ),
              Expanded(
                child: _NavTab(
                  item: items[1],
                  selected: selectedIndex == 1,
                  accentColor: primaryColor,
                  height: tabHeight,
                  semanticsOrder: 1,
                  onTap: () => onTabSelected(1),
                ),
              ),
              _CenterActionButton(
                onTap: onQuickActions,
                isInternal: isInternal,
                accentColor: primaryColor,
                onAccentColor: readableForeground,
              ),
              Expanded(
                child: _NavTab(
                  item: items[2],
                  selected: selectedIndex == 2,
                  accentColor: primaryColor,
                  height: tabHeight,
                  semanticsOrder: 3,
                  onTap: () => onTabSelected(2),
                ),
              ),
              Expanded(
                child: _MoreTab(
                  selected: selectedIndex >= 3,
                  badgeCount: notificationBadgeCount,
                  accentColor: primaryColor,
                  height: tabHeight,
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
  const _CenterActionButton({
    required this.onTap,
    required this.isInternal,
    required this.accentColor,
    required this.onAccentColor,
  });

  final VoidCallback onTap;
  final bool isInternal;
  final Color accentColor;
  final Color onAccentColor;

  @override
  Widget build(BuildContext context) {
    final label = isInternal ? 'Open work quick actions' : 'Open quick actions';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          label: label,
          hint: 'Shows actions available to your account',
          sortKey: const OrdinalSortKey(2),
          excludeSemantics: true,
          child: Material(
            color: accentColor,
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: InkWell(
              onTap: () {
                AppFeedback.action();
                onTap();
              },
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: Container(
                constraints: AppTouchTarget.constraints,
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.20),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(Icons.add_rounded, color: onAccentColor, size: 27),
              ),
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
    required this.accentColor,
    required this.height,
    required this.semanticsOrder,
    required this.onTap,
  });

  final OmcBottomNavItem item;
  final bool selected;
  final Color accentColor;
  final double height;
  final double semanticsOrder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? accentColor : AppTheme.textMuted;
    final motionDuration = AppMotion.durationFor(context, AppMotion.quick);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      sortKey: OrdinalSortKey(semanticsOrder),
      excludeSemantics: true,
      child: Material(
        key: switch (item.shellIndex) {
          0 => OmcWidgetKeys.navHome,
          1 => OmcWidgetKeys.navServices,
          _ => OmcWidgetKeys.navTrack,
        },
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!selected) AppFeedback.selection();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: AnimatedContainer(
            duration: motionDuration,
            curve: Curves.easeOutCubic,
            height: height,
            constraints: const BoxConstraints(
              minHeight: AppTouchTarget.minimum,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: selected
                  ? accentColor.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  duration: motionDuration,
                  scale: selected ? 1.05 : 1,
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      height: 1.1,
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

class _MoreTab extends StatelessWidget {
  const _MoreTab({
    required this.selected,
    required this.badgeCount,
    required this.accentColor,
    required this.height,
    required this.onTap,
  });

  final bool selected;
  final int badgeCount;
  final Color accentColor;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? accentColor : AppTheme.textMuted;
    final semanticLabel = badgeCount > 0
        ? 'More, $badgeCount unread notifications'
        : 'More';

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      sortKey: const OrdinalSortKey(4),
      excludeSemantics: true,
      child: Material(
        key: OmcWidgetKeys.navMore,
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AppFeedback.selection();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: AnimatedContainer(
            duration: AppMotion.durationFor(context, AppMotion.quick),
            height: height,
            constraints: const BoxConstraints(
              minHeight: AppTouchTarget.minimum,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: selected
                  ? accentColor.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                        child: ExcludeSemantics(
                          child: _Badge(count: badgeCount),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
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
        borderRadius: BorderRadius.circular(AppRadius.pill),
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
