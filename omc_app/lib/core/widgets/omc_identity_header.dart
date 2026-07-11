import 'package:flutter/material.dart';

import '../../app/theme.dart';

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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _NotificationButton(
          unreadNotifications: unreadNotifications,
          onTap: onNotifications,
        ),
        const SizedBox(width: 10),
        _Avatar(avatarUrl: avatarUrl, name: displayName, onTap: onAvatar),
      ],
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
  const _NotificationButton({required this.unreadNotifications, required this.onTap});

  final int unreadNotifications;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                Icons.notifications_none_rounded,
                size: 22,
                color: AppTheme.textPrimary,
              ),
            ),
            if (unreadNotifications > 0)
              Positioned(
                right: 4,
                top: 5,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
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
    final fallback = Container(
      color: _avatarColor.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(fontWeight: FontWeight.w900, color: _avatarColor),
      ),
    );
    final avatar = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: ClipOval(
        child: avatarUrl == null || avatarUrl!.trim().isEmpty
            ? fallback
            : Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
    if (onTap == null) return avatar;
    return InkWell(customBorder: const CircleBorder(), onTap: onTap, child: avatar);
  }

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    return parts.length == 1
        ? parts.first.substring(0, 1).toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Color get _avatarColor {
    const colors = [
      Color(0xFFE11D48),
      Color(0xFF5B7CFA),
      Color(0xFF17B890),
      Color(0xFF14B8A6),
      Color(0xFF8B5CF6),
      Color(0xFFF59E0B),
    ];
    final source = name.trim().isEmpty ? 'OMC' : name.trim();
    return colors[source.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % colors.length];
  }
}
