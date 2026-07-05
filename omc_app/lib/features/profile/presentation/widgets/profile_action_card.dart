import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

class ProfileActionCard extends StatelessWidget {
  const ProfileActionCard({
    required this.onEditProfile,
    required this.onUpdateContact,
    required this.onContactSupport,
    required this.onRefresh,
    super.key,
  });

  final VoidCallback onEditProfile;
  final VoidCallback onUpdateContact;
  final VoidCallback onContactSupport;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account Actions',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Profile edit, contact update, and support actions are prepared for backend endpoints.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _ProfileActionTile(
              icon: Icons.edit_outlined,
              title: 'Edit profile',
              subtitle: 'Update customer profile details.',
              onTap: onEditProfile,
            ),
            const SizedBox(height: 10),
            _ProfileActionTile(
              icon: Icons.phone_iphone_outlined,
              title: 'Update contact info',
              subtitle: 'Change phone or email after verification.',
              onTap: onUpdateContact,
            ),
            const SizedBox(height: 10),
            _ProfileActionTile(
              icon: Icons.support_agent_rounded,
              title: 'Contact OMC support',
              subtitle: 'Request profile or account assistance.',
              onTap: onContactSupport,
            ),
            const SizedBox(height: 10),
            _ProfileActionTile(
              icon: Icons.refresh_rounded,
              title: 'Refresh account data',
              subtitle: 'Reload latest profile information.',
              onTap: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outlineColor = Theme.of(context).colorScheme.outlineVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: outlineColor),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: AppTheme.primaryRed),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
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
