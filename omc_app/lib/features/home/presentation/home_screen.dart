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

  static const List<_HomeAction> _quickActions = [
    _HomeAction(
      title: 'File Tax',
      subtitle: 'Return',
      icon: Icons.receipt_long_rounded,
      target: _HomeActionTarget.services,
    ),
    _HomeAction(
      title: 'NTN',
      subtitle: 'Register',
      icon: Icons.badge_rounded,
      target: _HomeActionTarget.services,
    ),
    _HomeAction(
      title: 'GST',
      subtitle: 'Setup',
      icon: Icons.storefront_rounded,
      target: _HomeActionTarget.services,
    ),
    _HomeAction(
      title: 'Documents',
      subtitle: 'Upload',
      icon: Icons.upload_file_rounded,
      target: _HomeActionTarget.documents,
    ),
    _HomeAction(
      title: 'Track',
      subtitle: 'Requests',
      icon: Icons.timeline_rounded,
      target: _HomeActionTarget.myServices,
    ),
    _HomeAction(
      title: 'Calculator',
      subtitle: 'Tax',
      icon: Icons.calculate_rounded,
      target: _HomeActionTarget.calculator,
    ),
  ];

  static const List<_WorkspaceAction> _workspaceActions = [
    _WorkspaceAction(
      title: 'My Services',
      subtitle: 'Track active cases and request status',
      icon: Icons.assignment_outlined,
      target: _HomeActionTarget.myServices,
    ),
    _WorkspaceAction(
      title: 'Payments',
      subtitle: 'Review invoices and pending dues',
      icon: Icons.account_balance_wallet_outlined,
      target: _HomeActionTarget.payments,
    ),
    _WorkspaceAction(
      title: 'Knowledge',
      subtitle: 'Guides, updates and tax information',
      icon: Icons.menu_book_outlined,
      target: _HomeActionTarget.knowledge,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final dashboardSummary = ref.watch(homeDashboardSummaryProvider);
    final displayName = _displayNameFromUserId(authState.userId);
    final summary = dashboardSummary.maybeWhen(
      data: (summary) => summary,
      orElse: () => const HomeDashboardSummary.empty(
        fallbackMessage: 'Dashboard summary is loading right now.',
      ),
    );

    final statusItems = _statusItemsFromSummary(summary);

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
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _HeroCard(
                  activeCases: summary.activeCases,
                  onStartRequest: onOpenServices,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 0, 0),
              sliver: SliverToBoxAdapter(
                child: _StatusScroller(items: statusItems),
              ),
            ),
            if (summary.fallbackMessage != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _DashboardFallbackNote(
                    message: summary.fallbackMessage!,
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Quick Actions',
                  actionText: 'View all',
                  onAction: onOpenServices,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              sliver: SliverToBoxAdapter(
                child: _QuickActionLauncher(
                  actions: _quickActions,
                  onTap: (target) => _handleAction(context, target),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  title: summary.activeCases > 0
                      ? 'Current Progress'
                      : 'Start with OMC',
                  actionText: summary.activeCases > 0 ? 'Track' : null,
                  onAction: summary.activeCases > 0
                      ? () => context.go('/my-services')
                      : null,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              sliver: SliverToBoxAdapter(
                child: _ProgressCard(
                  summary: summary,
                  onStartRequest: onOpenServices,
                  onTrack: () => context.go('/my-services'),
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(title: 'Workspace'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              sliver: SliverToBoxAdapter(
                child: _WorkspaceList(
                  actions: _workspaceActions,
                  onTap: (target) => _handleAction(context, target),
                ),
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
              sliver: SliverToBoxAdapter(
                child: _RecentActivityCard(
                  activities: summary.recentActivity,
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
      _StatusItem(
        label: 'Active Services',
        value: summary.activeCases.toString(),
        icon: Icons.assignment_turned_in_rounded,
      ),
      _StatusItem(
        label: 'Docs Needed',
        value: summary.pendingDocuments.toString(),
        icon: Icons.folder_copy_rounded,
      ),
      _StatusItem(
        label: 'Payments Due',
        value: summary.paymentsDue.toString(),
        icon: Icons.account_balance_wallet_rounded,
      ),
      _StatusItem(
        label: 'Alerts',
        value: summary.unreadNotifications.toString(),
        icon: Icons.notifications_active_rounded,
      ),
    ];
  }

  void _handleAction(BuildContext context, _HomeActionTarget target) {
    switch (target) {
      case _HomeActionTarget.dashboard:
        context.go('/dashboard');
        return;
      case _HomeActionTarget.myServices:
        context.go('/my-services');
        return;
      case _HomeActionTarget.services:
        onOpenServices?.call();
        return;
      case _HomeActionTarget.documents:
        context.go('/documents');
        return;
      case _HomeActionTarget.payments:
        context.go('/payments');
        return;
      case _HomeActionTarget.calculator:
        onOpenCalculator?.call();
        return;
      case _HomeActionTarget.support:
        onOpenSupport?.call();
        return;
      case _HomeActionTarget.knowledge:
        context.go('/knowledge');
        return;
      case _HomeActionTarget.expenseTracker:
        context.go('/expense-tracker');
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
          width: 52,
          height: 52,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo_symbol_transparent.png',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.business_rounded, color: AppTheme.primaryRed),
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
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
        _RoundIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          onTap: onOpenNotifications,
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.activeCases, required this.onStartRequest});

  final int activeCases;
  final VoidCallback? onStartRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryRed.withValues(alpha: 0.24),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryRed,
                Color(0xFFA3162A),
                AppTheme.darkRed,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -34,
                top: -44,
                child: Opacity(
                  opacity: 0.10,
                  child: Image.asset(
                    'assets/images/logo_symbol_transparent.png',
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HeroBadge(),
                  const SizedBox(height: 20),
                  const Text(
                    'Your tax and business services, organized.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      height: 1.06,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Submit requests, upload documents and track every update from one place.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: onStartRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryRed,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Start Request'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _HeroMiniStat(activeCases: activeCases),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: Colors.white, size: 16),
          SizedBox(width: 7),
          Text(
            'OMC Premium Workspace',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMiniStat extends StatelessWidget {
  const _HeroMiniStat({required this.activeCases});

  final int activeCases;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            const Icon(Icons.timeline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$activeCases active',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusScroller extends StatelessWidget {
  const _StatusScroller({required this.items});

  final List<_StatusItem> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(right: 20),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _StatusChip(item: items[index]),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.item});

  final _StatusItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 146,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: AppTheme.primaryRed, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.value,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
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

class _DashboardFallbackNote extends StatelessWidget {
  const _DashboardFallbackNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.45,
            ),
          ),
        ),
        if (actionText != null)
          TextButton(onPressed: onAction, child: Text(actionText!)),
      ],
    );
  }
}

class _QuickActionLauncher extends StatelessWidget {
  const _QuickActionLauncher({required this.actions, required this.onTap});

  final List<_HomeAction> actions;
  final ValueChanged<_HomeActionTarget> onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      child: GridView.builder(
        itemCount: actions.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 0.92,
        ),
        itemBuilder: (context, index) {
          final action = actions[index];
          return _LogoActionTile(
            action: action,
            onTap: () => onTap(action.target),
          );
        },
      ),
    );
  }
}

class _LogoActionTile extends StatelessWidget {
  const _LogoActionTile({required this.action, required this.onTap});

  final _HomeAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryRed.withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryRed.withValues(alpha: 0.95),
                      AppTheme.darkRed,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryRed.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(action.icon, color: Colors.white, size: 23),
              ),
              const SizedBox(height: 9),
              Text(
                action.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                action.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.summary,
    required this.onStartRequest,
    required this.onTrack,
  });

  final HomeDashboardSummary summary;
  final VoidCallback? onStartRequest;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final hasActiveCase = summary.activeCases > 0;

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      onTap: hasActiveCase ? onTrack : onStartRequest,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: hasActiveCase
                  ? AppTheme.primaryRed.withValues(alpha: 0.09)
                  : const Color(0xFFFBE8EA),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Icon(
              hasActiveCase
                  ? Icons.track_changes_rounded
                  : Icons.add_task_rounded,
              color: AppTheme.primaryRed,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: hasActiveCase
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Service work is in progress',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${summary.activeCases} active case(s) currently being tracked.',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          value: 0.62,
                          backgroundColor: AppTheme.primaryRed.withValues(
                            alpha: 0.10,
                          ),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryRed,
                          ),
                        ),
                      ),
                    ],
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No active service yet',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Start a request and your service progress will appear here.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
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

