import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/storage/secure_storage_service.dart';

final localAuthenticationProvider = Provider<LocalAuthentication>((ref) {
  return LocalAuthentication();
});

final deviceLockServiceProvider = Provider<DeviceLockService>((ref) {
  return DeviceLockService(
    authentication: ref.watch(localAuthenticationProvider),
    storage: ref.watch(secureStorageServiceProvider),
  );
});

final deviceLockEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(deviceLockServiceProvider).isEnabled();
});

final biometricLoginAvailableProvider = FutureProvider<bool>((ref) {
  return ref.watch(deviceLockServiceProvider).isBiometricLoginAvailable();
});

class DeviceLockSessionController extends Notifier<bool> {
  @override
  bool build() => false;

  void markUnlocked() => state = true;

  void markLocked() => state = false;

  void setUnlocked(bool unlocked) => state = unlocked;
}

final deviceLockSessionUnlockedProvider =
    NotifierProvider<DeviceLockSessionController, bool>(
      DeviceLockSessionController.new,
    );

class DeviceLockService {
  const DeviceLockService({
    required this.authentication,
    required this.storage,
  });

  final LocalAuthentication authentication;
  final SecureStorageService storage;

  Future<bool> isSupported() async {
    try {
      return await authentication.isDeviceSupported() ||
          await authentication.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() => storage.readDeviceLockEnabled();

  Future<bool> authenticate() async {
    if (!await isSupported()) return false;
    try {
      return await authentication.authenticate(
        localizedReason: 'Unlock your OMC House app',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> enable() async {
    if (!await authenticate()) return false;
    await storage.saveDeviceLockEnabled(true);
    return true;
  }

  Future<void> enrollBiometricLogin({
    required String identifier,
    required String password,
  }) async {
    await storage.saveBiometricLoginCredentials(
      identifier: identifier.trim(),
      password: password,
    );
  }

  Future<bool> isBiometricLoginAvailable() async {
    if (!await isSupported()) return false;
    if (!await storage.readBiometricLoginEnabled()) return false;

    final identifier = await storage.readBiometricLoginIdentifier();
    final password = await storage.readBiometricLoginPassword();
    return identifier != null &&
        identifier.trim().isNotEmpty &&
        password != null &&
        password.isNotEmpty;
  }

  Future<({String identifier, String password})?>
  authenticateAndReadBiometricLogin() async {
    if (!await isBiometricLoginAvailable()) return null;
    if (!await authenticate()) return null;

    final identifier = await storage.readBiometricLoginIdentifier();
    final password = await storage.readBiometricLoginPassword();
    if (identifier == null ||
        identifier.trim().isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }

    return (identifier: identifier.trim(), password: password);
  }

  Future<void> clearBiometricLogin() => storage.clearBiometricLogin();

  Future<void> preserveBiometricLoginOnlyFor(String identity) async {
    final enrolled = await storage.readBiometricLoginIdentifier();
    if (enrolled != null &&
        enrolled.trim().isNotEmpty &&
        enrolled.trim().toLowerCase() != identity.trim().toLowerCase()) {
      await clearBiometricLogin();
    }
  }

  Future<void> disable() async {
    await storage.saveDeviceLockEnabled(false);
    await clearBiometricLogin();
  }
}
