import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/frappe_client.dart';
import 'mobile_app_config.dart';

final mobileAppConfigRepositoryProvider = Provider<MobileAppConfigRepository>(
  (ref) =>
      MobileAppConfigRepository(frappeClient: ref.watch(frappeClientProvider)),
);

final mobileAppConfigProvider = FutureProvider<MobileAppConfig>((ref) async {
  final repository = ref.watch(mobileAppConfigRepositoryProvider);
  Timer? expiry;
  var alive = true;
  ref.onDispose(() {
    alive = false;
    expiry?.cancel();
  });
  final config = await repository.fetchMobileAppConfig();
  if (alive && config.availability == MobileConfigAvailability.current) {
    final delay = config.validUntil!.difference(DateTime.now());
    expiry = Timer(
      delay.isNegative ? Duration.zero : delay,
      ref.invalidateSelf,
    );
  }
  return config;
});

class MobileAppConfigRepository {
  const MobileAppConfigRepository({
    required this.frappeClient,
    this.origin,
    this.clock,
  });

  final FrappeClient frappeClient;
  final String? origin;
  final DateTime Function()? clock;
  DateTime _now() => (clock ?? DateTime.now)().toUtc();
  String get _origin => Uri.parse(origin ?? ApiConfig.baseUrl).origin;
  String get _cacheKey =>
      'omc_public_config_v2_${base64Url.encode(utf8.encode(_origin))}';

  Future<MobileAppConfig> fetchMobileAppConfig() async {
    final cancellation = CancelToken();
    try {
      // The canonical client already has bounded GET retries. Do not layer an
      // unbounded retry loop over it, or save a fabricated enabled fallback.
      final response = await frappeClient
          .getMethod(ApiConfig.mobileAppConfigMethod, cancelToken: cancellation)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              cancellation.cancel('Mobile configuration deadline');
              throw TimeoutException('Mobile configuration is unavailable.');
            },
          );
      final fetchedAt = _now();
      final config = MobileAppConfig.fromApiResponse(
        response,
        fetchedAt: fetchedAt,
      );
      await _cache(response, fetchedAt);
      return config;
    } catch (_) {
      return await _readStale() ?? MobileAppConfig.fallback;
    }
  }

  Future<void> _cache(Map<String, dynamic> payload, DateTime fetchedAt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode({
        'origin': _origin,
        'fetched_at': fetchedAt.toIso8601String(),
        'payload': payload,
      });
      if (encoded.length <= 131072) {
        await prefs.setString(_cacheKey, encoded);
      }
    } catch (_) {
      // Storage failure cannot turn a valid network response into fake data.
    }
  }

  Future<MobileAppConfig?> _readStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_cacheKey);
      if (encoded == null || encoded.length > 131072) {
        return null;
      }
      final saved = jsonDecode(encoded);
      if (saved is! Map<String, dynamic> ||
          saved['origin'] != _origin ||
          saved['fetched_at'] is! String ||
          saved['payload'] is! Map<String, dynamic>) {
        return null;
      }
      final date = DateTime.tryParse(saved['fetched_at'] as String);
      if (date == null || date.isAfter(_now())) {
        return null;
      }
      return MobileAppConfig.fromApiResponse(
        saved['payload'] as Map<String, dynamic>,
        fetchedAt: date,
      ).asStale();
    } catch (_) {
      return null;
    }
  }
}
