import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/effective_capabilities_provider.dart';
import 'customer_service_case_detail_screen.dart';
import 'service_case_detail_legacy_screen.dart' as legacy;

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

    // Internal operations, assisted-service workflows and non-customer states
    // keep the established detail implementation and its administrative tools.
    return legacy.ServiceCaseDetailScreen(
      caseId: caseId,
      assisted: assisted,
      customerName: customerName,
    );
  }
}
