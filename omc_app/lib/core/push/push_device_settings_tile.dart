import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
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
              'Notifications could not be enabled on this device. Check Android notification settings or connectivity, then retry.',
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
        final state = _presentationFor(status);
        final message = _error ?? state.message;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _error == null
                            ? AppTheme.processingSoft
                            : AppTheme.dangerSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _error == null
                            ? state.icon
                            : Icons.error_outline_rounded,
                        color: _error == null
                            ? AppTheme.textSecondary
                            : AppTheme.danger,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications on this device',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            state.label,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: _error != null,
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _error == null
                          ? AppTheme.textSecondary
                          : AppTheme.danger,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _enable,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.notifications_outlined),
                    label: Text(_busy ? 'Checking device...' : state.action),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _PushDevicePresentation _presentationFor(PushDeviceStatus status) {
    if (!status.configured) {
      return const _PushDevicePresentation(
        label: 'Device setup unavailable',
        message:
            'Notifications are not configured in this app build. Account notification preferences remain separate from this device state.',
        action: 'Check device setup',
        icon: Icons.notifications_off_outlined,
      );
    }
    if (status.permission == PushPermission.notRequested) {
      return const _PushDevicePresentation(
        label: 'Android permission not requested',
        message:
            'Enable notifications to choose whether Android can show OMC updates on this device.',
        action: 'Enable notifications',
        icon: Icons.notifications_none_rounded,
      );
    }
    if (status.permission != PushPermission.granted) {
      return const _PushDevicePresentation(
        label: 'Android notifications blocked',
        message:
            'Open Android notification settings to review permission for OMC on this device.',
        action: 'Open notification settings',
        icon: Icons.notifications_off_outlined,
      );
    }
    if (status.registered) {
      return const _PushDevicePresentation(
        label: 'Device registered',
        message:
            'This device is registered for OMC updates. Delivery still depends on server push availability and your account notification preferences.',
        action: 'Refresh registration',
        icon: Icons.notifications_active_outlined,
      );
    }
    return const _PushDevicePresentation(
      label: 'Permission granted · registration pending',
      message:
          'Android can show notifications, but this device still needs to register with your current OMC account.',
      action: 'Retry device registration',
      icon: Icons.sync_problem_outlined,
    );
  }
}

class _PushDevicePresentation {
  const _PushDevicePresentation({
    required this.label,
    required this.message,
    required this.action,
    required this.icon,
  });

  final String label;
  final String message;
  final String action;
  final IconData icon;
}
