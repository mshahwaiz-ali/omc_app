import 'package:flutter/material.dart';

import 'app_state.dart';

/// Compatibility wrapper for older screens that still import `EmptyState`.
///
/// New screens should prefer [AppEmptyState] directly so empty-state behavior,
/// accessibility and interaction styling stay centralized.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: title,
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
