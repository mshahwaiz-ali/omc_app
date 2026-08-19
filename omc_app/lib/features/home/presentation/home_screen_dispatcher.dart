import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/effective_capabilities_provider.dart';
import 'approved_customer_home_view.dart';
import 'home_screen_role_aware.dart' as legacy;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    this.onOpenServices,
    this.onOpenCalculator,
    this.onOpenSupport,
    this.onOpenNotifications,
  });

  final VoidCallback? onOpenServices;
  final VoidCallback? onOpenCalculator;
  final VoidCallback? onOpenSupport;
  final VoidCallback? onOpenNotifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(effectiveCapabilitiesProvider);
    final useLifecycleCustomerHome =
        capabilities.isApproved &&
        !capabilities.isInternal &&
        (capabilities.canViewCustomerDashboard ||
            capabilities.canAccessCustomerDashboard);

    if (useLifecycleCustomerHome) {
      return ApprovedCustomerHomeView(
        onOpenServices: onOpenServices,
        onOpenCalculator: onOpenCalculator,
        onOpenSupport: onOpenSupport,
        onOpenNotifications: onOpenNotifications,
      );
    }

    // Preserve the established guest, pending/rejected and internal home paths.
    return legacy.HomeScreen(
      onOpenServices: onOpenServices,
      onOpenCalculator: onOpenCalculator,
      onOpenSupport: onOpenSupport,
      onOpenNotifications: onOpenNotifications,
    );
  }
}
