import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/core_providers.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../config/api_config.dart';
import '../network/frappe_client.dart';

/// Provider-neutral contract. A Firebase implementation is installed only when
/// valid platform configuration files and project credentials are supplied.
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

final pushTokenSourceProvider = Provider<PushTokenSource>((ref) {
  return const UnavailablePushTokenSource();
});

final pushRegistrationProvider = Provider<PushRegistrationCoordinator>((ref) {
  final coordinator = PushRegistrationCoordinator(
    client: ref.watch(frappeClientProvider),
    source: ref.watch(pushTokenSourceProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

class PushRegistrationCoordinator {
  PushRegistrationCoordinator({required this.client, required this.source});
  final FrappeClient client;
  final PushTokenSource source;
  StreamSubscription<String>? _refreshSubscription;
  String? _registeredToken;

  Future<void> syncForAuth(AuthState state) async {
    final authenticated = state.status == AuthStatus.authenticated;
    if (!authenticated) {
      final oldToken = _registeredToken;
      _registeredToken = null;
      if (oldToken != null) {
        await client.postMethod(
          ApiConfig.unregisterPushTokenMethod,
          data: {'token': oldToken},
        );
      }
      await _refreshSubscription?.cancel();
      _refreshSubscription = null;
      return;
    }
    final token = await source.requestToken();
    if (token == null || token.trim().isEmpty) return;
    await _register(token);
    _refreshSubscription ??= source.tokenRefreshes.listen(_register);
  }

  Future<void> _register(String token) async {
    if (token.trim().isEmpty) return;
    await client.postMethod(
      ApiConfig.registerPushTokenMethod,
      data: {'token': token.trim(), 'platform': source.platform},
    );
    _registeredToken = token.trim();
  }

  void dispose() {
    _refreshSubscription?.cancel();
  }
}

final pushAuthBindingProvider = Provider<void>((ref) {
  final coordinator = ref.watch(pushRegistrationProvider);
  ref.listen<AuthState>(authControllerProvider, (_, next) {
    unawaited(coordinator.syncForAuth(next));
  }, fireImmediately: true);
});
