import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/push/push_device_settings_tile.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../app_config/data/mobile_app_config.dart';
import '../../app_config/data/mobile_app_config_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../device_lock/data/device_lock_service.dart';
import '../../profile/data/profile_repository.dart';
import '../../support/data/support_repository.dart';
import '../data/settings_preferences.dart';
import '../data/settings_repository.dart';
import 'settings_screen.dart' show appPackageInfoProvider;

bool _settingsV2PreferenceSaveInFlight = false;
bool _settingsV2AccountRequestInFlight = false;
bool _settingsV2LogoutInFlight = false;

class SettingsV2Screen extends ConsumerWidget {
  const SettingsV2Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(settingsPreferencesProvider);
    final authState = ref.watch(authControllerProvider);
    final profileSummary = ref.watch(profileSummaryProvider);
    final mobileConfig =
        ref.watch(mobileAppConfigProvider).value ?? MobileAppConfig.fallback;
    final packageInfo = ref.watch(appPackageInfoProvider);
    final activeIdentity = authState.userId?.trim() ?? '';
    final biometricEnabled =
        activeIdentity.isNotEmpty &&
        ref.watch(biometricLoginEnabledForProvider(activeIdentity)).value ==
            true;
    final profile = profileSummary.maybeWhen(
      data: (profile) => profile,
      orElse: () => null,
    );
    final accountName = profile?.displayName ?? authState.displayName;
    final accountStatus = profile?.status ?? authState.customerStatus;
    final approvalStatus = profile?.approvalStatus ?? authState.approvalStatus;
    final isInternal =
        authState.capabilities.isInternal ||
        authState.canAccessInternalWorkspace;

