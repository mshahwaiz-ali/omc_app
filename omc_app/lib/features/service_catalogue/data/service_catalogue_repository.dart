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

    try {
      return await _fetchBackendServices();
    } on ApiError {
      if (Env.allowServiceCatalogueFallback) {
        return _fetchAssetServices();
      }

      rethrow;
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
          message: 'Service catalogue preview data is not available.',
        );
      }

      return _uniqueServices(
        decoded
            .whereType<Map<String, dynamic>>()
            .map(ServiceItem.fromJson)
            .where((service) => service.id.isNotEmpty),
      );
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message: 'Unable to load service catalogue preview right now.',
        details: error,
      );
    }
  }

  Future<List<ServiceItem>> _fetchBackendServices() async {
    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.serviceCatalogueMethod,
      );

      return _servicesFromResponse(response);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message:
            'OMC services could not be loaded from the server right now. Please retry or contact support.',
        code: 'service_catalogue_unavailable',
        details: error,
      );
    }
  }

  Iterable<Map<String, dynamic>> _expandServiceRecord(
    Map<String, dynamic> record,
  ) sync* {
    final nestedGroups =
        record['groups'] ??
        record['categories'] ??
        record['service_groups'] ??
        record['service_categories'];

    if (nestedGroups is List) {
      for (final group in nestedGroups.whereType<Map<String, dynamic>>()) {
        yield* _expandServiceRecord(group);
      }
      return;
    }

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
    final rawServices = _rawServicesFromResponse(response);

    if (rawServices is List) {
      return _uniqueServices(
        rawServices
            .whereType<Map<String, dynamic>>()
            .expand(_expandServiceRecord)
            .map(ServiceItem.fromJson)
            .where((service) => service.id.isNotEmpty),
      );
    }

    if (rawServices is Map<String, dynamic>) {
      return _uniqueServices(
        _expandServiceRecord(rawServices)
            .map(ServiceItem.fromJson)
            .where((service) => service.id.isNotEmpty),
      );
    }

    throw const ApiError(
      message: 'Service catalogue response was not in the expected format.',
      code: 'service_catalogue_invalid_response',
    );
  }

  List<ServiceItem> _uniqueServices(Iterable<ServiceItem> services) {
    final seen = <String>{};
    final unique = <ServiceItem>[];

    for (final service in services) {
      final key = service.id.trim();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      unique.add(service);
    }

    return unique;
  }

  Object? _rawServicesFromResponse(Map<String, dynamic> response) {
    final message = response['message'];

    if (message is List) return message;

    if (message is Map<String, dynamic>) {
      return message['services'] ??
          message['service_groups'] ??
          message['service_categories'] ??
          message['groups'] ??
          message['categories'] ??
          message['data'] ??
          message['items'] ??
          message['rows'] ??
          message['results'] ??
          message['records'] ??
          message['catalogue'] ??
          message['service_catalogue'];
    }

    if (response.containsKey('services')) return response['services'];
    if (response.containsKey('service_groups')) return response['service_groups'];
    if (response.containsKey('service_categories')) {
      return response['service_categories'];
    }
    if (response.containsKey('groups')) return response['groups'];
    if (response.containsKey('categories')) return response['categories'];
    if (response.containsKey('data')) return response['data'];
    if (response.containsKey('items')) return response['items'];
    if (response.containsKey('rows')) return response['rows'];
    if (response.containsKey('results')) return response['results'];
    if (response.containsKey('records')) return response['records'];
    if (response.containsKey('catalogue')) return response['catalogue'];
    if (response.containsKey('service_catalogue')) {
      return response['service_catalogue'];
    }

    return null;
  }
}
