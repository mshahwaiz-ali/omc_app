import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../data/device_lock_service.dart';

class DeviceLockGate extends ConsumerStatefulWidget {
  const DeviceLockGate({required this.child, super.key});
  final Widget child;

  @override
  Consumer