import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import 'service_item.dart';

final serviceCatalogueRepositoryProvider = Provider<ServiceCatalogueRepository>(
  (ref) {
    return const ServiceCatalogueRepository();
  },
);

class ServiceCatalogueRepository {
  const ServiceCatalogueRepository({AssetBundle? assetBundle})
    : this._(assetBundle);

  const ServiceCatalogueRepository._(this._assetBundle);

  final AssetBundle? _assetBundle;

  Future<List<ServiceItem>> fetchServices() async {
    try {
      final bundle = _assetBundle ?? rootBundle;
      final rawJson = await bundle.loadString(
        'assets/data/service_catalogue.json',
      );
      final decoded = jsonDecode(rawJson);

      if (decoded is! List) {
        throw const ApiError(
          message: 'Service catalogue data is not available.',
        );
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ServiceItem.fromJson)
          .where((service) => service.id.isNotEmpty)
          .toList(growable: false);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message: 'Unable to load service catalogue right now.',
        details: error,
      );
    }
  }
}
