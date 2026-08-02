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

  Future<void> disable() => storage.saveDeviceLockEnabled(false);
}
