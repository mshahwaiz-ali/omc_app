import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omc_app/core/network/dio_client.dart';
import 'package:omc_app/core/network/frappe_client.dart';
import 'package:omc_app/core/storage/secure_storage_service.dart';
import 'package:omc_app/features/app_config/data/mobile_app_config.dart';
import 'package:omc_app/features/app_config/data/mobile_app_config_repository.dart';

import 'app_gate_batch2_test.dart' show payload;

class ConfigClient extends FrappeClient {
  ConfigClient(this.read)
    : super(DioClient(secureStorageService: SecureStorageService()));
  final Future<Map<String, dynamic>> Function() read;
  int calls = 0;
  @override
  Future<Map<String, dynamic>> getMethod(
    String method, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) {
    calls++;
    return read();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final now = DateTime.utc(2026, 9, 8, 12);
  MobileAppConfigRepository repo(
    ConfigClient client, {
    String origin = 'https://example.test',
  }) => MobileAppConfigRepository(
    frappeClient: client,
    origin: origin,
    clock: () => now,
  );

  test('network outage without cache is unavailable, never enabled', () async {
    final result = await repo(
      ConfigClient(() async => throw StateError('offline')),
    ).fetchMobileAppConfig();
    expect(result.availability, MobileConfigAvailability.unavailable);
    expect(result.features.paymentsEnabled, isFalse);
  });
  test('valid cache is stale and disabled on outage even within TTL', () async {
    var offline = false;
    final client = ConfigClient(() async {
      if (offline) {
        throw StateError('offline');
      }
      return payload();
    });
    final repository = repo(client);
    expect(
      (await repository.fetchMobileAppConfig()).availability,
      MobileConfigAvailability.current,
    );
    offline = true;
    final result = await repository.fetchMobileAppConfig();
    expect(result.availability, MobileConfigAvailability.stale);
    expect(result.features.paymentsEnabled, isFalse);
    expect(client.calls, 2);
  });
  test('origin A cached controls cannot unlock or populate origin B', () async {
    await repo(
      ConfigClient(() async => payload()),
      origin: 'https://a.test',
    ).fetchMobileAppConfig();
    final result = await repo(
      ConfigClient(() async => throw StateError('offline')),
      origin: 'https://b.test',
    ).fetchMobileAppConfig();
    expect(result.availability, MobileConfigAvailability.unavailable);
  });
  test(
    'malformed network controls cannot replace known maintenance cache',
    () async {
      await repo(
        ConfigClient(() async => payload(maintenance: true)),
      ).fetchMobileAppConfig();
      final result = await repo(
        ConfigClient(() async => {'features': {}}),
      ).fetchMobileAppConfig();
      expect(result.availability, MobileConfigAvailability.stale);
      expect(result.controls.maintenanceMode, isTrue);
    },
  );
}
