import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/premium_card.dart';
import '../../home/data/home_dashboard_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(homeDashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(
        top: false,
        child: summaryAsync.when(
          loading: () => const LoadingView(message: 'Loading dashboard...'),
          error: (_, _) => const _DashboardBody(
            summary: HomeDashboardSummary.empty(
              fallbackMessage: 'Dashboard data could not be loaded.',
            ),
          ),
          data: (summary) => _DashboardBody(summary: summary),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.summary});

  final HomeDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final totalItems =
        summary.activeCases +
        summary.pendingDocuments +
        summary.paymentsDue +
        summary.unreadNotifications;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _DashboardHero(totalItems: totalItems),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Open Services',
                value: summary.activeCases.toString(),
                icon: Icons.pending_actions_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Documents',
                value: summary.pendingDocuments.toString(),
                icon: Icons.folder_copy_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Payments Due',
                value: summary.paymentsDue.toString(),
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Notifications',
                value: summary.unreadNotifications.toString(),
                icon: Icons.notifications_none_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _StatusBreakdownCard(summary: summary),
        if (summary.recentActivity.isNotEmpty) ...[
          const SizedBox(height: 16),
          _RecentActivityBreakdownCard(activities: summary.recentActivity),
        ],
        if (summary.fallbackMessage != null) ...[
          const SizedBox(height: 16),
          _FallbackCard(message: summary.fallbackMessage!),
        ],
      ],
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({required this.totalItems});

  final int totalItems;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryRed, AppTheme.darkRed],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.analytics_outlined, color: Colors.white, size: 30),
            const SizedBox(height: 14),
            const Text(
              'Analytics Overview',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$totalItems live item(s) across your OMC workspace',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryRed),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBreakdownCard extends StatelessWidget {
  const _StatusBreakdownCard({required this.summary});

  final HomeDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Open services', summary.activeCases),
      ('Documents', summary.pendingDocuments),
      ('Payments due', summary.paymentsDue),
      ('Notifications', summary.unreadNotifications),
    ];

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status breakdown',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.$1,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    row.$2.toString(),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
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


class _RecentActivityBreakdownCard extends StatelessWidget {
  const _RecentActivityBreakdownCard({required this.activities});

  final List<HomeDashboardActivity> activities;

  @override
  Widget build(BuildContext context) {
    final visibleActivities = activities.take(4).toList(growable: false);

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent activity',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (final activity in visibleActivities)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.timeline_rounded,
                    color: AppTheme.primaryRed,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (activity.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            activity.subtitle,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (activity.createdAtLabel != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            activity.createdAtLabel!,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
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


class _FallbackCard extends StatelessWidget {
  const _FallbackCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Text(
        message,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }
}
