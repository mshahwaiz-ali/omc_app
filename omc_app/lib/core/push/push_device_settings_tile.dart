import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import 'push_registration.dart';

class PushDeviceSettingsTile extends ConsumerStatefulWidget {
  const PushDeviceSettingsTile({super.key});
  @override
  ConsumerState<PushDeviceSettingsTile> createState() =>
      _PushDeviceSettingsTileState();
}

class _PushDeviceSettingsTileState
    extends ConsumerState<PushDeviceSettingsTile> {
  bool _busy = false;
  String? _error;

  Future<void> _enable() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final coordinator = ref.read(pushRegistrationProvider);
    final owner = ref.read(authControllerProvider).userId;
    try {
      await coordinator.boundSource?.enableNotifications();
      if (!mounted || ref.read(authControllerProvider).userId != owner) return;
      await coordinator.syncForAuth(
        ref.read(authControllerProvider),
        refresh: true,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Notifications could not be enabled. Retry after checking configuration or connectivity.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.watch(pushRegistrationProvider);
    if (coordinator.source.platform != 'android') {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<PushDeviceStatus>(
      valueListenable: coordinator.status,
      builder: (context, status, _) {
        final detail = !status.configured
            ? 'Firebase is not configured in this build.'
            : status.permission == PushPermission.notRequested
            ? 'Choose whether Android can show OMC updates.'
            : status.permission != PushPermission.granted
            ? 'Notifications are blocked. Review Android notification settings.'
            : status.registered
            ? 'This device is registered. Delivery also requires server push configuration and enabled preferences.'
            : 'Android permission is granted. Device registration needs a retry.';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications on this device',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(_error ?? detail),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _busy ? null : _enable,
                  icon: const Icon(Icons.notifications_outlined),
                  label: Text(
                    _busy
                        ? 'Checking...'
                        : status.registered
                        ? 'Refresh registration'
                        : 'Enable / retry',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
