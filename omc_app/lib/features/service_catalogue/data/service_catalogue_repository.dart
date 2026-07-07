import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/env.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import 'service_item.dart';

final serviceCatalogueRepositoryProvider = Provider<ServiceCatalogueRepository>(
  (ref) {
    return ServiceCatalogueRepository(
      frappeClient: ref.watch(frappeClientProvider),
    );
  },
);

class ServiceCatalogueRepository {
  const ServiceCatalogueRepository({
    required FrappeClient frappeClient,
    AssetBundle? assetBundle,
  }) : this._(frappeClient, assetBundle);

  const ServiceCatalogueRepository._(this._frappeClient, this._assetBundle);

  final FrappeClient _frappeClient;
  final AssetBundle? _assetBundle;

  Future<List<ServiceItem>> fetchServices() async {
    if (Env.useServicePreview) {
      return _fetchAssetServices();
    }

    if (Env.isProduction || Env.current == AppEnvironment.staging) {
      return _fetchBackendServices();
    }

    try {
      return await _fetchBackendServices();
    } on ApiError {
      if (Env.useBackendServiceCatalogue) {
        rethrow;
      }

      return _fetchAssetServices();
    }
  }

  Future<List<ServiceItem>> _fetchAssetServices() async {
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

  Future<List<ServiceItem>> _fetchBackendServices() async {
    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.serviceCatalogueMethod,
      );

      final services = _servicesFromResponse(response);
      if (services.isEmpty) {
        throw const ApiError(
          message: 'No services are available from the OMC server yet.',
          code: 'empty_service_catalogue',
        );
      }

      return services;
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message:
            'Service catalogue is not connected on the server yet. The local catalogue remains available when backend catalogue mode is disabled.',
        code: 'service_catalogue_unavailable',
        details: error,
      );
    }
  }

  Iterable<Map<String, dynamic>> _expandServiceRecord(
    Map<String, dynamic> record,
  ) sync* {
    final nestedServices =
        record['services'] ??
        record['items'] ??
        record['children'] ??
        record['service_items'];

    if (nestedServices is List) {
      for (final item in nestedServices.whereType<Map<String, dynamic>>()) {
        yield {
          ...record,
          ...item,
          'category':
              item['category'] ??
              item['service_category'] ??
              record['category'] ??
              record['service_category'] ??
              record['title'] ??
              record['name'],
        };
      }
      return;
    }

    yield record;
  }

  List<ServiceItem> _servicesFromResponse(Map<String, dynamic> response) {
    final message = response['message'];
    final rawServices = message is List
        ? message
        : message is Map<String, dynamic>
        ? message['services'] ??
              message['data'] ??
              message['items'] ??
              message['rows'] ??
              message['catalogue'] ??
              message['service_catalogue']
        : response['services'] ??
              response['data'] ??
              response['items'] ??
              response['rows'] ??
              response['catalogue'] ??
              response['service_catalogue'];

    if (rawServices is List) {
      return rawServices
          .whereType<Map<String, dynamic>>()
          .expand(_expandServiceRecord)
          .map(ServiceItem.fromJson)
          .where((service) => service.id.isNotEmpty)
          .toList(growable: false);
    }

    if (rawServices is Map<String, dynamic>) {
      return _expandServiceRecord(rawServices)
          .map(ServiceItem.fromJson)
          .where((service) => service.id.isNotEmpty)
          .toList(growable: false);
    }

    return const [];
  }
}
