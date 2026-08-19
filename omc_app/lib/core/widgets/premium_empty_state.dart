import 'package:flutter/material.dart';

import 'app_state.dart';

/// Compatibility wrapper retained for screens using the older premium state
/// name. Rendering delegates to the shared empty-state contract.
class PremiumEmptyState extends StatelessWidget {
  const PremiumEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: icon,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
