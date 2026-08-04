import 'package:flutter/material.dart';

/// Compatibility wrapper retained for existing imports.
///
/// Biometric authentication is now an explicit, user-triggered login action.
/// The application is no longer automatically locked on launch or resume.
class DeviceLockGate extends StatelessWidget {
  const DeviceLockGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
