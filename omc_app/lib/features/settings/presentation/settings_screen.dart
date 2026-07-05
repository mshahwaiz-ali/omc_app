import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/env.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/settings_preferences.dart';
import '../data/settings_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(settingsPreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Account controls, preferences, environment details and security information.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Account',
              children: [
                _SettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Profile preferences',
                  subtitle: 'Manage customer profile settings',
                  trailing: 'Ready',
                  onTap: () => _showBackendPendingSnack(
                    context,
                    'Profile settings endpoint is not connected yet.',
                  ),
                ),
                const _DividerIndent(),
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Security',
                  subtitle: 'Password, session and device security',
                  trailing: 'Secure',
                  onTap: () => _showBackendPendingSnack(
                    context,
                    'Security settings endpoint is not connected yet.',
                  ),
                ),
                const _DividerIndent(),
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Session',
                  subtitle: 'Logout and active session controls',
                  trailing: 'Active',
                  onTap: () => _showBackendPendingSnack(
                    context,
                    'Session management action is not connected here yet.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            preferencesAsync.when(
              data: (preferences) => _PreferencesSection(
                preferences: preferences,
                errorMessage: null,
                onRetry: () => ref.invalidate(settingsPreferencesProvider),
                onToggle: (updatedPreferences) =>
                    _savePreferences(context, ref, updatedPreferences),
              ),
              loading: () => const _PreferencesLoadingSection(),
              error: (error, _) => _PreferencesSection(
                preferences: null,
                errorMessage: _settingsErrorMessage(error),
                onRetry: () => ref.invalidate(settingsPreferencesProvider),
                onToggle: (updatedPreferences) =>
                    _savePreferences(context, ref, updatedPreferences),
              ),
            ),
            const SizedBox(height: 18),
            _SettingsSection(
              title: 'Backend',
              children: [
                _SettingsTile(
                  icon: Icons.cloud_outlined,
                  title: 'Environment',
                  subtitle: _environmentLabel,
                  trailing: Env.isProduction ? 'Live' : 'Dev',
                  onTap: () => _showBackendPendingSnack(
                    context,
                    'Environment is configured at build time.',
                  ),
                ),
                const _DividerIndent(),
                _SettingsTile(
                  icon: Icons.link_rounded,
                  title: 'API Server',
                  subtitle: ApiConfig.baseUrl,
                  trailing: 'Frappe',
                  onTap: () => _showBackendPendingSnack(
                    context,
                    'API server is configured through ApiConfig.',
                  ),
                ),
                const _DividerIndent(),
                _SettingsTile(
                  icon: Icons.grid_view_outlined,
                  title: 'Service Catalogue',
                  subtitle: Env.useBackendServiceCatalogue
                      ? 'Backend catalogue enabled'
                      : 'Asset catalogue fallback enabled',
                  trailing: Env.useBackendServiceCatalogue ? 'API' : 'Local',
                  onTap: () => _showBackendPendingSnack(
                    context,
                    'Catalogue source is configured through environment flags.',
                  ),
                ),
                const _DividerIndent(),
                _SettingsTile(
                  icon: Icons.science_outlined,
                  title: 'Testing Flags',
                  subtitle: _testingFlagsLabel,
                  trailing: _hasTestingFlags ? 'On' : 'Off',
                  onTap: () => _showBackendPendingSnack(
                    context,
                    'Testing flags are configured at build time.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SettingsSection(
              title: 'About',
              children: [
                _SettingsTile(
                  icon: Icons.phone_iphone_rounded,
                  title: 'OMC Mobile App',
                  subtitle: 'Premium customer service app',
                  trailing: 'Flutter',
                  onTap: () => _showBackendPendingSnack(
                    context,
                    'App version display will be connected with package info later.',
                  ),
                ),
                const _DividerIndent(),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Backend contract',
                  subtitle:
                      'Editable preferences are backend-ready placeholders',
                  trailing: 'Pending',
                  onTap: () => _showBackendPendingSnack(
                    context,
                    'Settings API contract is pending backend confirmation.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            PremiumCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      color: AppTheme.primaryRed,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Settings actions are backend-ready. Editable preferences will activate after the OMC settings contract is confirmed.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
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
    final repository = ref.read(settingsRepositoryProvider);

    try {
      await repository.savePreferences(preferences);

      if (!context.mounted) return;

      ref.invalidate(settingsPreferencesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings preferences updated.')),
      );
    } on ApiError catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update settings preferences yet.'),
        ),
      );
    }
  }

  static String get _environmentLabel {
    switch (Env.current) {
      case AppEnvironment.development:
        return 'Development';
      case AppEnvironment.staging:
        return 'Staging';
      case AppEnvironment.production:
        return 'Production';
    }
  }

  static bool get _hasTestingFlags => Env.useMockAuth || Env.useServicePreview;

  static String get _testingFlagsLabel {
    final enabled = <String>[
      if (Env.useMockAuth) 'Mock auth',
      if (Env.useServicePreview) 'Service preview',
    ];

    if (enabled.isEmpty) return 'No local testing flags enabled';
    return enabled.join(', ');
  }

  String _settingsErrorMessage(Object error) {
    if (error is ApiError && error.message.trim().isNotEmpty) {
      return error.message.trim();
    }

    return 'Settings preferences could not be loaded from the backend right now.';
  }

  void _showBackendPendingSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection({
    required this.preferences,
    required this.errorMessage,
    required this.onRetry,
    required this.onToggle,
  });

  final SettingsPreferences? preferences;
  final String? errorMessage;
  final VoidCallback onRetry;
  final ValueChanged<SettingsPreferences> onToggle;

  @override
  Widget build(BuildContext context) {
    final activePreferences = preferences ?? const SettingsPreferences();
    final isBackendAvailable = preferences != null;

    return _SettingsSection(
      title: 'Preferences',
      children: [
        _SettingsSwitchTile(
          icon: Icons.notifications_none_rounded,
          title: 'Service updates',
          subtitle: isBackendAvailable
              ? 'Notify me about service request progress'
              : errorMessage ??
                    'Backend preferences unavailable; showing safe defaults',
          value: activePreferences.serviceUpdatesEnabled,
          onChanged: isBackendAvailable
              ? (value) => onToggle(
                  activePreferences.copyWith(serviceUpdatesEnabled: value),
                )
              : null,
        ),
        const _DividerIndent(),
        _SettingsSwitchTile(
          icon: Icons.folder_copy_outlined,
          title: 'Document reminders',
          subtitle: 'Missing document and upload reminders',
          value: activePreferences.documentRemindersEnabled,
          onChanged: isBackendAvailable
              ? (value) => onToggle(
                  activePreferences.copyWith(documentRemindersEnabled: value),
                )
              : null,
        ),
        const _DividerIndent(),
        _SettingsSwitchTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Payment alerts',
          subtitle: 'Invoices, receipts and payment status updates',
          value: activePreferences.paymentAlertsEnabled,
          onChanged: isBackendAvailable
              ? (value) => onToggle(
                  activePreferences.copyWith(paymentAlertsEnabled: value),
                )
              : null,
        ),
        const _DividerIndent(),
        _SettingsSwitchTile(
          icon: Icons.calculate_outlined,
          title: 'Tax alerts',
          subtitle: 'Tax reminders, filing alerts and compliance updates',
          value: activePreferences.taxAlertsEnabled,
          onChanged: isBackendAvailable
              ? (value) => onToggle(
                  activePreferences.copyWith(taxAlertsEnabled: value),
                )
              : null,
        ),
        const _DividerIndent(),
        _SettingsSwitchTile(
          icon: Icons.email_outlined,
          title: 'Email notifications',
          subtitle: 'Send important updates by email',
          value: activePreferences.emailNotificationsEnabled,
          onChanged: isBackendAvailable
              ? (value) => onToggle(
                  activePreferences.copyWith(emailNotificationsEnabled: value),
                )
              : null,
        ),
        const _DividerIndent(),
        _SettingsSwitchTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'WhatsApp notifications',
          subtitle: 'Allow WhatsApp support and update messages',
          value: activePreferences.whatsAppNotificationsEnabled,
          onChanged: isBackendAvailable
              ? (value) => onToggle(
                  activePreferences.copyWith(
                    whatsAppNotificationsEnabled: value,
                  ),
                )
              : null,
        ),
        if (!isBackendAvailable) ...[
          const _DividerIndent(),
          _SettingsTile(
            icon: Icons.refresh_rounded,
            title: 'Retry preferences',
            subtitle: errorMessage ?? 'Load editable settings from backend',
            trailing: 'Retry',
            onTap: onRetry,
          ),
        ],
      ],
    );
  }
}

class _PreferencesLoadingSection extends StatelessWidget {
  const _PreferencesLoadingSection();

  @override
  Widget build(BuildContext context) {
    return const _SettingsSection(
      title: 'Preferences',
      children: [
        Padding(padding: EdgeInsets.all(18), child: SizedBox(height: 136)),
      ],
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onChanged != null;

    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      secondary: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: isEnabled ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(
          icon,
          color: isEnabled ? AppTheme.primaryRed : AppTheme.textSecondary,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: AppTheme.primaryRed),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text(
            trailing,
            style: const TextStyle(
              color: AppTheme.primaryRed,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _DividerIndent extends StatelessWidget {
  const _DividerIndent();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 76);
  }
}
