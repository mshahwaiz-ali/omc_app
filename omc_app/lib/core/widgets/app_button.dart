import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = true,
    this.semanticHint,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final enabled = !isLoading && onPressed != null;
    final button = FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppTouchTarget.prominentButtonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      child: AnimatedSwitcher(
        duration: AppMotion.quick,
        child: isLoading
            ? const SizedBox(
                key: ValueKey('loading'),
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : Row(
                key: const ValueKey('content'),
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Flexible(flex: 0, child: Icon(icon, size: 20)),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
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
