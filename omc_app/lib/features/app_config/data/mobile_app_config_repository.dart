import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/frappe_client.dart';
import 'mobile_app_config.dart';

final mobileAppConfigRepositoryProvider = Provider<MobileAppConfigRepository>((
  ref,
) {
  return MobileAppConfigRepository(
    frappeClient: ref.watch(frappeClientProvider),
  );
});

final mobileAppConfigProvider = FutureProvider<MobileAppConfig>((ref) async {
  final repository = ref.watch(mobileAppConfigRepositoryProvider);
  return repository.fetchMobileAppConfig();
});

class MobileAppConfigRepository {
  const MobileAppConfigRepository({required this.frappeClient});

  final FrappeClient frappeClient;

  Future<MobileAppConfig> fetchMobileAppConfig() async {
    try {
      final response = await frappeClient.getMethod(
        ApiConfig.mobileAppConfigMethod,
      );
      return MobileAppConfig.fromApiResponse(response);
    } catch (_) {
      return MobileAppConfig.fallback;
    }
  }
}
