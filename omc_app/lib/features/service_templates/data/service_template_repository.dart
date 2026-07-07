import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import 'service_template.dart';

final serviceTemplateRepositoryProvider = Provider<ServiceTemplateRepository>((ref) {
  return ServiceTemplateRepository(frappeClient: ref.watch(frappeClientProvider));
});

class ServiceTemplateRepository {
  const ServiceTemplateRepository({required this._frappeClient});

  final FrappeClient _frappeClient;

  Future<ServiceTemplate> fetchTemplate(String serviceId) async {
    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.serviceTemplateMethod,
        queryParameters: {'service_id': serviceId},
      );

      final message = response['message'];
      final data = message is Map<String, dynamic> ? message : response;
      return ServiceTemplate.fromJson(data);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message: 'Service form template could not be loaded right now.',
        code: 'service_template_unavailable',
        details: error,
      );
    }
  }
}
