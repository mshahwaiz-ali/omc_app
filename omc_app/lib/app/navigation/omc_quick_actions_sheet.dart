import 'package:flutter/material.dart';

import '../../features/auth/application/auth_state.dart';
import '../design_tokens.dart';
import '../theme.dart';
import 'omc_navigation_ia.dart';

Future<void> showOmcQuickActionsSheet({
  required BuildContext context,
  required AuthCapabilities capabilities,
  required VoidCallback onOpenServices,
  required VoidCallback onOpenDocuments,
  required VoidCallback onOpenPayments,
  required VoidCallback onOpenTrack,
  required VoidCallback onOpenSupport,
  required VoidCallback onOpenTaxCalculator,
  required VoidCallback onOpenExpenseTracker,
  required VoidCallback onOpenProfile,
  required VoidCallback onOpenKnowledge,
  required VoidCallback onOpenInternalWorkspace,
  required VoidCallback onOpenCommissionOperations,
  required VoidCallback onOpenCustomers,
  required VoidCallback onOpenTasks,
  required VoidCallback onCreateLead,
}) async {
  final actions = buildOmcQuickActions(capabilities);

  VoidCallback callbackFor(OmcNavigationActionId id) {
    return switch (id) {
      OmcNavigationActionId.createLead => onCreateLead,
      OmcNavigationActionId.startRequest ||
      OmcNavigationActionId.apply => onOpenServices,
      OmcNavigationActionId.reviewPayments ||
      OmcNavigationActionId.payments => onOpenPayments,
      OmcNavigationActionId.reviewDocuments ||
      OmcNavigationActionId.documents => onOpenDocuments,
      OmcNavigationActionId.supportQueue ||
      OmcNavigationActionId.support => onOpenSupport,
      OmcNavigationActionId.tasks => onOpenTasks,
      OmcNavigationActionId.tax => onOpenTaxCalculator,
      OmcNavigationActionId.knowledge => onOpenKnowledge,
      OmcNavigationActionId.profile => onOpenProfile,
      OmcNavigationActionId.workspace => onOpenInternalWorkspace,
      OmcNavigationActionId.commissionOperations => onOpenCommissionOperations,
      OmcNavigationActionId.customers => onOpenCustomers,
      OmcNavigationActionId.expense => onOpenExpenseTracker,
      OmcNavigationActionId.referrals ||
      OmcNavigationActionId.commissions ||
      OmcNavigationActionId.alerts ||
      OmcNavigationActionId.budget ||
      OmcNavigationActionId.settings ||
      OmcNavigationActionId.login ||
      OmcNavigationActionId.logout ||
      OmcNavigationActionId.leads => onOpenTrack,
    };
  }

  final selectedAction = await showModalBottomSheet<VoidCallback>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (sheetContext) =>
        _QuickActionsContent(actions: actions, callbackFor: callbackFor),
  );

  if (selectedAction == null || !context.mounted) return;
  selectedAction();
}

class _QuickActionsContent extends StatelessWidget {
  const _QuickActionsContent({
    required this.actions,
    required this.callbackFor,
  });

  final List<OmcNavigationItem> actions;
  final VoidCallback Function(OmcNavigationActionId id) callbackFor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.90,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md + bottomInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text('Quick actions', style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Actions available to your account right now.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final columns = _columnCount(
                  width: constraints.maxWidth,
                  textScale: textScale,
                );
                final spacing = AppSpacing.sm;
                final itemWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final item in actions)
                      SizedBox(
                        width: itemWidth,
                        child: _QuickActionButton(
                          item: item,
                          onTap: () => Navigator.of(
                            context,
                          ).pop(callbackFor(item.id)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  int _columnCount({required double width, required double textScale}) {
    if (width < 300 || textScale >= 1.5) return 1;
    if (width >= 600 && textScale < 1.3) {
      final threeColumnItemWidth =
          (width - AppSpacing.sm * 2) / 3;
      if (threeColumnItemWidth >= 176) return 3;
    }
    return 2;
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.item, required this.onTap});

  final OmcNavigationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadius.card);

    return Semantics(
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Icon(
                      _iconFor(item.id),
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(OmcNavigationActionId id) {
  return switch (id) {
    OmcNavigationActionId.createLead => Icons.person_add_alt_1_rounded,
    OmcNavigationActionId.startRequest ||
    OmcNavigationActionId.apply => Icons.add_business_rounded,
    OmcNavigationActionId.reviewPayments ||
    OmcNavigationActionId.payments => Icons.receipt_long_outlined,
    OmcNavigationActionId.reviewDocuments ||
    OmcNavigationActionId.documents => Icons.fact_check_outlined,
    OmcNavigationActionId.supportQueue ||
    OmcNavigationActionId.support => Icons.support_agent_outlined,
    OmcNavigationActionId.tasks => Icons.task_alt_outlined,
    OmcNavigationActionId.tax => Icons.calculate_outlined,
    OmcNavigationActionId.knowledge => Icons.menu_book_outlined,
    OmcNavigationActionId.profile => Icons.person_outline_rounded,
    OmcNavigationActionId.workspace => Icons.dashboard_customize_outlined,
    OmcNavigationActionId.commissionOperations =>
      Icons.account_balance_outlined,
    OmcNavigationActionId.customers => Icons.groups_outlined,
    OmcNavigationActionId.expense => Icons.account_balance_wallet_outlined,
    OmcNavigationActionId.referrals => Icons.hub_outlined,
    OmcNavigationActionId.commissions => Icons.payments_outlined,
    OmcNavigationActionId.alerts => Icons.notifications_none_rounded,
    OmcNavigationActionId.budget => Icons.savings_outlined,
    OmcNavigationActionId.settings => Icons.settings_outlined,
    OmcNavigationActionId.login => Icons.login_rounded,
    OmcNavigationActionId.logout => Icons.logout_rounded,
    OmcNavigationActionId.leads => Icons.person_search_outlined,
  };
}
