import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/env.dart';
import '../../../core/widgets/premium_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            _SettingsSection(
              title: 'Preferences',
              children: [
                _SettingsTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle: 'Service updates and document reminders',
                  trailing: 'Default',
                  onTap: () => _showBackendPendingSnack(
                    context,
                    'Notification preferences endpoint is not connected yet.',
                  ),
                ),
                const _DividerIndent(),
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: 'Premium OMC theme',
                  trailing: 'System',
                  onTap: () => _showBackendPendingSnack(
                    context,
                    'Appearance settings are fixed to the premium OMC theme for now.',
                  ),
                ),
                const _DividerIndent(),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy & data',
                  subtitle: 'Data export, consent and account privacy',
                  trailing: 'Ready',
                  onTap: () => _showBackendPendingSnack(
                    context,
                    'Privacy and data endpoint is not connected yet.',
                  ),
                ),
              ],
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

  void _showBackendPendingSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
