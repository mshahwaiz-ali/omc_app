import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

class AppBackHeader extends StatelessWidget {
  const AppBackHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final canPop = GoRouter.of(context).canPop();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: canPop
                  ? () => context.pop()
                  : () => context.go('/home'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.35,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (actionIcon != null && onAction != null)
              IconButton(
                tooltip: actionTooltip,
                onPressed: onAction,
                icon: Icon(actionIcon),
              ),
          ],
        ),
      ),
    );
  }
}
