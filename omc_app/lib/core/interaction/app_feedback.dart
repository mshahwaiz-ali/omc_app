import 'package:flutter/services.dart';

/// Centralizes subtle system feedback so interaction polish stays consistent.
///
/// Haptics are intentionally limited to meaningful actions and selections.
/// Platform implementations that do not support haptics safely ignore these
/// system calls.
class AppFeedback {
  const AppFeedback._();

  static void selection() {
    HapticFeedback.selectionClick();
  }

  static void action() {
    HapticFeedback.lightImpact();
  }

  static void success() {
    HapticFeedback.mediumImpact();
  }
}
