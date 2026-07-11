import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

class AppBackHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppBackHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
    this.fallbackRoute = '/home',
  });

  final String title;
  final String? subtitle;
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onAction;
  final String fallbackRoute;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 76 : 90);

  @override
  Widget build(BuildContext context) {
    final canPop = GoRouter.of(context).canPop();

    void goBack() {
      if (canPop) {
        context.pop();
      } else {
        context.go(fallbackRoute);
      }
    }

    return Material(
      color: const Color(0xFFF8FAFD),
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFD),
            border: Border(bottom: BorderSide(color: Color(0xFFE7EAF0))),
          ),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'Go back',
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: goBack,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E6ED)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A111827),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 19,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (actionIcon != null && onAction != null) ...[
                const SizedBox(width: 10),
                Tooltip(
                  message: actionTooltip ?? 'More action',
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: onAction,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E6ED)),
                        ),
                        child: Icon(
                          actionIcon,
                          size: 21,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
