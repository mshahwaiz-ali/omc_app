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

final biometricLoginAccountsProvider =
    FutureProvider<List<BiometricLoginAccount>>((ref) {
      return ref.watch(deviceLockServiceProvider).accounts();
    });

final biometricLoginEnabledForProvider = FutureProvider.family<bool, String>((
  ref,
  identity,
) {
  return ref
      .watch(deviceLockServiceProvider)
      .isBiometricLoginEnabledFor(identity);
});

class BiometricLoginAccount {
  const BiometricLoginAccount({
    required this.identifier,
    required this.password,
  });

  final String identifier;
  final String password;
}

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

  Future<bool> hasEnrolledBiometrics() async {
    try {
      final biometrics = await authentication.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String> biometricActionLabel() async {
    try {
      final biometrics = await authentication.getAvailableBiometrics();

      if (biometrics.contains(BiometricType.face)) {
        return 'Unlock with face';
      }

      if (biometrics.contains(BiometricType.fingerprint) ||
          biometrics.contains(BiometricType.strong) ||
          biometrics.contains(BiometricType.weak)) {
        return 'Unlock with fingerprint';
      }
    } catch (_) {
      // Use generic wording when capability detection is unavailable.
    }

    return 'Unlock with biometrics';
  }

  Future<bool> isEnabled() => storage.readDeviceLockEnabled();

  Future<bool> authenticate() async {
    if (!await isSupported() || !await hasEnrolledBiometrics()) return false;

    try {
      return await authentication.authenticate(
        localizedReason: 'Sign in to OMC House',
        options: const AuthenticationOptions(
          biometricOnly: true,
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
    final cleanIdentifier = identifier.trim();
    final existing = await accounts();

    final updated = <BiometricLoginAccount>[
      for (final account in existing)
        if (account.identifier.toLowerCase() != cleanIdentifier.toLowerCase())
          account,
      BiometricLoginAccount(identifier: cleanIdentifier, password: password),
    ];

    await storage.saveBiometricLoginAccounts(
      updated
          .map(
            (account) => {
              'identifier': account.identifier,
              'password': account.password,
            },
          )
          .toList(growable: false),
    );
  }

  Future<List<BiometricLoginAccount>> accounts() async {
    final stored = await storage.readBiometricLoginAccounts();

    return stored
        .map(
          (item) => BiometricLoginAccount(
            identifier: item['identifier'] ?? '',
            password: item['password'] ?? '',
          ),
        )
        .where(
          (item) =>
              item.identifier.trim().isNotEmpty && item.password.isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<bool> isBiometricLoginAvailable() async {
    if (!await isSupported() || !await hasEnrolledBiometrics()) return false;
    return (await accounts()).isNotEmpty;
  }

  Future<bool> isBiometricLoginEnabledFor(String identity) async {
    final cleanIdentity = identity.trim().toLowerCase();
    if (cleanIdentity.isEmpty) return false;

    final enrolled = await accounts();
    return enrolled.any(
      (account) => account.identifier.trim().toLowerCase() == cleanIdentity,
    );
  }

  Future<({String identifier, String password})?>
  authenticateAndReadBiometricLoginFor(String identity) async {
    final cleanIdentity = identity.trim().toLowerCase();
    if (cleanIdentity.isEmpty) return null;

    final enrolled = await accounts();
    BiometricLoginAccount? selected;

    for (final account in enrolled) {
      if (account.identifier.trim().toLowerCase() == cleanIdentity) {
        selected = account;
        break;
      }
    }

    if (selected == null) return null;
    if (!await authenticate()) return null;

    return (
      identifier: selected.identifier.trim(),
      password: selected.password,
    );
  }

  Future<void> removeBiometricLoginFor(String identity) async {
    final cleanIdentity = identity.trim().toLowerCase();
    final remaining = (await accounts())
        .where(
          (account) => account.identifier.trim().toLowerCase() != cleanIdentity,
        )
        .toList(growable: false);

    await storage.saveBiometricLoginAccounts(
      remaining
          .map(
            (account) => {
              'identifier': account.identifier,
              'password': account.password,
            },
          )
          .toList(growable: false),
    );
  }

  Future<void> clearBiometricLogin() => storage.clearBiometricLogin();

  Future<void> preserveBiometricLoginOnlyFor(String identity) async {
    // Multiple OMC accounts may be registered on the same device.
  }

  Future<void> disable() async {
    await storage.saveDeviceLockEnabled(false);
    await clearBiometricLogin();
  }
}
