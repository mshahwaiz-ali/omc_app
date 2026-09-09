import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';
import '../interaction/app_feedback.dart';

class OmcIdentityHeader extends StatelessWidget {
  const OmcIdentityHeader({
    super.key,
    required this.displayName,
    required this.avatarUrl,
    required this.unreadNotifications,
    required this.onNotifications,
    this.onAvatar,
  });

  final String displayName;
  final String? avatarUrl;
  final int unreadNotifications;
  final VoidCallback onNotifications;
  final VoidCallback? onAvatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stack = constraints.maxWidth < 360 || textScale >= 1.5;

        final identity = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textCaption,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Semantics(
              header: true,
              child: Text(
                displayName,
                softWrap: true,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        );

        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NotificationButton(
              unreadNotifications: unreadNotifications,
              onTap: onNotifications,
            ),
            const SizedBox(width: AppSpacing.xs),
            _Avatar(avatarUrl: avatarUrl, name: displayName, onTap: onAvatar),
          ],
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              identity,
              const SizedBox(height: AppSpacing.sm),
              actions,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: identity),
            const SizedBox(width: AppSpacing.xs),
            actions,
          ],
        );
      },
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({
    required this.unreadNotifications,
    required this.onTap,
  });

  final int unreadNotifications;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = unreadNotifications > 0
        ? 'Notifications, $unreadNotifications unread'
        : 'Notifications';
    final theme = Theme.of(context);

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: theme.colorScheme.surface,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              AppFeedback.selection();
              onTap();
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: AppTouchTarget.minimum,
                  height: AppTouchTarget.minimum,
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 24,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (unreadNotifications > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxs,
                        vertical: 1,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.danger,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatarUrl, required this.name, this.onTap});

  final String? avatarUrl;
  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Container(
      color: theme.colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
    final avatar = Container(
      width: AppTouchTarget.minimum,
      height: AppTouchTarget.minimum,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipOval(
        child: avatarUrl == null || avatarUrl!.trim().isEmpty
            ? fallback
            : Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                // Remote account images can be rendered by the browser image
                // element when cross-origin image requests are restricted.
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
    if (onTap == null) return avatar;

    return Tooltip(
      message: 'Open profile',
      child: Semantics(
        button: true,
        label: 'Open profile for $name',
        excludeSemantics: true,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            AppFeedback.selection();
            onTap!();
          },
          child: avatar,
        ),
      ),
    );
  }

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    return parts.length == 1
        ? parts.first.substring(0, 1).toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
