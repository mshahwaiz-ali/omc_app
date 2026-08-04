import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../core/network/frappe_client.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/storage/preferences_service.dart';

final sessionEpochProvider = NotifierProvider<SessionEpochController, int>(
  SessionEpochController.new,
);

class SessionEpochController extends Notifier<int> {
  @override
  int build() => 0;

  void advance() => state++;
}

final sessionExpirySignalProvider =
    NotifierProvider<SessionExpirySignalController, int>(
      SessionExpirySignalController.new,
    );

class SessionExpirySignalController extends Notifier<int> {
  @override
  int build() => 0;

  void signal() => state++;
}

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final preferencesServiceProvider = FutureProvider<PreferencesService>((ref) {
  return PreferencesService.create();
});

final dioClientProvider = Provider<DioClient>((ref) {
  ref.watch(sessionEpochProvider);
  final secureStorageService = ref.watch(secureStorageServiceProvider);

  return DioClient(
    secureStorageService: secureStorageService,
    onUnauthorized: () =>
        ref.read(sessionExpirySignalProvider.notifier).signal(),
  );
});

final frappeClientProvider = Provider<FrappeClient>((ref) {
  final dioClient = ref.watch(dioClientProvider);

  return FrappeClient(dioClient);
});
