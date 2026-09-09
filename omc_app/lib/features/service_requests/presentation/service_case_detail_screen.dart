import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/effective_capabilities_provider.dart';
import 'customer_service_case_detail_screen.dart';
import 'operational_service_case_detail_screen.dart';

class ServiceCaseDetailScreen extends ConsumerWidget {
  const ServiceCaseDetailScreen({
    super.key,
    required this.caseId,
    this.assisted = false,
    this.customerName,
  });

  final String caseId;
  final bool assisted;
  final String? customerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(effectiveCapabilitiesProvider);
    final useCanonicalCustomerDetail =
        !assisted &&
        capabilities.isApproved &&
        !capabilities.isInternal &&
        capabilities.canTrackRequests;

    if (useCanonicalCustomerDetail) {
      return CustomerServiceCaseDetailScreen(caseId: caseId);
    }

    // Assisted, internal and other authorized non-canonical variants keep the
    // established operational repository/mutation authority, but render it in
    // a dedicated operations-first presentation instead of the legacy mixed
    // customer/admin layout. The legacy screen remains in the repository as a
    // historical safety reference and for its focused regression tests.
    return OperationalServiceCaseDetailScreen(
      caseId: caseId,
      assisted: assisted,
      customerName: customerName,
    );
  }
}
