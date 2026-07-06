import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/premium_card.dart';
import '../../home/data/home_dashboard_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(homeDashboardSummaryProvider);

    return Scaffold(
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeDashboardSummaryProvider);
            await ref.read(homeDashboardSummaryProvider.future);
          },
          child: summaryAsync.when(
            loading: () => const _DashboardLoadingView(),
            error: (_, _) => const _DashboardBody(
              summary: HomeDashboardSummary.empty(
                fallbackMessage: 'Dashboard data could not be loaded.',
              ),
            ),
            data: (summary) => _DashboardBody(summary: summary),
          ),
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _DashboardHero(totalItems: totalItems),
        const SizedBox(height: 20),
        _MetricGrid(summary: summary),
        const SizedBox(height: 20),
        _StatusBreakdownCard(summary: summary),
        if (summary.recentActivity.isNotEmpty) ...[
          const SizedBox(height: 20),
          _RecentActivityBreakdownCard(activities: summary.recentActivity),
        ],
        if (summary.fallbackMessage != null) ...[
          const SizedBox(height: 20),
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
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryRed.withValues(alpha: 0.20),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.analytics_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Live overview of your OMC workspace.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
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
                _HeroPill(
                  icon: Icons.bolt_rounded,
                  label: '$totalItems live items',
                ),
                const _HeroPill(
                  icon: Icons.cloud_done_outlined,
                  label: 'Backend synced',
                ),
                const _HeroPill(
                  icon: Icons.shield_outlined,
                  label: 'Secure account',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary});

  final HomeDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Open services',
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
                title: 'Payments due',
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
      ],
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
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 126),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 29,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
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
      _StatusRowData(
        label: 'Open services',
        value: summary.activeCases,
        icon: Icons.pending_actions_rounded,
      ),
      _StatusRowData(
        label: 'Documents',
        value: summary.pendingDocuments,
        icon: Icons.folder_copy_outlined,
      ),
      _StatusRowData(
        label: 'Payments due',
        value: summary.paymentsDue,
        icon: Icons.account_balance_wallet_outlined,
      ),
      _StatusRowData(
        label: 'Notifications',
        value: summary.unreadNotifications,
        icon: Icons.notifications_none_rounded,
      ),
    ];

    final maxValue = rows
        .map((row) => row.value)
        .fold<int>(0, (previous, value) => value > previous ? value : previous);

    return _DashboardSection(
      title: 'Status breakdown',
      subtitle: 'Current items grouped by service area.',
      child: Column(
        children: [
          for (final row in rows) ...[
            _StatusBreakdownRow(data: row, maxValue: maxValue),
            if (row != rows.last) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _StatusBreakdownRow extends StatelessWidget {
  const _StatusBreakdownRow({required this.data, required this.maxValue});

  final _StatusRowData data;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final progress = maxValue == 0 ? 0.0 : data.value / maxValue;

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.primaryRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(data.icon, color: AppTheme.primaryRed, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.label,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    data.value.toString(),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.07),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusRowData {
  const _StatusRowData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;
}

class _RecentActivityBreakdownCard extends StatelessWidget {
  const _RecentActivityBreakdownCard({required this.activities});

  final List<HomeDashboardActivity> activities;

  @override
  Widget build(BuildContext context) {
    final visibleActivities = activities.take(4).toList(growable: false);

    return _DashboardSection(
      title: 'Recent activity',
      subtitle: 'Latest updates from services, documents and payments.',
      child: Column(
        children: [
          for (final activity in visibleActivities) ...[
            _ActivityRow(activity: activity),
            if (activity != visibleActivities.last) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final HomeDashboardActivity activity;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.primaryRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.timeline_rounded,
            color: AppTheme.primaryRed,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (activity.subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
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
                const SizedBox(height: 5),
                Text(
                  activity.createdAtLabel!,
                  style: const TextStyle(
                    color: AppTheme.primaryRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
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
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoadingView extends StatelessWidget {
  const _DashboardLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: const [
        PremiumCard(
          padding: EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LoadingBox(width: 58, height: 58, radius: 22),
              SizedBox(height: 18),
              _LoadingBar(widthFactor: 0.58, height: 18),
              SizedBox(height: 10),
              _LoadingBar(widthFactor: 0.84),
              SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _LoadingPill(width: 92),
                  _LoadingPill(width: 116),
                  _LoadingPill(width: 108),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _LoadingMetricCard()),
            SizedBox(width: 12),
            Expanded(child: _LoadingMetricCard()),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _LoadingMetricCard()),
            SizedBox(width: 12),
            Expanded(child: _LoadingMetricCard()),
          ],
        ),
      ],
    );
  }
}

class _LoadingMetricCard extends StatelessWidget {
  const _LoadingMetricCard();

  @override
  Widget build(BuildContext context) {
    return const PremiumCard(
      padding: EdgeInsets.all(16),
      child: SizedBox(
        height: 94,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LoadingBox(width: 42, height: 42, radius: 15),
            Spacer(),
            _LoadingBar(widthFactor: 0.38, height: 18),
            SizedBox(height: 8),
            _LoadingBar(widthFactor: 0.72),
          ],
        ),
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 30,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.widthFactor, this.height = 9});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
