import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
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

  InternalWorkspaceSummary _mapSummaryResponse(Map<String, dynamic> data) {
    final message = data['message'];

    if (message is Map<String, dynamic>) {
      return InternalWorkspaceSummary.fromJson(message);
    }

    return InternalWorkspaceSummary.fromJson(data);
  }
}
