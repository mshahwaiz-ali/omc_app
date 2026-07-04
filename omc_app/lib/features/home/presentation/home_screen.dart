import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/premium_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<_HomeAction> _quickServices = [
    _HomeAction(
      title: 'File Tax Return',
      subtitle: 'Start your tax filing request',
      icon: Icons.receipt_long_rounded,
    ),
    _HomeAction(
      title: 'NTN Registration',
      subtitle: 'Register NTN with documents',
      icon: Icons.badge_rounded,
    ),
    _HomeAction(
      title: 'GST Registration',
      subtitle: 'Business sales tax setup',
      icon: Icons.storefront_rounded,
    ),
    _HomeAction(
      title: 'Tax Calculator',
      subtitle: 'Estimate payable tax',
      icon: Icons.calculate_rounded,
    ),
  ];

  static const List<_StatusItem> _statusItems = [
    _StatusItem(label: 'Active Cases', value: '03'),
    _StatusItem(label: 'Completed', value: '12'),
    _StatusItem(label: 'Pending Docs', value: '02'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverToBoxAdapter(child: _HomeHeader()),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 0),
              sliver: SliverToBoxAdapter(child: _HeroCard()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    for (final item in _statusItems) ...[
                      Expanded(child: _StatusCard(item: item)),
                      if (item != _statusItems.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Quick Services',
                  actionText: 'View all',
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverGrid.builder(
                itemCount: _quickServices.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.9,
                ),
                itemBuilder: (context, index) {
                  return _ServiceCard(action: _quickServices[index]);
                },
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Recent Activity',
                  actionText: 'Track',
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverToBoxAdapter(child: _RecentActivityCard()),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primaryRed,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: const Text(
            'OMC',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Muhammad Shahwaiz',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        IconButton.filled(
          onPressed: () {},
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primaryRed,
          ),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryRed, AppTheme.darkRed],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 34,
            ),
            const SizedBox(height: 18),
            const Text(
              'Tax, compliance and business services in one premium app.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                height: 1.15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Submit requests, upload documents, track progress and get expert support.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryRed,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Start a Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.item});

  final _StatusItem item;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        height: 64,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Text(
              item.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.actionText});

  final String title;
  final String actionText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(onPressed: () {}, child: Text(actionText)),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.action});

  final _HomeAction action;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(action.icon, color: AppTheme.primaryRed, size: 25),
          ),
          const Spacer(),
          Text(
            action.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            action.subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

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
            ),
            child: const Icon(
              Icons.timeline_rounded,
              color: AppTheme.primaryRed,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No live case activity yet',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Your submitted requests and status updates will appear here.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAction {
  const _HomeAction({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class _StatusItem {
  const _StatusItem({required this.label, required this.value});

  final String label;
  final String value;
}
