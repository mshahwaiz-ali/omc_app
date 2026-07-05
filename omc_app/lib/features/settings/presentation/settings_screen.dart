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
              'App preferences, environment details and security information.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            PremiumCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: const [
                  _SettingsTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    subtitle: 'Service updates and document reminders',
                    trailing: 'Default',
                  ),
                  _DividerIndent(),
                  _SettingsTile(
                    icon: Icons.palette_outlined,
                    title: 'Appearance',
                    subtitle: 'Premium OMC theme',
                    trailing: 'System',
                  ),
                  _DividerIndent(),
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Security',
                    subtitle: 'Session is stored securely on device',
                    trailing: 'Enabled',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Backend',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            PremiumCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.cloud_outlined,
                    title: 'Environment',
                    subtitle: _environmentLabel,
                    trailing: Env.isProduction ? 'Live' : 'Dev',
                  ),
                  const _DividerIndent(),
                  _SettingsTile(
                    icon: Icons.link_rounded,
                    title: 'API Server',
                    subtitle: ApiConfig.baseUrl,
                    trailing: 'Frappe',
                  ),
                  const _DividerIndent(),
                  _SettingsTile(
                    icon: Icons.grid_view_outlined,
                    title: 'Service Catalogue',
                    subtitle: Env.useBackendServiceCatalogue
                        ? 'Backend catalogue enabled'
                        : 'Asset catalogue fallback enabled',
                    trailing: Env.useBackendServiceCatalogue ? 'API' : 'Local',
                  ),
                  const _DividerIndent(),
                  _SettingsTile(
                    icon: Icons.science_outlined,
                    title: 'Testing Flags',
                    subtitle: _testingFlagsLabel,
                    trailing: _hasTestingFlags ? 'On' : 'Off',
                  ),
                ],
              ),
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
                      Icons.info_outline_rounded,
                      color: AppTheme.primaryRed,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Editable preferences will be connected after the backend settings contract is confirmed.',
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
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
      trailing: Text(
        trailing,
        style: const TextStyle(
          color: AppTheme.primaryRed,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
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
