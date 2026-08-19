import 'package:flutter/material.dart';

import '../../core/widgets/omc_premium.dart';
import '../../features/auth/application/auth_state.dart';
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
  required VoidCallback onOpenCustomers,
  required VoidCallback onOpenTasks,
  required VoidCallback onCreateLead,
}) async {
  final actions = buildOmcQuickActions(capabilities);

  VoidCallback callbackFor(OmcNavigationActionId id) {
    return switch (id) {
      OmcNavigationActionId.createLead => onCreateLead,
      OmcNavigationActionId.startRequest || OmcNavigationActionId.apply =>
        onOpenServices,
      OmcNavigationActionId.reviewPayments || OmcNavigationActionId.payments =>
        onOpenPayments,
      OmcNavigationActionId.reviewDocuments ||
      OmcNavigationActionId.documents => onOpenDocuments,
      OmcNavigationActionId.supportQueue || OmcNavigationActionId.support =>
        onOpenSupport,
      OmcNavigationActionId.tasks => onOpenTasks,
      OmcNavigationActionId.tax => onOpenTaxCalculator,
      OmcNavigationActionId.knowledge => onOpenKnowledge,
      OmcNavigationActionId.profile => onOpenProfile,
      OmcNavigationActionId.workspace => onOpenInternalWorkspace,
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
    showDragHandle: true,
    backgroundColor: Colors.white,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => _QuickActionsContent(
      actions: actions,
      callbackFor: callbackFor,
    ),
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
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.58,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Quick actions',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Actions for the work you can perform right now.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, index) {
                final item = actions[index];
                return _QuickActionButton(
                  item: item,
                  onTap: () => Navigator.of(context).pop(callbackFor(item.id)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.item, required this.onTap});

  final OmcNavigationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = OmcPremium.moduleColor(item.label);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(item.id), color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 10.8,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(OmcNavigationActionId id) {
  return switch (id) {
    OmcNavigationActionId.createLead => Icons.person_add_alt_1_rounded,
    OmcNavigationActionId.startRequest || OmcNavigationActionId.apply =>
      Icons.add_business_rounded,
    OmcNavigationActionId.reviewPayments || OmcNavigationActionId.payments =>
      Icons.receipt_long_outlined,
    OmcNavigationActionId.reviewDocuments ||
    OmcNavigationActionId.documents => Icons.fact_check_outlined,
    OmcNavigationActionId.supportQueue || OmcNavigationActionId.support =>
      Icons.support_agent_outlined,
    OmcNavigationActionId.tasks => Icons.task_alt_outlined,
    OmcNavigationActionId.tax => Icons.calculate_outlined,
    OmcNavigationActionId.knowledge => Icons.menu_book_outlined,
    OmcNavigationActionId.profile => Icons.person_outline_rounded,
    OmcNavigationActionId.workspace => Icons.dashboard_customize_outlined,
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
