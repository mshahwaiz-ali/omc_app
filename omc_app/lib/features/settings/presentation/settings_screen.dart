import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../support/data/support_repository.dart';
import '../data/settings_preferences.dart';
import '../data/settings_repository.dart';

final appPackageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(settingsPreferencesProvider);
    final authState = ref.watch(authControllerProvider);
    final profileSummary = ref.watch(profileSummaryProvider);
    final packageInfo = ref.watch(appPackageInfoProvider);
    final profile = profileSummary.maybeWhen(
      data: (profile) => profile,
      orElse: () => null,
    );
    final accountName = profile?.displayName ?? authState.displayName;
    final accountStatus = profile?.status ?? authState.customerStatus;
    final approvalStatus = profile?.approvalStatus ?? authState.approvalStatus;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            _SettingsHero(
              accountName: accountName,
              accountStatus: accountStatus,
              approvalStatus: approvalStatus,
            ),
            const SizedBox(height: 22),
            _SettingsSection(
              title: 'Account',
              subtitle: 'Manage profile, security and active app session.',
              children: [
                _SettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Profile preferences',
                  subtitle: accountName ?? 'Customer identity and account details',
                  trailing: approvalStatus ?? accountStatus ?? 'Ready',
                  onTap: () => context.push('/profile'),
                ),
                const _DividerIndent(),
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Security',
                  subtitle: 'Password, device and account protection',
                  trailing: 'Secure',
                  onTap: () => _showAccountRequestSheet(
                    context,
                    ref,
                    title: 'Security request',
                    topic: 'Account security / password change',
                    label: 'What do you need help with?',
                    hint: 'Example: I want to change my password or secure my account.',
                    submitLabel: 'Submit security request',
                  ),
                ),
                const _DividerIndent(),
                _SettingsTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete account request',
                  subtitle: 'Ask OMC to review and process account deletion',
                  trailing: 'Request',
                  isDestructive: true,
                  onTap: () => _showAccountRequestSheet(
                    context,
                    ref,
                    title: 'Delete account request',
                    topic: 'Delete account request',
                    label: 'Reason or instructions',
                    hint: 'Example: Please delete my mobile app account and related access.',
                    submitLabel: 'Submit deletion request',
                  ),
                ),
                const _DividerIndent(),
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  subtitle: 'Clear secure session and return to login',
                  trailing: 'Exit',
                  isDestructive: true,
                  onTap: () => _confirmLogout(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 20),
            preferencesAsync.when(
              data: (preferences) => _PreferencesSection(
                preferences: preferences ?? const SettingsPreferences(),
                errorMessage: null,
                onRetry: () => ref.invalidate(settingsPreferencesProvider),
                onToggle: (updatedPreferences) =>
                    _savePreferences(context, ref, updatedPreferences),
              ),
              loading: () => const _PreferencesLoadingSection(),
              error: (error, _) => _PreferencesSection(
                preferences: const SettingsPreferences(),
                errorMessage: _settingsErrorMessage(error),
                onRetry: () => ref.invalidate(settingsPreferencesProvider),
                onToggle: (updatedPreferences) =>
                    _savePreferences(context, ref, updatedPreferences),
              ),
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Legal',
              subtitle: 'Customer-facing policy and terms shortcuts.',
              children: [
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy policy',
                  subtitle: 'How OMC handles customer and service data',
                  trailing: 'View',
                  onTap: () => _showPolicySheet(
                    context,
                    title: 'Privacy policy',
                    message:
                        'OMC will use customer information to manage service requests, documents, support, notifications and account access. Full legal text can be linked from backend settings when available.',
                  ),
                ),
                const _DividerIndent(),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Terms & Conditions',
                  subtitle: 'Service usage, support and account access terms',
                  trailing: 'View',
                  onTap: () => _showPolicySheet(
                    context,
                    title: 'Terms & Conditions',
                    message:
                        'OMC services are subject to review, approval, document verification and applicable compliance requirements. Full legal text can be linked from backend settings when available.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'About',
              subtitle: 'App readiness, sync behaviour and product details.',
              children: [
                _SettingsTile(
                  icon: Icons.phone_iphone_rounded,
                  title: 'OMC Mobile App',
                  subtitle: packageInfo.maybeWhen(
                    data: (info) => 'Version ${info.version}+${info.buildNumber}',
                    orElse: () => 'Premium customer service app',
                  ),
                  trailing: packageInfo.maybeWhen(
                    data: (info) => info.appName,
                    orElse: () => 'Flutter',
                  ),
                  onTap: () => _showSnack(
                    context,
                    packageInfo.maybeWhen(
                      data: (info) => '${info.appName} ${info.version}+${info.buildNumber}',
                      orElse: () => 'OMC Mobile App',
                    ),
                  ),
                ),
                const _DividerIndent(),
                _SettingsTile(
                  icon: Icons.sync_rounded,
                  title: 'Account sync',
                  subtitle: 'Preferences sync with backend account controls',
                  trailing: 'Ready',
                  onTap: () => _showSnack(
                    context,
                    'Preferences sync automatically when account controls are available.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SettingsFootnote(),
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
    try {
      await ref.read(settingsRepositoryProvider).savePreferences(preferences);
      if (!context.mounted) return;
      ref.invalidate(settingsPreferencesProvider);
      _showSnack(context, 'Settings preferences updated.');
    } on ApiError catch (error) {
      if (!context.mounted) return;
      _showSnack(context, error.message);
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(context, 'Could not update settings preferences yet.');
    }
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
      backgroundColor: Colors.transparent,
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

    try {
      await ref
          .read(supportRepositoryProvider)
          .createSupportTicket(topic: topic, message: cleanMessage);
      if (!context.mounted) return;
      _showSnack(context, '$title submitted to OMC support.');
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, _settingsErrorMessage(error));
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LargeIcon(icon: Icons.logout_rounded),
              const SizedBox(height: 16),
              const Text('Logout from OMC?', style: _TextStyles.sheetTitle),
              const SizedBox(height: 8),
              const Text(
                'Your secure session will be cleared on this device. You can login again anytime.',
                textAlign: TextAlign.center,
                style: _TextStyles.body,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Logout'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldLogout != true || !context.mounted) return;
    await ref.read(authControllerProvider.notifier).logout();
    ref.invalidate(profileSummaryProvider);
    if (!context.mounted) return;
    context.go('/login');
  }

  Future<void> _showPolicySheet(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _LargeIcon(icon: Icons.policy_outlined),
              const SizedBox(height: 16),
              Text(title, style: _TextStyles.sheetTitle),
              const SizedBox(height: 8),
              Text(message, style: _TextStyles.body),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _settingsErrorMessage(Object error) {
    if (error is ApiError && error.message.trim().isNotEmpty) {
      return error.message.trim();
    }
    return 'Settings preferences could not be loaded right now. Please try again.';
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero({this.accountName, this.accountStatus, this.approvalStatus});

  final String? accountName;
  final String? accountStatus;
  final String? approvalStatus;

  @override
  Widget build(BuildContext context) {
    final statusText = [accountStatus, approvalStatus]
        .where((value) => (value ?? '').trim().isNotEmpty)
        .join(' • ');
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const _LargeIcon(icon: Icons.tune_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Settings', style: _TextStyles.heroTitle),
                const SizedBox(height: 5),
                Text(
                  statusText.isEmpty
                      ? 'Manage your account, preferences and OMC service updates.'
                      : statusText,
                  style: _TextStyles.body,
                ),
                if ((accountName ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(accountName!, style: _TextStyles.badge),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection({
    required this.preferences,
    required this.errorMessage,
    required this.onRetry,
    required this.onToggle,
  });

  final SettingsPreferences preferences;
  final String? errorMessage;
  final VoidCallback onRetry;
  final ValueChanged<SettingsPreferences> onToggle;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'Notifications',
      subtitle: 'Choose which OMC updates you want to receive.',
      children: [
        if (errorMessage != null) ...[
          _InlineError(message: errorMessage!, onRetry: onRetry),
          const _DividerIndent(),
        ],
        _SwitchTile(
          title: 'Service updates',
          value: preferences.serviceUpdatesEnabled,
          onChanged: (value) => onToggle(preferences.copyWith(serviceUpdatesEnabled: value)),
        ),
        _SwitchTile(
          title: 'Document reminders',
          value: preferences.documentRemindersEnabled,
          onChanged: (value) => onToggle(preferences.copyWith(documentRemindersEnabled: value)),
        ),
        _SwitchTile(
          title: 'Payment alerts',
          value: preferences.paymentAlertsEnabled,
          onChanged: (value) => onToggle(preferences.copyWith(paymentAlertsEnabled: value)),
        ),
        _SwitchTile(
          title: 'Tax alerts',
          value: preferences.taxAlertsEnabled,
          onChanged: (value) => onToggle(preferences.copyWith(taxAlertsEnabled: value)),
        ),
        _SwitchTile(
          title: 'Email notifications',
          value: preferences.emailNotificationsEnabled,
          onChanged: (value) => onToggle(preferences.copyWith(emailNotificationsEnabled: value)),
        ),
        _SwitchTile(
          title: 'WhatsApp notifications',
          value: preferences.whatsAppNotificationsEnabled,
          onChanged: (value) => onToggle(preferences.copyWith(whatsAppNotificationsEnabled: value)),
        ),
      ],
    );
  }
}

class _PreferencesLoadingSection extends StatelessWidget {
  const _PreferencesLoadingSection();

  @override
  Widget build(BuildContext context) {
    return const PremiumCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.subtitle, required this.children});

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _TextStyles.sectionTitle),
                const SizedBox(height: 5),
                Text(subtitle, style: _TextStyles.body),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppTheme.primaryRed : AppTheme.textPrimary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: _SmallIcon(icon: icon, isDestructive: isDestructive),
      title: Text(title, style: _TextStyles.tileTitle.copyWith(color: color)),
      subtitle: Text(subtitle, style: _TextStyles.caption),
      trailing: Text(trailing, style: _TextStyles.trailing),
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.title, required this.value, required this.onChanged});

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      title: Text(title, style: _TextStyles.tileTitle),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primaryRed,
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
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
      child: PremiumCard(
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _SmallIcon(icon: Icons.support_agent_rounded),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: _TextStyles.sectionTitle)),
                ],
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
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(controller.text),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(submitLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
      child: Row(
        children: [
          const _SmallIcon(icon: Icons.cloud_off_outlined),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: _TextStyles.caption)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _SettingsFootnote extends StatelessWidget {
  const _SettingsFootnote();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'OMC keeps customer-facing settings clean. Debug and backend details are hidden from normal users.',
      textAlign: TextAlign.center,
      style: _TextStyles.caption,
    );
  }
}

class _DividerIndent extends StatelessWidget {
  const _DividerIndent();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 76, endIndent: 18);
  }
}

class _LargeIcon extends StatelessWidget {
  const _LargeIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.10)),
      ),
      child: Icon(icon, color: AppTheme.primaryRed, size: 30),
    );
  }
}

class _SmallIcon extends StatelessWidget {
  const _SmallIcon({required this.icon, this.isDestructive = false});

  final IconData icon;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: isDestructive ? 0.10 : 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: AppTheme.primaryRed),
    );
  }
}

class _TextStyles {
  static const heroTitle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 26,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.35,
  );

  static const sheetTitle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.2,
  );

  static const sectionTitle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w900,
  );

  static const tileTitle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w900,
  );

  static const body = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );

  static const caption = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  static const trailing = TextStyle(
    color: AppTheme.primaryRed,
    fontSize: 12,
    fontWeight: FontWeight.w900,
  );

  static const badge = TextStyle(
    color: AppTheme.primaryRed,
    fontSize: 12,
    fontWeight: FontWeight.w900,
  );
}
