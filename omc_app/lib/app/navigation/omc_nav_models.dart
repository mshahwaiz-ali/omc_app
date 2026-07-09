import 'package:flutter/material.dart';

class OmcBottomNavItem {
  const OmcBottomNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.shellIndex,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int shellIndex;
}

class OmcSheetAction {
  const OmcSheetAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;
  final bool isDestructive;
}
