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

  // Module colors remain recognition decoration only. They must not be used as
  // workflow authority or as a substitute for semantic status treatment.
  static const Color services = Color(0xFFE83F5B);
  static const Color documents = Color(0xFF3B6DF6);
  static const Color payments = Color(0xFF11A97D);
  static const Color tax = Color(0xFF2563EB);
  static const Color track = Color(0xFF0F9D8E);
  static const Color leads = Color(0xFF7C3AED);
  static const Color tasks = Color(0xFFF97316);
  static const Color system = AppTheme.processing;

  static const Color open = AppTheme.info;
  static const Color inProgress = AppTheme.info;
  static const Color review = AppTheme.processing;
  static const Color action = AppTheme.warning;
  static const Color success = AppTheme.success;
  static const Color danger = AppTheme.danger;

  /// Reserved for modal/sticky separation. Ordinary cards default to no shadow.
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: AppTheme.textPrimary.withValues(alpha: 0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
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
        key.contains('overdue')) {
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
        key.contains('submitted') ||
        key.contains('processing')) {
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

  static Color statusBackground(String? value) {
    final tone = statusColor(value);
    if (tone == danger) return AppTheme.dangerSoft;
    if (tone == action) return AppTheme.warningSoft;
    if (tone == review || tone == system) return AppTheme.processingSoft;
    if (tone == success) return AppTheme.successSoft;
    if (tone == open || tone == inProgress) return AppTheme.infoSoft;
    return AppTheme.processingSoft;
  }

  static IconData statusIcon(String? value) {
    final tone = statusColor(value);
    if (tone == danger) return Icons.error_outline_rounded;
    if (tone == action) return Icons.priority_high_rounded;
    if (tone == review) return Icons.schedule_rounded;
    if (tone == success) return Icons.check_circle_outline_rounded;
    if (tone == open || tone == inProgress) return Icons.info_outline_rounded;
    return Icons.circle_outlined;
  }
}

class OmcPageListView extends StatelessWidget {
  const OmcPageListView({
    required this.children,
    super.key,
    this.topPadding = AppSpacing.lg,
    this.bottomPadding = AppSpacing.xl,
    this.controller,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.physics = const AlwaysScrollableScrollPhysics(
      parent: BouncingScrollPhysics(),
    ),
    this.maxWidth = AppLayout.generalMaxWidth,
  });

  final List<Widget> children;
  final double topPadding;
  final double bottomPadding;
  final ScrollController? controller;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final ScrollPhysics physics;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = AppLayout.pageInsetFor(constraints.maxWidth);
        final horizontal = constraints.maxWidth > maxWidth + inset * 2
            ? (constraints.maxWidth - maxWidth) / 2
            : inset;
        return ListView(
          controller: controller,
          keyboardDismissBehavior: keyboardDismissBehavior,
          physics: physics,
          padding: EdgeInsets.fromLTRB(
            horizontal,
            topPadding,
            horizontal,
            bottomPadding,
          ),
          children: children,
        );
      },
    );
  }
}

class OmcPagePadding extends StatelessWidget {
  const OmcPagePadding({
    required this.child,
    super.key,
    this.topPadding = AppSpacing.lg,
    this.bottomPadding = AppSpacing.xl,
    this.maxWidth = AppLayout.generalMaxWidth,
  });

  final Widget child;
  final double topPadding;
  final double bottomPadding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = AppLayout.pageInsetFor(constraints.maxWidth);
        final horizontal = constraints.maxWidth > maxWidth + inset * 2
            ? (constraints.maxWidth - maxWidth) / 2
            : inset;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            topPadding,
            horizontal,
            bottomPadding,
          ),
          child: child,
        );
      },
    );
  }
}

class OmcSurface extends StatelessWidget {
  const OmcSurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.onTap,
    this.radius = AppRadius.card,
    this.borderColor,
    this.backgroundColor = OmcPremium.surface,
    this.shadow = false,
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
        container: true,
        button: true,
        label: semanticLabel,
        hint: semanticHint,
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
    this.size = 40,
    this.iconSize = 20,
    this.radius = AppRadius.control,
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
          color: OmcPremium.soft(color, 0.08),
          borderRadius: BorderRadius.circular(radius),
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
    final theme = Theme.of(context);
    final tone = color ?? OmcPremium.statusColor(label);
    final background = color == null
        ? OmcPremium.statusBackground(label)
        : OmcPremium.soft(tone, 0.08);
    final statusIcon = icon ?? OmcPremium.statusIcon(label);

    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: tone.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: tone, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  softWrap: true,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w500,
                    height: 1.30,
                  ),
                ),
              ),
            ],
          ),
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
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            softWrap: true,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            softWrap: true,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final hasAction = actionLabel != null;
        final stackAction =
            hasAction && (constraints.maxWidth < 320 || scale >= 1.5);

        if (stackAction) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text,
              const SizedBox(height: AppSpacing.xs),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: text),
            if (hasAction) ...[
              const SizedBox(width: AppSpacing.xs),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        );
      },
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
    final theme = Theme.of(context);
    final semanticLabel = [
      '$label: $value',
      if (subtitle != null && subtitle!.trim().isNotEmpty) subtitle!.trim(),
    ].join('. ');

    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: OmcSurface(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OmcIconBadge(icon: icon, color: color),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              softWrap: true,
              style: theme.textTheme.amountSecondary.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              softWrap: true,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle!,
                softWrap: true,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textCaption,
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
                  size: 12,
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
