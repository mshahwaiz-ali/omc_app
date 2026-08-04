import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'navigation_coordinator.dart';

/// Centralized Android/system-back behavior for the app shell.
class AppBackNavigationGuard extends StatefulWidget {
  const AppBackNavigationGuard({
    required this.child,
    required this.fallbackLocation,
    this.homeLocation = '/home',
    this.exitWindow = const Duration(seconds: 2),
    super.key,
  });

  final Widget child;
  final String fallbackLocation;
  final String homeLocation;
  final Duration exitWindow;

  @override
  State<AppBackNavigationGuard> createState() => _AppBackNavigationGuardState();
}

class _AppBackNavigationGuardState extends State<AppBackNavigationGuard> {
  DateTime? _lastExitRequest;

  @override
  Widget build(BuildContext context) {
    final navigatorCanPop = Navigator.of(context).canPop();

    return PopScope<Object?>(
      canPop: navigatorCanPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleRootBack();
      },
      child: widget.child,
    );
  }

  void _handleRootBack() {
    final currentLocation = GoRouterState.of(context).uri.path;
    final fallback = widget.fallbackLocation;

    final resolvedFallback = NavigationCoordinator.rootFallback(
      currentLocation: currentLocation,
      policyFallback: fallback,
      homeLocation: widget.homeLocation,
    );

    if (currentLocation != resolvedFallback) {
      _lastExitRequest = null;
      context.go(resolvedFallback);
      return;
    }

    final now = DateTime.now();
    final previous = _lastExitRequest;
    if (previous != null && now.difference(previous) <= widget.exitWindow) {
      SystemNavigator.pop();
      return;
    }

    _lastExitRequest = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Press back again to exit'),
          behavior: SnackBarBehavior.floating,
          duration: widget.exitWindow,
        ),
      );
  }
}