    return Scaffold(
      key: OmcWidgetKeys.settingsScreen,
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          children: [
            Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'Account security, notifications and app information',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            _AccountIdentityCard(
              accountName: accountName,
              accountStatus: accountStatus,
              approvalStatus: approvalStatus,
            ),
            const SizedBox(height: 22),
            const _SectionHeading(title: 'Profile'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.person_outline_rounded,
                  title: 'Profile',
                  supporting: 'Personal, contact and business details',
                  trailing: 'Edit',
                  onTap: () => context.push('/profile/edit'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionHeading(title: 'Security'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.lock_outline_rounded,
                  title: 'Password',
                  supporting: 'Change your OMC account password',
                  trailing: 'Change',
                  onTap: () => context.push('/change-password'),
                ),
                const Divider(height: 1),
                _SettingsRow(
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometric sign in',
                  supporting: biometricEnabled
                      ? 'Enabled for this account on this device'
                      : 'Optional fingerprint or device authentication shortcut',
                  trailing: biometricEnabled ? 'On' : 'Off',
                  onTap: () => _toggleDeviceLock(
                    context,
                    ref,
                    currentlyEnabled: biometricEnabled,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionHeading(title: 'Notifications'),
            const SizedBox(height: 10),
            const PushDeviceSettingsTile(),
            if (!isInternal) ...[
              const SizedBox(height: 10),
              preferencesAsync.when(
                loading: () => const _PreferencesLoadingCard(),
                error: (error, _) {
                  final failure = AppFailureClassifier.classify(
                    error,
                    fallbackTitle: 'Preferences unavailable',
                    fallbackMessage:
                        'Notification preferences could not be loaded right now.',
                  );
                  return _PreferencesCard(
                    preferences: const SettingsPreferences(),
                    errorMessage: failure.message,
                    onRetry: () => ref.invalidate(settingsPreferencesProvider),
                    onToggle: null,
                  );
                },
                data: (preferences) => _PreferencesCard(
                  preferences: preferences ?? const SettingsPreferences(),
                  errorMessage: null,
                  onRetry: () => ref.invalidate(settingsPreferencesProvider),
                  onToggle: (updated) =>
                      _savePreferences(context, ref, updated),
                ),
              ),
            ],
            const SizedBox(height: 22),
            const _SectionHeading(title: 'Legal'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy policy',
                  supporting: 'How OMC handles customer and service data',
                  trailing: 'View',
                  onTap: () => _openLegalDocument(
                    context,
                    title: 'Privacy policy',
                    url: mobileConfig.legal.privacyPolicyUrl,
                    message: mobileConfig.legal.privacyPolicyText,
                  ),
                ),
                const Divider(height: 1),
                _SettingsRow(
                  icon: Icons.description_outlined,
                  title: 'Terms & Conditions',
                  supporting: 'Service usage, support and account access terms',
                  trailing: 'View',
                  onTap: () => _openLegalDocument(
                    context,
                    title: 'Terms & Conditions',
                    url: mobileConfig.legal.termsUrl,
                    message: mobileConfig.legal.termsText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionHeading(title: 'About'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.phone_iphone_rounded,
                  title: 'OMC Mobile App',
                  supporting: packageInfo.maybeWhen(
                    data: (info) =>
                        'Version ${info.version}+${info.buildNumber}',
                    orElse: () => 'App version information',
                  ),
                  trailing: packageInfo.maybeWhen(
                    data: (info) => info.appName,
                    orElse: () => '',
                  ),
                  onTap: () => _showSnack(
                    context,
                    packageInfo.maybeWhen(
                      data: (info) =>
                          '${info.appName} ${info.version}+${info.buildNumber}',
                      orElse: () => 'OMC Mobile App',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionHeading(title: 'Account actions'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete account request',
                  supporting: 'Ask OMC to review and process account deletion',
                  trailing: 'Request',
                  destructive: true,
                  onTap: () => _showAccountRequestSheet(
                    context,
                    ref,
                    title: 'Delete account request',
                    topic: 'Delete account request',
                    label: 'Reason or instructions',
                    hint:
                        'Example: Please delete my mobile app account and related access.',
                    submitLabel: 'Submit deletion request',
                  ),
                ),
                const Divider(height: 1),
                _SettingsRow(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  supporting: 'Clear the secure session on this device',
                  trailing: 'Exit',
                  destructive: true,
                  onTap: () => _confirmLogout(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePreferences(
    BuildContext context,
    WidgetRef ref,
    SettingsPreferences preferences,
  ) async {
    if (_settingsV2PreferenceSaveInFlight) return;
    _settingsV2PreferenceSaveInFlight = true;

    try {
      await ref.read(settingsRepositoryProvider).savePreferences(preferences);
      if (!context.mounted) return;
      ref.invalidate(settingsPreferencesProvider);
      _showSnack(context, 'Settings preferences updated.');
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Preferences not updated',
        fallbackMessage: 'Could not update settings preferences right now.',
      );
      _showSnack(context, failure.message);
    } finally {
      _settingsV2PreferenceSaveInFlight = false;
    }
  }

  Future<void> _toggleDeviceLock(
    BuildContext context,
    WidgetRef ref, {
    required bool currentlyEnabled,
  }) async {
    final service = ref.read(deviceLockServiceProvider);
    if (currentlyEnabled) {
      final identity = ref.read(authControllerProvider).userId?.trim() ?? '';
      if (identity.isNotEmpty) {
        await service.disableBiometricLoginFor(identity);
      }

      ref.read(deviceLockSessionUnlockedProvider.notifier).markUnlocked();
      ref.invalidate(deviceLockEnabledProvider);
      ref.invalidate(biometricLoginAvailableProvider);
      ref.invalidate(biometricLoginAccountsProvider);
      if (identity.isNotEmpty) {
        ref.invalidate(biometricLoginEnabledForProvider(identity));
      }

      if (context.mounted) {
        _showSnack(context, 'Biometric sign in disabled for this account.');
      }
      return;
    }

    if (!await service.isSupported()) {
      if (context.mounted) {
        _showSnack(
          context,
          'Biometric authentication is not configured on this device.',
        );
      }
      return;
    }

    if (!context.mounted) return;
    final password = await _requestDeviceLockPassword(context);
    if (!context.mounted || password == null || password.isEmpty) return;

    final authState = ref.read(authControllerProvider);
    final identifier = authState.userId?.trim() ?? '';
    if (identifier.isEmpty) {
      _showSnack(context, 'Your signed-in account could not be identified.');
      return;
    }

    try {
      await ref
          .read(authRepositoryProvider)
          .verifyCurrentPassword(currentPassword: password);
    } catch (_) {
      if (context.mounted) {
        _showSnack(context, 'Password verification failed.');
      }
      return;
    }

    if (!context.mounted) return;
    ref.read(deviceLockSessionUnlockedProvider.notifier).markUnlocked();

    try {
      final enabled = await service.enableBiometricLogin(
        identifier: identifier,
        password: password,
      );

      ref.invalidate(deviceLockEnabledProvider);
      ref.invalidate(biometricLoginAvailableProvider);
      ref.invalidate(biometricLoginAccountsProvider);
      ref.invalidate(biometricLoginEnabledForProvider(identifier));

      if (!context.mounted) return;
      if (enabled) {
        ref.read(deviceLockSessionUnlockedProvider.notifier).markUnlocked();
      }
      _showSnack(
        context,
        enabled
            ? 'Biometric sign in enabled.'
            : 'Biometric setup was cancelled. You can continue using your password.',
      );
    } catch (error) {
      ref.invalidate(deviceLockEnabledProvider);
      ref.invalidate(biometricLoginAvailableProvider);
      ref.invalidate(biometricLoginAccountsProvider);
      ref.invalidate(biometricLoginEnabledForProvider(identifier));
      if (context.mounted) {
        final failure = AppFailureClassifier.classify(
          error,
          fallbackTitle: 'Biometric setup not completed',
          fallbackMessage:
              'Biometric sign in could not be enabled. Your password sign in remains available.',
        );
        _showSnack(context, failure.message);
      }
    }
  }

  Future<String?> _requestDeviceLockPassword(BuildContext context) async {
    var passwordValue = '';
    var obscure = true;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Enable biometric sign in'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Confirm your current OMC password. It will be protected by the device secure storage and used only after successful biometric authentication.',
                ),
                const SizedBox(height: 16),
                TextField(
                  obscureText: obscure,
                  onChanged: (value) => passwordValue = value,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      Navigator.of(dialogContext).pop(value);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setDialogState(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (passwordValue.isNotEmpty) {
                  Navigator.of(dialogContext).pop(passwordValue);
                }
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAccountRequestSheet(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String topic,
    required String label,
    required String hint,
    required String submitLabel,
  }) async {
    final controller = TextEditingController();
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AccountRequestSheet(
        title: title,
        label: label,
        hint: hint,
        submitLabel: submitLabel,
        controller: controller,
      ),
    );
    controller.dispose();

    final cleanMessage = message?.trim();
    if (cleanMessage == null || cleanMessage.isEmpty) return;
    if (!context.mounted || _settingsV2AccountRequestInFlight) return;

    _settingsV2AccountRequestInFlight = true;
    try {
      await ref
          .read(supportRepositoryProvider)
          .createSupportTicket(topic: topic, message: cleanMessage);
      if (!context.mounted) return;
      _showSnack(context, '$title submitted to OMC support.');
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Request not submitted',
        fallbackMessage:
            'Your account request could not be submitted right now.',
      );
      _showSnack(context, failure.message);
    } finally {
      _settingsV2AccountRequestInFlight = false;
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.logout_rounded, size: 36, color: AppTheme.danger),
            const SizedBox(height: 14),
            Text(
              'Logout from OMC?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Your secure session will be cleared on this device. You can login again anytime.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(sheetContext).pop(true),
              child: const Text('Logout'),
            ),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    if (shouldLogout != true || !context.mounted || _settingsV2LogoutInFlight) {
      return;
    }

    _settingsV2LogoutInFlight = true;
    try {
      await ref.read(authControllerProvider.notifier).logout();
      ref.invalidate(profileSummaryProvider);
      if (!context.mounted) return;
      context.go('/login');
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Logout incomplete',
        fallbackMessage:
            'The session could not be cleared right now. Please try again.',
      );
      _showSnack(context, failure.message);
    } finally {
      _settingsV2LogoutInFlight = false;
    }
  }

  Future<void> _showPolicySheet(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55,
              ),
              child: SingleChildScrollView(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLegalDocument(
    BuildContext context, {
    required String title,
    required String? url,
    required String message,
  }) async {
    final uri = _safeExternalUri(url);
    if (uri != null) {
      try {
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (opened) return;
      } catch (_) {
        // Fall through to backend-provided legal copy.
      }
    }

    if (!context.mounted) return;
    await _showPolicySheet(context, title: title, message: message);
  }

  Uri? _safeExternalUri(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    return uri;
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AccountIdentityCard extends StatelessWidget {
  const _AccountIdentityCard({
    this.accountName,
    this.accountStatus,
    this.approvalStatus,
  });

  final String? accountName;
  final String? accountStatus;
  final String? approvalStatus;

  @override
  Widget build(BuildContext context) {
    final statuses = <String>[
      if (accountStatus?.trim().isNotEmpty == true) accountStatus!.trim(),
      if (approvalStatus?.trim().isNotEmpty == true) approvalStatus!.trim(),
    ];

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            accountName?.trim().isNotEmpty == true
                ? accountName!.trim()
                : 'Signed-in account',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (statuses.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in statuses.toSet())
                  OmcStatusBadge(
                    label: status,
                    color: OmcPremium.statusColor(status),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.supporting,
    required this.trailing,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String supporting;
  final String trailing;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive ? AppTheme.danger : AppTheme.textPrimary;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: destructive
                        ? AppTheme.dangerSoft
                        : AppTheme.cardSoft,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Icon(
                    icon,
                    color: destructive
                        ? AppTheme.danger
                        : AppTheme.textSecondary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: foreground),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        supporting,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (trailing.trim().isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      trailing,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: destructive
                            ? AppTheme.danger
                            : AppTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({
    required this.preferences,
    required this.errorMessage,
    required this.onRetry,
    required this.onToggle,
  });

  final SettingsPreferences preferences;
  final String? errorMessage;
  final VoidCallback onRetry;
  final ValueChanged<SettingsPreferences>? onToggle;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          if (errorMessage != null) ...[
            _InlinePreferenceError(message: errorMessage!, onRetry: onRetry),
            const Divider(height: 1),
          ],
          _PreferenceSwitch(
            title: 'In-app notifications',
            value: preferences.inAppNotificationsEnabled,
            onChanged: onToggle == null
                ? null
                : (value) => onToggle!(
                    preferences.copyWith(inAppNotificationsEnabled: value),
                  ),
          ),
          if (preferences.pushProviderOperational) ...[
            const Divider(height: 1),
            _PreferenceSwitch(
              title: 'Push notifications',
              value: preferences.pushNotificationsEnabled,
              onChanged: onToggle == null
                  ? null
                  : (value) => onToggle!(
                      preferences.copyWith(pushNotificationsEnabled: value),
                    ),
            ),
          ],
          const Divider(height: 1),
          _PreferenceSwitch(
            title: 'Service updates',
            value: preferences.serviceUpdatesEnabled,
            onChanged: onToggle == null
                ? null
                : (value) => onToggle!(
                    preferences.copyWith(serviceUpdatesEnabled: value),
                  ),
          ),
          const Divider(height: 1),
          _PreferenceSwitch(
            title: 'Document reminders',
            value: preferences.documentRemindersEnabled,
            onChanged: onToggle == null
                ? null
                : (value) => onToggle!(
                    preferences.copyWith(documentRemindersEnabled: value),
                  ),
          ),
          const Divider(height: 1),
          _PreferenceSwitch(
            title: 'Payment alerts',
            value: preferences.paymentAlertsEnabled,
            onChanged: onToggle == null
                ? null
                : (value) => onToggle!(
                    preferences.copyWith(paymentAlertsEnabled: value),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _InlinePreferenceError extends StatelessWidget {
  const _InlinePreferenceError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppTheme.danger,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _PreferencesLoadingCard extends StatelessWidget {
  const _PreferencesLoadingCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SkeletonLine(width: 180),
          SizedBox(height: 14),
          _SkeletonLine(),
          SizedBox(height: 10),
          _SkeletonLine(width: 220),
        ],
      ),
    );
  }
}

class _AccountRequestSheet extends StatelessWidget {
  const _AccountRequestSheet({
    required this.title,
    required this.label,
    required this.hint,
    required this.submitLabel,
    required this.controller,
  });

  final String title;
  final String label;
  final String hint;
  final String submitLabel;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.82,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      minLines: 4,
                      maxLines: 7,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: label,
                        hintText: hint,
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pop(controller.text),
                      icon: const Icon(Icons.send_rounded),
                      label: Text(submitLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({this.width});
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: 14,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
