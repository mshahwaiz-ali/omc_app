import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

class PremiumListHeader extends StatelessWidget {
  const PremiumListHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.metaLabel,
    this.accentColor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? metaLabel;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;
    final cleanMeta = metaLabel?.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stackMeta =
            cleanMeta != null &&
            cleanMeta.isNotEmpty &&
            (constraints.maxWidth < 420 || textScale > 1.25);

        final heading = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!stackMeta && cleanMeta != null && cleanMeta.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.xs),
              _MetaBadge(label: cleanMeta, accent: accent),
            ],
          ],
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              if (stackMeta && cleanMeta != null && cleanMeta.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.only(left: 57),
                  child: _MetaBadge(label: cleanMeta, accent: accent),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.075),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: accent.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
