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
      return InternalWorkspaceSummary.empty();
    } catch (_) {
      return InternalWorkspaceSummary.empty();
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
