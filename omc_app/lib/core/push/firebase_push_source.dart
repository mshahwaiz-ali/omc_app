import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'push_token_source.dart';

@pragma('vm:entry-point')
Future<void> omcBackgroundMessage(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // An unconfigured installation must not crash a background isolate.
  }
  // Android displays the generic notification payload. Do not display it twice.
}

class FirebasePushSource implements BoundPushTokenSource {
  static const _native = MethodChannel('omc/notifications');
  static const _resetKey = 'omc_push_token_reset_pending_v1';
  final _opens = StreamController<PushOpenIntent>.broadcast();
  final _notifications = FlutterLocalNotificationsPlugin();
  final _subscriptions = <StreamSubscription<RemoteMessage>>[];
  Future<void>? _initializing;
  Future<void>? _resetting;
  PushOpenIntent? _pending;
  String? _binding;
  bool _ready = false;
  bool _localReady = false;
  bool _disposed = false;
  int _generation = 0;

  @override
  bool get ready => _ready && !_disposed;
  @override
  String? get bindingId => _binding;
  @override
  PushOpenIntent? get pendingOpen => _pending;

  @override
  Future<void> initialize() {
    if (ready || _disposed) return Future<void>.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (!_localReady) {
        await _notifications.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_omc'),
          ),
          onDidReceiveNotificationResponse: (response) =>
              _openLocal(response.payload),
        );
        await _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                'omc_updates',
                'OMC updates',
                description: 'Private OMC service and account updates',
                importance: Importance.high,
              ),
            );
        _localReady = true;
        final launch = await _notifications.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp == true) {
          _openLocal(launch?.notificationResponse?.payload);
        }
      }
      await Firebase.initializeApp();
      if (_disposed) return;
      FirebaseMessaging.onBackgroundMessage(omcBackgroundMessage);
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen((message) {
          unawaited(_showForeground(message));
        }),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          _open(message.data);
        }),
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _open(initial.data);
      _ready = true;
    } catch (_) {
      _ready = false;
      for (final subscription in _subscriptions) {
        await subscription.cancel();
      }
      _subscriptions.clear();
      // Never log raw tokens, key paths or provider credential exceptions.
    }
  }

  void _openLocal(String? payload) {
    try {
      final data = jsonDecode(payload ?? '{}');
      if (data is Map<String, dynamic>) _open(data);
    } catch (_) {
      // Reject malformed payloads.
    }
  }

  void _open(Map<String, dynamic> data) {
    final intent = PushOpenIntent.fromData(data);
    if (_disposed ||
        intent == null ||
        (_binding != null && _binding != intent.bindingId)) {
      return;
    }
    _pending = intent;
    _opens.add(intent);
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final intent = PushOpenIntent.fromData(message.data);
    if (_disposed || intent == null || _binding != intent.bindingId) return;
    final generation = _generation;
    final id = intent.notificationId.codeUnits.fold<int>(
      0,
      (hash, value) => (hash * 31 + value) & 0x7fffffff,
    );
    try {
      await _notifications.show(
        id: id,
        title: 'OMC House',
        body: 'You have an update. Open OMC to view it.',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'omc_updates',
            'OMC updates',
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.private,
            icon: 'ic_stat_omc',
            tag: intent.notificationId,
            onlyAlertOnce: true,
          ),
        ),
        payload: jsonEncode(intent.toData()),
      );
      if (_disposed ||
          generation != _generation ||
          _binding != intent.bindingId) {
        await _notifications.cancel(id: id, tag: intent.notificationId);
      }
    } catch (_) {
      // Plugin/network failures must not escape into the application zone.
    }
  }

  @override
  void setBinding(String? binding) {
    if (_binding != binding) _generation++;
    _binding = binding;
    final intent = _pending;
    if (binding != null && intent != null) {
      if (intent.bindingId == binding) {
        _opens.add(intent);
      } else {
        _pending = null;
      }
    }
  }

  @override
  void consumeOpen(PushOpenIntent intent) {
    if (_pending == intent) _pending = null;
  }

  @override
  void clearPending() => _pending = null;

  @override
  Future<PushPermission> permissionState() async {
    if (!ready) return PushPermission.unavailable;
    try {
      final value = await _native.invokeMethod<String>('permissionState');
      return PushPermission.values.firstWhere(
        (state) => state.name == value,
        orElse: () => PushPermission.unavailable,
      );
    } catch (_) {
      return PushPermission.unavailable;
    }
  }

  @override
  Future<void> enableNotifications() async {
    await initialize();
    if (!ready) throw StateError('Push is not configured in this build.');
    final permission = await permissionState();
    if (permission == PushPermission.notRequested) {
      await _native.invokeMethod<String>('requestPermission');
    } else if (permission != PushPermission.granted) {
      await _native.invokeMethod<void>('openSettings');
    }
  }

  @override
  Future<void> resetDevice() {
    setBinding(null);
    clearPending();
    return _resetting ??= _reset().whenComplete(() => _resetting = null);
  }

  Future<void> _reset() async {
    // Persist first: an offline logout must not reuse the old token on restart.
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_resetKey, true)) {
      throw StateError('Could not persist pending push cleanup.');
    }
    if (_localReady) {
      try {
        await _notifications.cancelAll();
      } catch (_) {}
    }
    if (Firebase.apps.isEmpty) return;
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
    await FirebaseMessaging.instance.deleteToken();
    await prefs.remove(_resetKey);
  }

  @override
  Future<String?> requestToken() async {
    final generation = _generation;
    await initialize();
    final resetting = _resetting;
    if (resetting != null) await resetting;
    if (!ready || generation != _generation) return null;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_resetKey) == true) {
      // Retry a previously failed deletion before obtaining a new token.
      final retry = _resetting ??= _reset().whenComplete(
        () => _resetting = null,
      );
      await retry;
    }
    if (await permissionState() != PushPermission.granted ||
        generation != _generation ||
        _disposed) {
      return null;
    }
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    final token = await FirebaseMessaging.instance.getToken();
    return !_disposed && generation == _generation ? token : null;
  }

  @override
  String get platform => 'android';
  @override
  Stream<String> get tokenRefreshes =>
      ready ? FirebaseMessaging.instance.onTokenRefresh : const Stream.empty();
  @override
  Stream<PushOpenIntent> get openedNotifications => _opens.stream;
  @override
  Stream<String> get openedRoutes => _opens.stream.map(
    (intent) => '/notifications/${Uri.encodeComponent(intent.notificationId)}',
  );

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _binding = null;
    _pending = null;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    unawaited(_opens.close());
  }
}
