import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import 'admin_control_repository.dart';

const String scopedAdminOverviewMethod =
    'omc_app.api.admin_read.get_admin_overview';

final scopedAdminOverviewProvider = FutureProvider<AdminOverview>((ref) async {
  final client = ref.watch(frappeClientProvider);
  final response = await client.getMethod(scopedAdminOverviewMethod);
  final message = response['message'];
  final payload = message is Map<String, dynamic> ? message : response;
  return AdminOverview.fromJson(payload);
});
