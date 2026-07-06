import 'package:flutter/material.dart';

class PremiumInfoChip extends StatelessWidget {
  const PremiumInfoChip({
    required this.label,
    this.icon,
    this.color,
    super.key,
  });

  final IconData? icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chipColor.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: chipColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: chipColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
