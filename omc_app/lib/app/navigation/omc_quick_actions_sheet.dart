import 'package:flutter/material.dart';

import '../../features/auth/application/auth_state.dart';
import '../theme.dart';
import 'omc_nav_models.dart';

Future<void> showOmcQuickActionsSheet({
  required BuildContext context,
  required AuthCapabilities capabilities,
  required VoidCallback onOpenServices,
  required VoidCallback onOpenDocuments,
  required VoidCallback onOpenPayments,
  required VoidCallback onOpenSupport,
  required VoidCallback onOpenTaxCalculator,
  required VoidCallback onOpenExpenseTracker,
  required VoidCallback onOpenProfile,
  required VoidCallback onOpenInternalWorkspace,
  required VoidCallback onOpenCustomers,
  required VoidCallback onOpenTasks,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final actions = _quickActions(
        sheetContext: sheetContext,
        capabilities: capabilities,
        onOpenServices: onOpenServices,
        onOpenDocuments: onOpenDocuments,
        onOpenPayments: onOpenPayments,
        onOpenSupport: onOpenSupport,
        onOpenTaxCalculator: onOpenTaxCalculator,
        onOpenExpenseTracker: onOpenExpenseTracker,
        onOpenProfile: onOpenProfile,
        onOpenInternalWorkspace: onOpenInternalWorkspace,
        onOpenCustomers: onOpenCustomers,
        onOpenTasks: onOpenTasks,
      );
      return _QuickActionsContent(actions: actions);
    },
  );
}

List<OmcSheetAction> _quickActions({
  required BuildContext sheetContext,
  required AuthCapabilities capabilities,
  required VoidCallback onOpenServices,
  required VoidCallback onOpenDocuments,
  required VoidCallback onOpenPayments,
  required VoidCallback onOpenSupport,
  required VoidCallback onOpenTaxCalculator,
  required VoidCallback onOpenExpenseTracker,
  required VoidCallback onOpenProfile,
  required VoidCallback onOpenInternalWorkspace,
  required VoidCallback onOpenCustomers,
  required VoidCallback onOpenTasks,
}) {
  OmcSheetAction action(String label, IconData icon, VoidCallback onTap) {
    return OmcSheetAction(label: label, icon: icon, onTap: () => _closeThen(sheetContext, onTap));
  }

  if (capabilities.canAccessInternalWorkspace || capabilities.isInternal) {
    return [
      action('Workspace', Icons.admin_panel_settings_outlined, onOpenInternalWorkspace),
      action('Service Cases', Icons.fact_check_outlined, onOpenServices),
      action('Customers', Icons.groups_outlined, onOpenCustomers),
      action('Docs Review', Icons.folder_copy_outlined, onOpenDocuments),
      action('Tasks', Icons.task_alt_outlined, onOpenTasks),
    ];
  }

  if (capabilities.isApproved) {
    return [
      action('New Service', Icons.add_business_outlined, onOpenServices),
      action('Upload Doc', Icons.upload_file_outlined, onOpenDocuments),
      action('Payment Receipt', Icons.receipt_long_outlined, onOpenPayments),
      action('Support Ticket', Icons.support_agent_outlined, onOpenSupport),
      action('Expense Entry', Icons.account_balance_wallet_outlined, onOpenExpenseTracker),
    ];
  }

  if (capabilities.isPending) {
    return [
      action('Tax Calculator', Icons.calculate_outlined, onOpenTaxCalculator),
      action('Expense Tracker', Icons.account_balance_wallet_outlined, onOpenExpenseTracker),
      action('Support', Icons.support_agent_outlined, onOpenSupport),
      action('Profile Status', Icons.verified_user_outlined, onOpenProfile),
    ];
  }

  return [
    action('Tax Calculator', Icons.calculate_outlined, onOpenTaxCalculator),
    action('Expense Tracker', Icons.account_balance_wallet_outlined, onOpenExpenseTracker),
    action('Support', Icons.support_agent_outlined, onOpenSupport),
    action('Create Account', Icons.person_add_alt_1_outlined, onOpenProfile),
  ];
}

void _closeThen(BuildContext context, VoidCallback onTap) {
  Navigator.of(context).pop();
  onTap();
}

class _QuickActionsContent extends StatelessWidget {
  const _QuickActionsContent({required this.actions});

  final List<OmcSheetAction> actions;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Quick actions',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Fast shortcuts based on your current access.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) => _SheetActionTile(action: actions[index]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetActionTile extends StatelessWidget {
  const _SheetActionTile({required this.action});

  final OmcSheetAction action;

  @override
  Widget build(BuildContext context) {
    final color = action.isDestructive ? Colors.red.shade700 : AppTheme.primaryRed;
    return Material(
      color: AppTheme.cardSoft.withValues(alpha: 0.48),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(action.icon, color: color, size: 21),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 11,
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
