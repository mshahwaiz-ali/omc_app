import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../interaction/app_feedback.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = true,
    this.semanticHint,
    this.hapticFeedback = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final String? semanticHint;
  final bool hapticFeedback;

  @override
  Widget build(BuildContext context) {
    final enabled = !isLoading && onPressed != null;
    final effectiveOnPressed = !enabled
        ? null
        : () {
            if (hapticFeedback) AppFeedback.action();
            onPressed!();
          };

    final foreground = Theme.of(context).colorScheme.onPrimary;
    final button = FilledButton(
      onPressed: effectiveOnPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppTouchTarget.primaryButtonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    label,
                    softWrap: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            Positioned(
              right: 0,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              ),
            ),
        ],
      ),
    );

    final accessibleButton = Semantics(
      button: true,
      enabled: enabled,
      label: isLoading ? '$label, loading' : label,
      hint: semanticHint,
      liveRegion: isLoading,
      excludeSemantics: true,
      child: button,
    );

    if (!isExpanded) return accessibleButton;

    return SizedBox(width: double.infinity, child: accessibleButton);
  }
}
