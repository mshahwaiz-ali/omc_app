import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavigationCoordinator {
  const NavigationCoordinator._();

  static Future<void> back(
    BuildContext context, {
    required String fallbackLocation,
  }) async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      await navigator.maybePop();
      return;
    }
    if (context.mounted) context.go(fallbackLocation);
  }

  static String rootFallback({
    required String currentLocation,
    required String policyFallback,
    String homeLocation = '/home',
  }) {
    if (policyFallback.isNotEmpty && currentLocation != policyFallback) {
      return policyFallback;
    }
    return homeLocation;
  }
}
