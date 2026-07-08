import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/providers/core_providers.dart';
import '../../../app/theme.dart';
import '../../../core/network/frappe_client.dart';
import '../../app_config/data/mobile_app_config.dart';
import '../../app_config/data/mobile_app_config_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';

const String _supportUnreadCountMethod =
    'omc_app.api.support_chat.get_support_unread_count';
const String _activeSupportTicketMethod =
    'omc_app.api.support_chat.get_active_support_ticket';
const String _markSupportTicketReadMethod =
    'omc_app.api.support_chat.mark_support_ticket_read';

final supportBubbleUnreadCountProvider = FutureProvider<int>((ref) async {
  final client = ref.watch(frappeClientProvider);
  try {
    final response = await client.getMethod(_supportUnreadCountMethod);
    return _extractCount(response);
  } catch (_) {
    return 0;
  }
});

class SupportChatBubbleOverlay extends ConsumerStatefulWidget {
  const SupportChatBubbleOverlay({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<SupportChatBubbleOverlay> createState() =>
      _SupportChatBubbleOverlayState();
}

class _SupportChatBubbleOverlayState
    extends ConsumerState<SupportChatBubbleOverlay> {
  static const String _hiddenKey = 'support_chat_bubble_hidden';
  static const String _dxKey = 'support_chat_bubble_dx';
  static const String _dyKey = 'support_chat_bubble_dy';
  static const double _bubbleSize = 62;
  static const double _edgePadding = 14;
  static const double _bottomNavClearance = 112;

  bool _prefsLoaded = false;
  bool _hidden = false;
  bool _opening = false;
  Offset? _position;

  @override
  void initState() {
    super.initState();
    widget.router.routeInformationProvider.addListener(_handleRouteChanged);
    _loadPrefs();
  }

  @override
  void didUpdateWidget(covariant SupportChatBubbleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routeInformationProvider.removeListener(
        _handleRouteChanged,
      );
      widget.router.routeInformationProvider.addListener(_handleRouteChanged);
    }
  }

  @override
  void dispose() {
    widget.router.routeInformationProvider.removeListener(_handleRouteChanged);
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final dx = prefs.getDouble(_dxKey);
    final dy = prefs.getDouble(_dyKey);
    setState(() {
      _hidden = prefs.getBool(_hiddenKey) ?? false;
      _position = dx != null && dy != null ? Offset(dx, dy) : null;
      _prefsLoaded = true;
    });
  }

  void _handleRouteChanged() {
    if (mounted) setState(() {});
  }

  String get _currentPath {
    return widget.router.routeInformationProvider.value.uri.path;
  }

  bool _canRenderBubble(AuthStatus status, MobileFeatureConfig features) {
    if (!features.supportEnabled) return false;
    if (status == AuthStatus.checking || status == AuthStatus.unauthenticated) {
      return false;
    }

    final path = _currentPath;
    if (path == '/' || path == '/login' || path == '/signup') return false;
    if (path == '/under-review') return false;
    if (path.startsWith('/support-tickets/')) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final mobileConfig =
        ref.watch(mobileAppConfigProvider).value ?? MobileAppConfig.fallback;
    final canRender = _prefsLoaded &&
        _canRenderBubble(authState.status, mobileConfig.features);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (canRender && !_hidden) _buildBubbleLayer(context),
        if (canRender && _hidden && _currentPath == '/support')
          _buildRestorePill(context),
      ],
    );
  }

  Widget _buildBubbleLayer(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaPadding = MediaQuery.paddingOf(context);
        final maxX = _safeMax(_edgePadding, constraints.maxWidth - _bubbleSize - _edgePadding);
        final minY = mediaPadding.top + 12;
        final maxY = _safeMax(
          minY,
          constraints.maxHeight -
              _bubbleSize -
              _bottomNavClearance -
              mediaPadding.bottom,
        );
        final fallbackY = _clampDouble(
          constraints.maxHeight - _bottomNavClearance - _bubbleSize,
          minY,
          maxY,
        );
        final fallback = Offset(maxX, fallbackY);
        final position = _clampPosition(_position ?? fallback, maxX, minY, maxY);

        if (_position != position) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _position = position);
          });
        }

        return Positioned(
          left: position.dx,
          top: position.dy,
          child: _SupportBubbleButton(
            size: _bubbleSize,
            unreadCount: ref.watch(supportBubbleUnreadCountProvider).value ?? 0,
            isOpening: _opening,
            onTap: _openSupportDestination,
            onHide: _hideBubble,
            onDragUpdate: (delta) {
              setState(() {
                _position = _clampPosition(position + delta, maxX, minY, maxY);
              });
            },
            onDragEnd: () => _snapToEdge(maxX, minY, maxY),
          ),
        );
      },
    );
  }

  Widget _buildRestorePill(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      right: 18,
      bottom: bottomPadding + 104,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showBubbleAgain,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppTheme.primaryRed.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppTheme.primaryRed,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Show chat bubble',
                  style: TextStyle(
                    color: AppTheme.primaryRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Offset _clampPosition(Offset value, double maxX, double minY, double maxY) {
    return Offset(
      _clampDouble(value.dx, _edgePadding, maxX),
      _clampDouble(value.dy, minY, maxY),
    );
  }

  double _safeMax(double min, double value) {
    return value < min ? min : value;
  }

  double _clampDouble(double value, double min, double max) {
    return value.clamp(min, max).toDouble();
  }

  Future<void> _snapToEdge(double maxX, double minY, double maxY) async {
    final position = _position;
    if (position == null) return;

    final midpoint = maxX / 2;
    final snapped = _clampPosition(
      Offset(position.dx < midpoint ? _edgePadding : maxX, position.dy),
      maxX,
      minY,
      maxY,
    );
    setState(() => _position = snapped);
    await _savePosition(snapped);
  }

  Future<void> _savePosition(Offset position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_dxKey, position.dx);
    await prefs.setDouble(_dyKey, position.dy);
  }

  Future<void> _hideBubble() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hiddenKey, true);
    if (mounted) setState(() => _hidden = true);
  }

  Future<void> _showBubbleAgain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hiddenKey, false);
    if (mounted) setState(() => _hidden = false);
  }

  Future<void> _openSupportDestination() async {
    if (_opening) return;
    setState(() => _opening = true);

    try {
      final client = ref.read(frappeClientProvider);
      final ticketId = await _fetchActiveTicketId(client);
      if (!mounted) return;

      if (ticketId != null && ticketId.trim().isNotEmpty) {
        await _markTicketRead(client, ticketId);
        ref.invalidate(supportBubbleUnreadCountProvider);
        widget.router.push('/support-tickets/${Uri.encodeComponent(ticketId)}');
      } else {
        widget.router.push('/support');
      }
    } catch (_) {
      if (mounted) widget.router.push('/support');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }
}

