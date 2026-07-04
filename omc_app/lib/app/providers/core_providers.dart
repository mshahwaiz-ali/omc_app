import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../core/network/frappe_client.dart';
import '../../core/storage/secure_storage_service.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final dioClientProvider = Provider<DioClient>((ref) {
  final secureStorageService = ref.watch(secureStorageServiceProvider);

  return DioClient(
    secureStorageService: secureStorageService,
  );
});

final frappeClientProvider = Provider<FrappeClient>((ref) {
  final dioClient = ref.watch(dioClientProvider);

  return FrappeClient(dioClient);
});
