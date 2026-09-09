import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/interaction/app_feedback.dart';
import '../../core/diagnostics/omc_widget_keys.dart';
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
    final theme = Theme.of(context);
    final readableForeground = onAccentColor ?? theme.colorScheme.onPrimary;
    final selectedInk = theme.colorScheme.onPrimaryContainer;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          key: const ValueKey('omc_bottom_nav_surface'),
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: const Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _NavTab(
                  item: items[0],
                  selected: selectedIndex == 0,
                  accentColor: primaryColor,
                  selectedInk: selectedInk,
                  semanticsOrder: 0,
                  onTap: () => onTabSelected(0),
                ),
              ),
              Expanded(
                child: _NavTab(
                  item: items[1],
                  selected: selectedIndex == 1,
                  accentColor: primaryColor,
                  selectedInk: selectedInk,
                  semanticsOrder: 1,
                  onTap: () => onTabSelected(1),
                ),
              ),
              Expanded(
                child: _CenterActionButton(
                  onTap: onQuickActions,
                  isInternal: isInternal,
                  accentColor: primaryColor,
                  onAccentColor: readableForeground,
                  accentInk: selectedInk,
                ),
              ),
              Expanded(
                child: _NavTab(
                  item: items[2],
                  selected: selectedIndex == 2,
                  accentColor: primaryColor,
                  selectedInk: selectedInk,
                  semanticsOrder: 3,
                  onTap: () => onTabSelected(2),
                ),
              ),
              Expanded(
                child: _MoreTab(
                  selected: selectedIndex >= 3,
                  badgeCount: notificationBadgeCount,
                  accentColor: primaryColor,
                  selectedInk: selectedInk,
                  onAccentColor: readableForeground,
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
    required this.accentInk,
  });

  final VoidCallback onTap;
  final bool isInternal;
  final Color accentColor;
  final Color onAccentColor;
  final Color accentInk;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = isInternal
        ? 'Open work quick actions'
        : 'Open quick actions';

    return Tooltip(
      message: semanticLabel,
      child: Semantics(
        button: true,
        label: semanticLabel,
        hint: 'Shows actions available to your account',
        sortKey: const OrdinalSortKey(2),
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              AppFeedback.action();
              onTap();
            },
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: AppTouchTarget.minimum,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 2,
                vertical: AppSpacing.xxs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: onAccentColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Quick',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accentInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
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
    required this.selectedInk,
    required this.semanticsOrder,
    required this.onTap,
  });

  final OmcBottomNavItem item;
  final bool selected;
  final Color accentColor;
  final Color selectedInk;
  final double semanticsOrder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedInk : AppTheme.textCaption;
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
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: AnimatedContainer(
            duration: motionDuration,
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(
              minHeight: AppTouchTarget.minimum,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? accentColor.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedScale(
                  duration: motionDuration,
                  scale: selected ? 1.05 : 1,
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 3,
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    height: 1.2,
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
    required this.selectedInk,
    required this.onAccentColor,
    required this.onTap,
  });

  final bool selected;
  final int badgeCount;
  final Color accentColor;
  final Color selectedInk;
  final Color onAccentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedInk : AppTheme.textCaption;
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
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: AnimatedContainer(
            duration: AppMotion.durationFor(context, AppMotion.quick),
            constraints: const BoxConstraints(
              minHeight: AppTouchTarget.minimum,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? accentColor.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.more_horiz_rounded, color: color, size: 24),
                    if (badgeCount > 0)
                      Positioned(
                        top: -8,
                        right: -13,
                        child: ExcludeSemantics(
                          child: _Badge(
                            count: badgeCount,
                            backgroundColor: accentColor,
                            foregroundColor: onAccentColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'More',
                  maxLines: 3,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    height: 1.2,
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
  const _Badge({
    required this.count,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final int count;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: TextStyle(
            color: foregroundColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
