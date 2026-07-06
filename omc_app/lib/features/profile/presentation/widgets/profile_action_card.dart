import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/premium_card.dart';

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
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account actions',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Request profile updates, refresh customer data, or contact OMC support.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _ProfileActionTile(
            icon: Icons.edit_outlined,
            title: 'Edit profile',
            subtitle: 'Submit updated customer profile details',
            onTap: onEditProfile,
          ),
          const SizedBox(height: 10),
          _ProfileActionTile(
            icon: Icons.phone_iphone_outlined,
            title: 'Update contact info',
            subtitle: 'Request phone or email verification changes',
            onTap: onUpdateContact,
          ),
          const SizedBox(height: 10),
          _ProfileActionTile(
            icon: Icons.support_agent_rounded,
            title: 'Contact OMC support',
            subtitle: 'Get help with profile or account issues',
            onTap: onContactSupport,
          ),
          const SizedBox(height: 10),
          _ProfileActionTile(
            icon: Icons.refresh_rounded,
            title: 'Refresh account data',
            subtitle: 'Reload latest profile information',
            onTap: onRefresh,
          ),
        ],
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
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: outlineColor.withValues(alpha: 0.70)),
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
