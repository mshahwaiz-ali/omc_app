import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import '../domain/internal_service_case.dart';
import '../domain/internal_workspace_summary.dart';

class InternalWorkspaceRepository {
  const InternalWorkspaceRepository(this._frappeClient);

  final FrappeClient _frappeClient;

  Future<InternalWorkspaceSummary> getSummary() async {
    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.internalWorkspaceSummaryMethod,
      );

      return _mapSummaryResponse(response);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message:
            'Internal workspace summary could not be loaded from the server right now.',
        code: 'internal_workspace_unavailable',
        details: error,
      );
    }
  }

  Future<InternalServiceCaseQueue> getServiceCases({
    String? search,
    String? status,
    String? documentStatus,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};
      final cleanSearch = search?.trim();
      final cleanStatus = status?.trim();
      final cleanDocumentStatus = documentStatus?.trim().toLowerCase();

      if (cleanSearch != null && cleanSearch.isNotEmpty) {
        queryParameters['search'] = cleanSearch;
      }
      if (cleanStatus != null && cleanStatus.isNotEmpty) {
        queryParameters['status'] = cleanStatus;
      }
      if (cleanDocumentStatus != null && cleanDocumentStatus.isNotEmpty) {
        queryParameters['document_status'] = cleanDocumentStatus;
      }

      final response = await _frappeClient.getMethod(
        ApiConfig.internalServiceCasesMethod,
        queryParameters: queryParameters,
      );

      return InternalServiceCaseQueue.fromResponse(response);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message:
            'Service cases could not be loaded from the internal workspace right now.',
        code: 'internal_service_cases_unavailable',
        details: error,
      );
    }
  }

  Future<InternalServiceCase> createServiceRequestForCustomer({
    required String customerProfile,
    required String serviceId,
    String? title,
    String? note,
  }) async {
    final data = <String, dynamic>{
      'customer_profile': customerProfile.trim(),
      'service_id': serviceId.trim(),
    };

    final cleanTitle = title?.trim();
    final cleanNote = note?.trim();
    if (cleanTitle != null && cleanTitle.isNotEmpty) {
      data['title'] = cleanTitle;
    }
    if (cleanNote != null && cleanNote.isNotEmpty) {
      data['note'] = cleanNote;
    }

    if ((data['customer_profile'] as String).isEmpty) {
      throw const ApiError(message: 'Customer profile is required.');
    }
    if ((data['service_id'] as String).isEmpty) {
      throw const ApiError(message: 'Service ID is required.');
    }

    final response = await _frappeClient.postMethod(
      ApiConfig.createServiceRequestForCustomerMethod,
      data: data,
    );

    final message = response['message'];
    final source = message is Map<String, dynamic> ? message : response;
    final rawCase = source['case'];
    if (rawCase is Map<String, dynamic>) {
      return InternalServiceCase.fromJson(rawCase);
    }

    throw const ApiError(
      message:
          'Service request was created but the backend response was incomplete.',
      code: 'internal_service_case_response_invalid',
    );
  }

  InternalWorkspaceSummary _mapSummaryResponse(Map<String, dynamic> data) {
    final message = data['message'];

    if (message is Map<String, dynamic>) {
      return InternalWorkspaceSummary.fromJson(message);
    }

    return InternalWorkspaceSummary.fromJson(data);
  }
}