class _SupportBubbleButton extends StatelessWidget {
  const _SupportBubbleButton({
    required this.size,
    required this.unreadCount,
    required this.isOpening,
    required this.onTap,
    required this.onHide,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final double size;
  final int unreadCount;
  final bool isOpening;
  final VoidCallback onTap;
  final VoidCallback onHide;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

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
              onPanUpdate: (details) => onDragUpdate(details.delta),
              onPanEnd: (_) => onDragEnd(),
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
                      color: AppTheme.primaryRed.withValues(alpha: 0.34),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Center(
                    child: isOpening
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.support_agent_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                  ),
                ),
              ),
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              top: 0,
              right: 0,
              child: _BubbleBadge(count: unreadCount),
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

class _BubbleBadge extends StatelessWidget {
  const _BubbleBadge({required this.count});

  final int count;

  String get _label => count > 99 ? '99+' : count.toString();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        _label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

Future<String?> _fetchActiveTicketId(FrappeClient client) async {
  final response = await client.getMethod(_activeSupportTicketMethod);
  final ticket = _extractTicketMap(response);
  if (ticket == null) return null;

  final id = ticket['id'] ?? ticket['name'] ?? ticket['ticket_id'];
  final text = id?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

Future<void> _markTicketRead(FrappeClient client, String ticketId) async {
  await client.postMethod(
    _markSupportTicketReadMethod,
    data: {'ticket_id': ticketId, 'name': ticketId},
  );
}

Map<String, dynamic>? _extractTicketMap(Map<String, dynamic>? data) {
  if (data == null) return null;
  final message = data['message'];
  final rawTicket = message is Map<String, dynamic>
      ? message['ticket'] ??
          message['support_ticket'] ??
          message['active_ticket'] ??
          message['data'] ??
          message['item'] ??
          message['record']
      : data['ticket'] ??
          data['support_ticket'] ??
          data['active_ticket'] ??
          data['data'] ??
          data['item'] ??
          data['record'];
  return rawTicket is Map<String, dynamic> ? rawTicket : null;
}

int _extractCount(Map<String, dynamic>? data) {
  if (data == null) return 0;
  final message = data['message'];
  final value = message is Map<String, dynamic>
      ? message['count'] ?? message['unread_count'] ?? message['total']
      : data['count'] ?? data['unread_count'] ?? data['total'] ?? message;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '') ?? 0;
}
