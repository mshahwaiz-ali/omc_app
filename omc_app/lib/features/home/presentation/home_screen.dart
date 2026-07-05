import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../data/home_dashboard_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    this.onOpenServices,
    this.onOpenCalculator,
    this.onOpenSupport,
    this.onOpenNotifications,
  });

  final VoidCallback? onOpenServices;
  final VoidCallback? onOpenCalculator;
  final VoidCallback? onOpenSupport;
  final VoidCallback? onOpenNotifications;

  static const List<_HomeAction> _quickServices = [
    _HomeAction(
      title: 'File Tax Return',
      subtitle: 'Start your tax filing request',
      icon: Icons.receipt_long_rounded,
      target: _HomeActionTarget.services,
    ),
    _HomeAction(
      title: 'NTN Registration',
      subtitle: 'Register NTN with documents',
      icon: Icons.badge_rounded,
      target: _HomeActionTarget.services,
    ),
    _HomeAction(
      title: 'GST Registration',
      subtitle: 'Business sales tax setup',
      icon: Icons.storefront_rounded,
      target: _HomeActionTarget.services,
    ),
    _HomeAction(
      title: 'Tax Calculator',
      subtitle: 'Estimate payable tax',
      icon: Icons.calculate_rounded,
      target: _HomeActionTarget.calculator,
    ),
  ];

  static const List<_WorkspaceAction> _workspaceActions = [
    _WorkspaceAction(
      title: 'My Services',
      subtitle: 'Cases and request status',
      icon: Icons.assignment_outlined,
      target: _HomeActionTarget.myServices,
    ),
    _WorkspaceAction(
      title: 'Documents',
      subtitle: 'CNIC, proofs and files',
      icon: Icons.folder_copy_outlined,
      target: _HomeActionTarget.services,
    ),
    _WorkspaceAction(
      title: 'Payments',
      subtitle: 'Invoices and receipts',
      icon: Icons.account_balance_wallet_outlined,
      target: _HomeActionTarget.services,
    ),
    _WorkspaceAction(
      title: 'Support',
      subtitle: 'Help from OMC team',
      icon: Icons.support_agent_rounded,
      target: _HomeActionTarget.support,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final dashboardSummary = ref.watch(homeDashboardSummaryProvider);
    final displayName = _displayNameFromUserId(authState.userId);
    final statusItems = dashboardSummary.maybeWhen(
      data: _statusItemsFromSummary,
      orElse: () => _statusItemsFromSummary(const HomeDashboardSummary.empty()),
    );

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _HomeHeader(
                  displayName: displayName,
                  onOpenNotifications: onOpenNotifications,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _HeroCard(onStartRequest: onOpenServices),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    for (final item in statusItems) ...[
                      Expanded(child: _StatusCard(item: item)),
                      if (item != statusItems.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Quick Services',
                  actionText: 'View all',
                  onAction: onOpenServices,
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
                  childAspectRatio: 0.92,
                ),
                itemBuilder: (context, index) {
                  final action = _quickServices[index];
                  return _ServiceCard(
                    action: action,
                    onTap: () => _handleAction(context, action.target),
                  );
                },
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(title: 'Workspace'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverGrid.builder(
                itemCount: _workspaceActions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.18,
                ),
                itemBuilder: (context, index) {
                  final action = _workspaceActions[index];
                  return _WorkspaceCard(
                    action: action,
                    onTap: () => _handleAction(context, action.target),
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Recent Activity',
                  actionText: 'Track',
                  onAction: () => context.go('/my-services'),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverToBoxAdapter(
                child: _RecentActivityCard(
                  onTrack: () => context.go('/my-services'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_StatusItem> _statusItemsFromSummary(HomeDashboardSummary summary) {
    return [
      _StatusItem(label: 'Active Cases', value: summary.activeCases.toString()),
      _StatusItem(label: 'Completed', value: summary.completedCases.toString()),
      _StatusItem(
        label: 'Pending Docs',
        value: summary.pendingDocuments.toString(),
      ),
    ];
  }

  void _handleAction(BuildContext context, _HomeActionTarget target) {
    switch (target) {
      case _HomeActionTarget.myServices:
        context.go('/my-services');
        return;
      case _HomeActionTarget.services:
        onOpenServices?.call();
        return;
      case _HomeActionTarget.calculator:
        onOpenCalculator?.call();
        return;
      case _HomeActionTarget.support:
        onOpenSupport?.call();
        return;
    }
  }

  String _displayNameFromUserId(String? userId) {
    final value = userId?.trim();
    if (value == null || value.isEmpty) return 'OMC Customer';

    final localPart = value.split('@').first;
    final cleaned = localPart.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (cleaned.isEmpty) return value;

    return cleaned
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.displayName,
    required this.onOpenNotifications,
  });

  final String displayName;
  final VoidCallback? onOpenNotifications;

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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        IconButton.filled(
          tooltip: 'Notifications',
          onPressed: onOpenNotifications,
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
  const _HeroCard({required this.onStartRequest});

  final VoidCallback? onStartRequest;

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
                onPressed: onStartRequest,
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
  const _SectionHeader({required this.title, this.actionText, this.onAction});

  final String title;
  final String? actionText;
  final VoidCallback? onAction;

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
        if (actionText != null)
          TextButton(onPressed: onAction, child: Text(actionText!)),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.action, required this.onTap});

  final _HomeAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      onTap: onTap,
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

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({required this.action, required this.onTap});

  final _WorkspaceAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(action.icon, color: AppTheme.primaryRed, size: 28),
          const Spacer(),
          Text(
            action.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            action.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.onTrack});

  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      onTap: onTrack,
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
                  'Submitted requests and status updates stay here.',
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
          const SizedBox(width: 10),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}

enum _HomeActionTarget { myServices, services, calculator, support }

class _HomeAction {
  const _HomeAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.target,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final _HomeActionTarget target;
}

class _WorkspaceAction {
  const _WorkspaceAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.target,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final _HomeActionTarget target;
}

class _StatusItem {
  const _StatusItem({required this.label, required this.value});

  final String label;
  final String value;
}
