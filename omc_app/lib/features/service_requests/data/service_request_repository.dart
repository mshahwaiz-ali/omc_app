import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/frappe_client.dart';

final serviceRequestRepositoryProvider = Provider<ServiceRequestRepository>((
  ref,
) {
  return ServiceRequestRepository(
    frappeClient: ref.watch(frappeClientProvider),
  );
});

class ServiceRequestRepository {
  const ServiceRequestRepository({required FrappeClient frappeClient})
    : this._(frappeClient);

  const ServiceRequestRepository._(this._frappeClient);

  final FrappeClient _frappeClient;

  Future<Map<String, dynamic>> createLead({
    required Map<String, dynamic> data,
  }) {
    // TODO: Map customer service-request payload to Frappe create_lead schema.
    return _frappeClient.postMethod(ApiConfig.createLeadMethod, data: data);
  }

  Future<Map<String, dynamic>> createService({
    required Map<String, dynamic> data,
  }) {
    // TODO: Map internal/partner lead payload to Frappe create_service schema.
    return _frappeClient.postMethod(ApiConfig.createServiceMethod, data: data);
  }

  Future<Map<String, dynamic>> uploadFile({
    required String filePath,
    required String fileName,
    required String doctype,
    required String docname,
    bool isPrivate = true,
  }) {
    // TODO: Wire document picker output and progress reporting into this call.
    return _frappeClient.uploadFile(
      filePath: filePath,
      fileName: fileName,
      doctype: doctype,
      docname: docname,
      isPrivate: isPrivate,
    );
  }
}
