/// Provider-neutral interfaces keep non-Android builds and tests independent.
abstract interface class PushTokenSource {
  Future<String?> requestToken();
  Stream<String> get tokenRefreshes;
  Stream<String> get openedRoutes;
  String get platform;
}

class UnavailablePushTokenSource implements PushTokenSource {
  const UnavailablePushTokenSource();
  @override
  Future<String?> requestToken() async => null;
  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
  @override
  Stream<String> get openedRoutes => const Stream.empty();
  @override
  String get platform => 'unknown';
}

enum PushPermission {
  notRequested,
  granted,
  denied,
  previouslyDenied,
  settingsRequired,
  unavailable,
}

class PushOpenIntent {
  const PushOpenIntent(this.notificationId, this.bindingId);
  final String notificationId;
  final String bindingId;

  static bool validBinding(Object? value) =>
      value is String && RegExp(r'^[a-f0-9]{32}$').hasMatch(value);

  static PushOpenIntent? fromData(Map<String, dynamic> data) {
    final id = data['notification_id'];
    final binding = data['binding_id'];
    if (id is! String ||
        id.isEmpty ||
        id.length > 140 ||
        id.trim() != id ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(id) ||
        !validBinding(binding)) {
      return null;
    }
    return PushOpenIntent(id, binding as String);
  }

  Map<String, String> toData() => {
    'notification_id': notificationId,
    'binding_id': bindingId,
  };

  @override
  bool operator ==(Object other) =>
      other is PushOpenIntent &&
      other.notificationId == notificationId &&
      other.bindingId == bindingId;
  @override
  int get hashCode => Object.hash(notificationId, bindingId);
}

abstract interface class BoundPushTokenSource implements PushTokenSource {
  bool get ready;
  String? get bindingId;
  PushOpenIntent? get pendingOpen;
  Stream<PushOpenIntent> get openedNotifications;
  Future<void> initialize();
  Future<PushPermission> permissionState();
  Future<void> enableNotifications();
  void setBinding(String? binding);
  void consumeOpen(PushOpenIntent intent);
  void clearPending();
  Future<void> resetDevice();
  void dispose();
}
