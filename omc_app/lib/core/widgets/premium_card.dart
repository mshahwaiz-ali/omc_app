import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.onTap,
    this.semanticLabel,
    this.semanticHint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(AppRadius.card);
    final content = Padding(padding: padding, child: child);

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: borderRadius,
        child: onTap == null
            ? content
            : InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
      ),
    );

    if (onTap != null && semanticLabel != null) {
      card = Semantics(
        button: true,
        label: semanticLabel,
        hint: semanticHint,
        excludeSemantics: true,
        child: card,
      );
    }

    return card;
  }
}
