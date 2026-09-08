import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'push_registration.dart';

@pragma('vm:entry-point')
Future<void> omcBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Android displays the notification payload. Never display it twice here.
}

class FirebasePushSource implements PushTokenSource {
  final _opens = StreamController<String>.broadcast();
  final _notifications = FlutterLocalNotificationsPlugin();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Map<String, dynamic>? _pending;
  String? _binding;
  bool ready = false;

  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(omcBackgroundMessage);
      await _notifications.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_omc')),
        onDidReceiveNotificationResponse: (response) {
          try { _open(Map<String, dynamic>.from(jsonDecode(response.payload ?? '{}') as Map)); } catch (_) { /* Reject malformed payload. */ }
        },
      );
      await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
        const AndroidNotificationChannel('omc_updates', 'OMC updates', importance: Importance.high));
      _subscriptions.add(FirebaseMessaging.onMessage.listen((message) async {
        final data = message.data;
        if (_binding == null || data['binding_id'] != _binding) return;
        final id = data['notification_id']?.toString() ?? '';
        if (id.isEmpty) return;
        await _notifications.show(id: id.codeUnits.fold<int>(0, (hash, value) => (hash * 31 + value) & 0x7fffffff),
          title: 'OMC House', body: 'You have an update. Open OMC to view it.',
          notificationDetails: AndroidDetails.value, payload: jsonEncode(data));
      }));
      _subscriptions.add(FirebaseMessaging.onMessageOpenedApp.listen((message) => _open(message.data)));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _pending = initial.data;
      final launch = await _notifications.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        try { _pending = Map<String, dynamic>.from(jsonDecode(launch!.notificationResponse!.payload!) as Map); } catch (_) { /* Ignore invalid launch. */ }
      }
      ready = true;
    } catch (_) { ready = false; }
  }

  void setBinding(String? binding) {
    _binding = binding;
    final pending = _pending;
    if (binding != null && pending != null) { _pending = null; _open(pending); }
  }

  void _open(Map<String, dynamic> data) {
    if (_binding == null) { _pending = data; return; }
    if (data['binding_id'] != _binding) return;
    final id = data['notification_id']?.toString() ?? '';
    if (id.isEmpty || id.length > 140) return;
    _opens.add('/notifications/${Uri.encodeComponent(id)}');
  }

  Future<void> enableNotifications() async {
    if (!ready) throw StateError('Push configuration is unavailable in this build.');
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool('omc_push_permission_requested') == true) {
      await const MethodChannel('omc/notifications').invokeMethod<void>('openSettings');
    } else {
      await preferences.setBool('omc_push_permission_requested', true);
      await FirebaseMessaging.instance.requestPermission();
    }
  }

  Future<void> resetDevice() async {
    _binding = null;
    _pending = null;
    if (!ready) return;
    await _notifications.cancelAll();
    await FirebaseMessaging.instance.deleteToken();
  }

  @override
  Future<String?> requestToken() async {
    if (!ready) return null;
    final permission = await FirebaseMessaging.instance.getNotificationSettings();
    if (permission.authorizationStatus != AuthorizationStatus.authorized) return null;
    return FirebaseMessaging.instance.getToken();
  }
  @override
  String get platform => 'android';
  @override
  Stream<String> get tokenRefreshes => ready ? FirebaseMessaging.instance.onTokenRefresh : const Stream.empty();
  @override
  Stream<String> get openedRoutes => _opens.stream;
}

class AndroidDetails {
  static const value = NotificationDetails(android: AndroidNotificationDetails(
    'omc_updates', 'OMC updates', importance: Importance.high, priority: Priority.high,
    icon: 'ic_stat_omc', visibility: NotificationVisibility.private));
}
