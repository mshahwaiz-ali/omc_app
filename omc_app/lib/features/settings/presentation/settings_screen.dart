import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../auth/application/auth_controller.dart';
import '../../support/data/support_repository.dart';
import '../data/settings_preferences.dart';
import '../data/settings_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(settingsPreferencesProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const _SettingsHero(),
            const SizedBox(height: 22),
            _SettingsSection(
              title: 'Account',
              subtitle: 'Manage your profile, security and active app session.',
              children: [
                _SettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Profile preferences',
                  subtitle: 'Customer identity and account details',
                  trailing: 'Ready',
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
                    hint:
                        'Example: I want to change my password or secure my account.',
                    submitLabel: 'Submit security request',
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
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'About',
              subtitle: 'App readiness, sync behaviour and product details.',
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
                  icon: Icons.sync_rounded,
                  title: 'Account sync',
                  subtitle: 'Preferences sync with backend account controls',
                  trailing: 'Ready',
                  onTap: () => _showBackendPendingSnack(
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
      builder: (sheetContext) {
        return _AccountRequestSheet(
          title: title,
          label: label,
          hint: hint,
          submitLabel: submitLabel,
          controller: controller,
        );
      },
    );

    controller.dispose();

    final cleanMessage = message?.trim();
    if (cleanMessage == null || cleanMessage.isEmpty) return;

    try {
      await ref
          .read(supportRepositoryProvider)
          .createSupportTicket(topic: topic, message: cleanMessage);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title submitted to OMC support.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_settingsErrorMessage(error))));
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
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(
                      color: AppTheme.primaryRed.withValues(alpha: 0.10),
                    ),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppTheme.primaryRed,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Logout from OMC?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your secure session will be cleared on this device. You can login again anytime.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
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
        );
      },
    );

    if (shouldLogout != true || !context.mounted) return;

    await ref.read(authControllerProvider.notifier).logout();

    if (!context.mounted) return;

    context.go('/login');
  }

  String _settingsErrorMessage(Object error) {
    if (error is ApiError && error.message.trim().isNotEmpty) {
      return error.message.trim();
    }

    return 'Settings preferences could not be loaded right now. Please try again.';
  }

  void _showBackendPendingSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppTheme.primaryRed.withValues(alpha: 0.10),
                  ),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppTheme.primaryRed,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Manage your account, preferences and OMC service updates.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              const PremiumInfoChip(
                icon: Icons.person_pin_circle_outlined,
                label: 'Account active',
              ),
              const PremiumInfoChip(
                icon: Icons.verified_user_outlined,
                label: 'Protected account',
              ),
              const PremiumInfoChip(
                icon: Icons.business_center_outlined,
                label: 'OMC services',
              ),
            ],
          ),
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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: AppTheme.primaryRed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
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
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.length < 10) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter at least 10 characters.'),
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).pop(text);
                  },
                  icon: const Icon(Icons.send_rounded),
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
      subtitle: isBackendAvailable
          ? 'Control service, document, payment and support notifications.'
          : 'Using safe defaults until backend preferences are available.',
      children: [
        _SettingsSwitchTile(
          icon: Icons.notifications_none_rounded,
          title: 'Service updates',
          subtitle: isBackendAvailable
              ? 'Notify me about service request progress'
              : errorMessage ??
                    'Using safe defaults until preferences sync is available',
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
            subtitle: errorMessage ?? 'Load account preferences',
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
      subtitle: 'Loading account notification controls.',
      children: [
        _LoadingPreferenceTile(),
        _DividerIndent(),
        _LoadingPreferenceTile(),
        _DividerIndent(),
        _LoadingPreferenceTile(),
      ],
    );
  }
}

class _LoadingPreferenceTile extends StatelessWidget {
  const _LoadingPreferenceTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryRed.withValues(alpha: 0.06),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LoadingBar(widthFactor: 0.44),
                const SizedBox(height: 9),
                _LoadingBar(widthFactor: 0.76),
                const SizedBox(height: 8),
                _LoadingBar(widthFactor: 0.58),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 44,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppTheme.primaryRed.withValues(alpha: 0.06),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 9,
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          _SettingsIcon(icon: icon, isEnabled: isEnabled),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isEnabled
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.15,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
    final accentColor = isDestructive
        ? Colors.red.shade700
        : AppTheme.primaryRed;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            _SettingsIcon(
              icon: icon,
              color: accentColor,
              backgroundAlpha: isDestructive ? 0.08 : 0.08,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              trailing,
              style: TextStyle(
                color: accentColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({
    required this.icon,
    this.isEnabled = true,
    this.color,
    this.backgroundAlpha = 0.08,
  });

  final IconData icon;
  final bool isEnabled;
  final Color? color;
  final double backgroundAlpha;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        color ?? (isEnabled ? AppTheme.primaryRed : AppTheme.textSecondary);

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: backgroundAlpha)),
      ),
      child: Icon(icon, color: iconColor, size: 21),
    );
  }
}

class _SettingsFootnote extends StatelessWidget {
  const _SettingsFootnote();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryRed.withValues(alpha: 0.08),
              ),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: AppTheme.primaryRed,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Settings are connected to backend account preferences where available. Safe defaults keep the app stable when sync is unavailable.',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
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
