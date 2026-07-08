import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme.dart';

class SupportChatBubbleOverlay extends StatefulWidget {
  const SupportChatBubbleOverlay({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  @override
  State<SupportChatBubbleOverlay> createState() => _SupportChatBubbleOverlayState();
}

class _SupportChatBubbleOverlayState extends State<SupportChatBubbleOverlay> {
  static const String _hiddenKey = 'support_chat_bubble_hidden';
  static const double _size = 58;

  bool _prefsLoaded = false;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hidden = prefs.getBool(_hiddenKey) ?? false;
      _prefsLoaded = true;
    });
  }

  bool get _canShowBubble {
    final path = widget.router.routeInformationProvider.value.uri.path;
    if (!_prefsLoaded || _hidden) return false;
    if (path == '/' || path == '/login' || path == '/signup') return false;
    if (path == '/under-review') return false;
    if (path == '/support' || path.startsWith('/support-tickets/')) return false;
    return true;
  }

  Future<void> _hideBubble() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hiddenKey, true);
    if (mounted) setState(() => _hidden = true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_canShowBubble)
          Positioned(
            right: 18,
            bottom: bottomPadding + 104,
            child: _SupportBubbleButton(
              size: _size,
              onTap: () => widget.router.push('/support'),
              onHide: _hideBubble,
            ),
          ),
      ],
    );
  }
}

class _SupportBubbleButton extends StatelessWidget {
  const _SupportBubbleButton({
    required this.size,
    required this.onTap,
    required this.onHide,
  });

  final double size;
  final VoidCallback onTap;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 12,
      height: size + 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 6,
            top: 6,
            child: GestureDetector(
              onTap: onTap,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryRed, Color(0xFFB2162D)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryRed.withValues(alpha: 0.30),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -2,
            left: -2,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onHide,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.textSecondary,
                    size: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
