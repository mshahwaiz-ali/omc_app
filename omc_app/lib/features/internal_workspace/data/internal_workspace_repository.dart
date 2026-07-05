import '../../../core/config/api_config.dart';
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
    } catch (_) {
      // Keep Internal Workspace usable during local/UI testing while backend APIs are pending.
      return _sampleSummary;
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

const InternalWorkspaceSummary _sampleSummary = InternalWorkspaceSummary(
  openLeads: 0,
  activeCustomers: 0,
  pendingTasks: 0,
  pendingPayments: 0,
);