class _WorkspaceList extends StatelessWidget {
  const _WorkspaceList({required this.actions, required this.onTap});

  final List<_WorkspaceAction> actions;
  final ValueChanged<_HomeActionTarget> onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int index = 0; index < actions.length; index++) ...[
            _WorkspaceTile(
              action: actions[index],
              onTap: () => onTap(actions[index].target),
            ),
            if (index != actions.length - 1)
              const Divider(height: 1, indent: 76, endIndent: 18),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({required this.action, required this.onTap});

  final _WorkspaceAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(action.icon, color: AppTheme.primaryRed, size: 22),
      ),
      title: Text(
        action.title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        action.subtitle,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.activities, required this.onTrack});

  final List<HomeDashboardActivity> activities;
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    final latestActivity = activities.isNotEmpty ? activities.first : null;

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
              Icons.history_rounded,
              color: AppTheme.primaryRed,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: latestActivity == null
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No live case activity yet',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Submitted requests and status updates stay here.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latestActivity.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        latestActivity.subtitle.isNotEmpty
                            ? latestActivity.subtitle
                            : latestActivity.createdAtLabel ?? 'Latest update',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (activities.length > 1) ...[
                        const SizedBox(height: 6),
                        Text(
                          '+${activities.length - 1} more update(s)',
                          style: const TextStyle(
                            color: AppTheme.primaryRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: AppTheme.primaryRed),
          ),
        ),
      ),
    );
  }
}

enum _HomeActionTarget {
  dashboard,
  myServices,
  services,
  documents,
  payments,
  calculator,
  support,
  knowledge,
  expenseTracker,
}

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
  const _StatusItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}
