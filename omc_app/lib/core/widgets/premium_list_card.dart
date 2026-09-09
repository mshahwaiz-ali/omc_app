import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

class PremiumListCard extends StatelessWidget {
  const PremiumListCard({
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(AppRadius.card);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: borderRadius,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final stackLayout =
                    constraints.maxWidth < 360 || textScale >= 1.5;

                final iconBadge = ExcludeSemantics(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Icon(
                      icon,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                );

                final textBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      softWrap: true,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        softWrap: true,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                );

                final heading = stackLayout
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          iconBadge,
                          const SizedBox(height: AppSpacing.xs),
                          textBlock,
                          if (trailing != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            trailing!,
                          ],
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          iconBadge,
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: textBlock),
                          if (trailing != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            trailing!,
                          ],
                        ],
                      );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    if (children.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: children,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
