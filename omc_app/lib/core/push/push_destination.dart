import '../../app/route_access_policy.dart';
import '../../features/auth/application/auth_state.dart';

/// Input MUST be the authenticated backend response, never the FCM payload.
/// Saved/provider URLs are deliberately ignored; only known existing routes win.
String? pushDestination(
  Map<String, dynamic> notification,
  AuthCapabilities capabilities,
) {
  final type = notification['reference_doctype'];
  final name = notification['reference_name'];
  String? route;
  if (type == null || type == '') {
    final id = notification['name'];
    if (id is String && id.isNotEmpty) {
      route = '/notifications/${Uri.encodeComponent(id)}';
    }
  } else if (name is String && name.isNotEmpty && name.length <= 140) {
    final id = Uri.encodeComponent(name);
    route = switch (type) {
      'OMC Service Request' =>
        capabilities.isInternal && capabilities.canViewAnyServiceCase
            ? '/internal-workspace/service-cases/$id'
            : '/my-services/$id',
      'OMC Service Document' => '/documents/$id',
      'OMC Service Payment' => '/payments/$id',
      'OMC Support Ticket' => '/support-tickets/$id',
      'Task' => '/tasks/$id',
      _ => null,
    };
  }
  return route != null && canAccessRoute(route, capabilities) ? route : null;
}
