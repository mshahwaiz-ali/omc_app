import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';

class OmcPremium {
  const OmcPremium._();

  static const Color ink = AppTheme.textPrimary;
  static const Color muted = AppTheme.textSecondary;
  static const Color surface = AppTheme.card;
  static const Color canvas = AppTheme.background;
  static const Color border = AppTheme.border;

  static const Color services = Color(0xFFE83F5B);
  static const Color documents = Color(0xFF3B6DF6);
  static const Color payments = Color(0xFF11A97D);
  static const Color tax = Color(0xFF2563EB);
  static const Color track = Color(0xFF0F9D8E);
  static const Color leads = Color(0xFF7C3AED);
  static const Color tasks = Color(0xFFF97316);
  static const Color system = Color(0xFF475569);

  static const Color open = Color(0xFF2563EB);
  static const Color inProgress = Color(0xFF0EA5E9);
  static const Color review = Color(0xFF0F9D8E);
  static const Color action = Color(0xFFF97316);
  static const Color success = AppTheme.success;
  static const Color danger = Color(0xFFDC2626);

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: AppTheme.textPrimary.withValues(alpha: 0.07),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];

  static Color soft(Color color, [double alpha = 0.10]) {
    return color.withValues(alpha: alpha);
  }

  static Color moduleColor(String? value) {
    final key = (value ?? '').toLowerCase();
    if (key.contains('document') || key.contains('folder')) return documents;
    if (key.contains('payment') ||
        key.contains('receipt') ||
        key.contains('invoice')) {
      return payments;
    }
    if (key.contains('tax') ||
        key.contains('calculator') ||
        key.contains('ntn') ||
        key.contains('gst')) {
      return tax;
    }
    if (key.contains('track') ||
        key.contains('progress') ||
        key.contains('review')) {
      return track;
    }
    if (key.contains('lead')) return leads;
    if (key.contains('task') || key.contains('todo')) return tasks;
    if (key.contains('service') || key.contains('case')) return services;
    return system;
  }

  static Color statusColor(String? value) {
    final key = (value ?? '').toLowerCase();
    if (key.contains('reject') ||
        key.contains('block') ||
        key.contains('overdue') ||
        key.contains('cancel')) {
      return danger;
    }
    if (key.contains('action') ||
        key.contains('missing') ||
        key.contains('pending') ||
        key.contains('required')) {
      return action;
    }
    if (key.contains('review') ||
        key.contains('uploaded') ||
        key.contains('submitted')) {
      return review;
    }
    if (key.contains('complete') ||
        key.contains('approved') ||
        key.contains('paid') ||
        key.contains('verified')) {
      return success;
    }
    if (key.contains('progress')) return inProgress;
    if (key.contains('open') || key.contains('active')) return open;
    return system;
  }
}

class OmcSurface extends StatelessWidget {
  const OmcSurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.onTap,
    this.radius = AppRadius.large,
    this.borderColor,
    this.backgroundColor = OmcPremium.surface,
    this.shadow = true,
    this.semanticLabel,
    this.semanticHint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double radius;
  final Color? borderColor;
  final Color backgroundColor;
  final bool shadow;
  final String? semanticLabel;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final padded = Padding(padding: padding, child: child);

    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? OmcPremium.border),
        boxShadow: shadow ? OmcPremium.softShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: onTap == null
            ? padded
            : InkWell(onTap: onTap, borderRadius: borderRadius, child: padded),
      ),
    );

    if (onTap != null && semanticLabel != null) {
      content = Semantics(
        button: true,
        label: semanticLabel,
        hint: semanticHint,
        excludeSemantics: true,
        child: content,
      );
    }

    return content;
  }
}

class OmcIconBadge extends StatelessWidget {
  const OmcIconBadge({
    required this.icon,
    super.key,
    this.color = OmcPremium.services,
    this.size = 46,
    this.iconSize = 22,
    this.radius = AppRadius.medium,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: OmcPremium.soft(color),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: OmcPremium.soft(color, 0.12)),
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }
}

class OmcStatusBadge extends StatelessWidget {
  const OmcStatusBadge({required this.label, super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? OmcPremium.statusColor(label);
    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: OmcPremium.soft(tone),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: OmcPremium.soft(tone, 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: tone, size: 14),
              const SizedBox(width: 5),
            ] else ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OmcSectionHeader extends StatelessWidget {
  const OmcSectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.25,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: AppSpacing.xs),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}

class OmcMetricCard extends StatelessWidget {
  const OmcMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    super.key,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = [
      '$label: $value',
      if (subtitle != null && subtitle!.trim().isNotEmpty) subtitle!.trim(),
    ].join('. ');

    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: OmcSurface(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OmcIconBadge(
              icon: icon,
              color: color,
              size: 38,
              iconSize: 19,
              radius: 14,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.45,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class OmcLockedOverlay extends StatelessWidget {
  const OmcLockedOverlay({
    required this.child,
    required this.locked,
    super.key,
  });

  final Widget child;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final content = Opacity(
      opacity: locked ? 0.62 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (locked)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: OmcPremium.softShadow,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 11,
                  color: OmcPremium.muted,
                ),
              ),
            ),
        ],
      ),
    );

    if (!locked) return content;
    return Semantics(container: true, label: 'Locked', child: content);
  }
}
