import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers/core_providers.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/application/auth_controller.dart';
import '../config/api_config.dart';
import 'push_token_source.dart';

export 'push_token_source.dart';

typedef PushMutation =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> data,
      CancelToken cancellation,
    );

final pushTokenSourceProvider = Provider<PushTokenSource>((ref) {
  return const UnavailablePushTokenSource();
});

final pushRegistrationProvider = Provider<PushRegistrationCoordinator>((ref) {
  final client = ref.watch(dioClientProvider);
  final coordinator = PushRegistrationCoordinator(
    source: ref.watch(pushTokenSourceProvider),
    installationId: _installationId,
    currentOwner: () {
      final auth = ref.read(authControllerProvider);
      return auth.status == AuthStatus.authenticated ? auth.userId : null;
    },
    mutate: (method, data, cancellation) async {
      try {
        // Same authenticated/intercepted client as the existing Frappe wrapper.
        final response = await client.instance.post<Map<String, dynamic>>(
          '${ApiConfig.apiMethodPath}/$method',
          data: data,
          cancelToken: cancellation,
        );
        final body = response.data ?? <String, dynamic>{};
        final message = body['message'];
        return message is Map<String, dynamic> ? message : body;
      } on DioException catch (error) {
        throw client.parseError(error);
      }
    },
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

Future<String> _installationId() async {
  final prefs = await SharedPreferences.getInstance();
  const key = 'omc_push_installation_v1';
  final existing = prefs.getString(key);
  if (PushOpenIntent.validBinding(existing)) return existing!;
  final random = Random.secure();
  final value = List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  if (!await prefs.setString(key, value)) {
    throw StateError('Could not persist installation identity.');
  }
  return value;
}

class PushDeviceStatus {
  const PushDeviceStatus({
    this.configured = false,
    this.permission = PushPermission.unavailable,
    this.registered = false,
    this.retryNeeded = false,
  });
  final bool configured;
  final PushPermission permission;
  final bool registered;
  final bool retryNeeded;
}

class PushRegistrationCoordinator {
  PushRegistrationCoordinator({
    required this.source,
    required this.mutate,
    required this.installationId,
    required this.currentOwner,
    this.requestDeadline = const Duration(seconds: 5),
  });
  final PushTokenSource source;
  final PushMutation mutate;
  final Future<String> Function() installationId;
  final String? Function() currentOwner;
  final Duration requestDeadline;
  final status = ValueNotifier<PushDeviceStatus>(const PushDeviceStatus());
  StreamSubscription<String>? _refresh;
  CancelToken? _request;
  Future<void> _serial = Future<void>.value();
  Future<void>? _cleanup;
  String? _owner;
  String? _token;
  String? _binding;
  String? _unregisterBinding;
  int _generation = 0;
  bool _disposed = false;

  BoundPushTokenSource? get boundSource =>
      source is BoundPushTokenSource ? source as BoundPushTokenSource : null;
  String? get bindingId => _binding;
  String? get owner => _owner;

  bool _current(String owner, int generation) =>
      !_disposed &&
      owner == _owner &&
      generation == _generation &&
      currentOwner() == owner;

  Future<void> syncForAuth(AuthState auth, {bool refresh = false}) async {
    if (_disposed) return;
    final owner = auth.status == AuthStatus.authenticated ? auth.userId : null;
    if (owner == null || owner.isEmpty) {
      // Preserve a cold-start intent during initial auth checking.
      if (_owner != null) await prepareForSignOut(unregister: false);
      return;
    }
    var expectedGeneration = _generation;
    if (_owner != null && _owner != owner) {
      final reset = prepareForSignOut(unregister: false);
      expectedGeneration = _generation;
      await reset;
    }
    final cleanup = _cleanup;
    if (cleanup != null) await cleanup;
    if (_disposed ||
        _generation != expectedGeneration ||
        currentOwner() != owner) {
      return;
    }
    if (_owner == owner && _token != null && _binding != null && !refresh) {
      return;
    }
    if (_owner != owner) {
      _owner = owner;
      _generation++;
    }
    final generation = _generation;
    await _enqueue(() async {
      if (!_current(owner, generation)) return;
      try {
        final token = await source.requestToken().timeout(
          const Duration(seconds: 12),
        );
        if (!_current(owner, generation)) return;
        _refresh ??= source.tokenRefreshes.listen(
          (token) =>
              unawaited(_enqueue(() => _register(token, owner, generation))),
          onError: (Object _) {
            if (_current(owner, generation)) _publish(retryNeeded: true);
          },
        );
        if (token == null || token.trim().isEmpty) {
          _binding = null;
          boundSource?.setBinding(null);
          final permission = await boundSource?.permissionState();
          if (_current(owner, generation)) _publish(permission: permission);
          return;
        }
        await _register(token, owner, generation);
      } catch (_) {
        if (_current(owner, generation)) _publish(retryNeeded: true);
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() work) {
    _serial = _serial
        .then((_) async {
          if (!_disposed) await work();
        })
        .catchError((Object _) {
          // Every async callback is observed. Failure never tears down auth.
        });
    return _serial;
  }

  Future<Map<String, dynamic>> _post(
    String method,
    Map<String, dynamic> data,
    CancelToken cancellation,
  ) async {
    return mutate(method, data, cancellation).timeout(
      requestDeadline,
      onTimeout: () {
        cancellation.cancel('Push request deadline');
        throw TimeoutException('Push request timed out.');
      },
    );
  }

  Future<void> _register(String token, String owner, int generation) async {
    if (!_current(owner, generation) || token.trim().isEmpty) return;
    CancelToken? cancellation;
    try {
      final permission = await boundSource?.permissionState();
      if (!_current(owner, generation)) return;
      if (permission != null && permission != PushPermission.granted) {
        _binding = null;
        boundSource?.setBinding(null);
        _publish(permission: permission);
        return;
      }
      final device = await installationId();
      if (!_current(owner, generation)) return;
      cancellation = CancelToken();
      _request = cancellation;
      final result = await _post(ApiConfig.registerPushTokenMethod, {
        'token': token.trim(),
        'platform': source.platform,
        'device_id': device,
      }, cancellation);
      if (!_current(owner, generation)) return;
      final binding = result['binding_id'];
      if (result['registered'] != true ||
          !PushOpenIntent.validBinding(binding)) {
        throw StateError('Server did not confirm the push binding.');
      }
      _token = token.trim();
      _binding = binding as String;
      _unregisterBinding = _binding;
      boundSource?.setBinding(_binding);
      _publish(permission: permission, registered: true);
    } catch (_) {
      if (_current(owner, generation)) {
        _binding = null;
        boundSource?.setBinding(null);
        _publish(retryNeeded: true);
      }
    } finally {
      if (identical(_request, cancellation)) _request = null;
    }
  }

  /// Invoke before removing canonical credentials. Local authority drops
  /// synchronously; best-effort remote cleanup and provider deletion are bounded.
  Future<void> prepareForSignOut({bool unregister = true}) {
    if (_cleanup != null) return _cleanup!;
    final token = _token;
    final binding = _unregisterBinding;
    _generation++;
    _owner = null;
    _token = null;
    _binding = null;
    _unregisterBinding = null;
    _request?.cancel('Session changed');
    _request = null;
    final refresh = _refresh;
    _refresh = null;
    if (refresh != null) unawaited(refresh.cancel());
    boundSource?.setBinding(null);
    boundSource?.clearPending();
    _publish();
    final cancellation = CancelToken();
    final remote = unregister && token != null
        ? _post(ApiConfig.unregisterPushTokenMethod, {
            'token': token,
            'binding_id': ?binding,
          }, cancellation).then<void>((_) {}).catchError((Object _) {})
        : Future<void>.value();
    final reset = (boundSource?.resetDevice() ?? Future<void>.value())
        .timeout(requestDeadline)
        .catchError((Object _) {});
    _cleanup = Future.wait<void>([remote, reset])
        .then<void>((_) {})
        .whenComplete(() {
          cancellation.cancel('Sign-out cleanup complete');
          _cleanup = null;
        });
    return _cleanup!;
  }

  void _publish({
    PushPermission? permission,
    bool registered = false,
    bool retryNeeded = false,
  }) {
    if (_disposed) return;
    status.value = PushDeviceStatus(
      configured: boundSource?.ready == true,
      permission: permission ?? status.value.permission,
      registered: registered,
      retryNeeded: retryNeeded,
    );
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _request?.cancel('Coordinator disposed');
    unawaited(_refresh?.cancel());
    status.dispose();
  }
}

// openedRoutes is compatibility-only. PushRuntimeHost consumes typed opaque IDs.
