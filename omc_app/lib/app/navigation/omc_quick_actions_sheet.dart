import 'package:flutter/material.dart';

import '../../core/widgets/omc_premium.dart';
import '../../features/auth/application/auth_state.dart';
import '../theme.dart';
import 'omc_nav_models.dart';

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
  required VoidCallback onCreateTask,
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
        onOpenTrack: onOpenTrack,
        onOpenSupport: onOpenSupport,
        onOpenTaxCalculator: onOpenTaxCalculator,
        onOpenExpenseTracker: onOpenExpenseTracker,
        onOpenProfile: onOpenProfile,
        onOpenKnowledge: onOpenKnowledge,
        onOpenInternalWorkspace: onOpenInternalWorkspace,
        onOpenCustomers: onOpenCustomers,
        onOpenTasks: onOpenTasks,
        onCreateLead: onCreateLead,
        onCreateTask: onCreateTask,
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
  required VoidCallback onCreateTask,
}) {
  OmcSheetAction action(String label, IconData icon, VoidCallback onTap) {
    return OmcSheetAction(
      label: label,
      icon: icon,
      onTap: () => _closeThen(sheetContext, onTap),
    );
  }

  if (capabilities.canAccessInternalWorkspace || capabilities.isInternal) {
    final items = <OmcSheetAction>[];

    if (capabilities.canManageLeads) {
      items.add(
        action('New Lead', Icons.person_add_alt_1_rounded, onCreateLead),
      );
    }
    if (capabilities.canManageTasks) {
      items.add(
        action('Assign Task', Icons.playlist_add_check_rounded, onCreateTask),
      );
    }
    if (capabilities.canCreateServiceForCustomer) {
      items.add(
        action('Start Request', Icons.add_business_rounded, onOpenServices),
      );
    }
    if (capabilities.canReviewPayments) {
      items.add(
        action('Review Payments', Icons.receipt_long_outlined, onOpenPayments),
      );
    }
    if (capabilities.canReviewDocuments) {
      items.add(
        action('Review Documents', Icons.fact_check_outlined, onOpenDocuments),
      );
    }
    if (capabilities.canManageCustomers ||
        capabilities.canViewAllCustomers ||
        capabilities.canViewRelevantCustomers) {
      items.add(
        action('Customers', Icons.person_search_rounded, onOpenCustomers),
      );
    }
    if (capabilities.canViewAllServiceCases ||
        capabilities.canViewRelevantServiceCases ||
        capabilities.canViewAssignedServiceCases) {
      items.add(
        action('Cases', Icons.fact_check_outlined, onOpenInternalWorkspace),
      );
    }
    if (capabilities.canManageAssignedTasks && !capabilities.canManageTasks) {
      items.add(action('My Tasks', Icons.task_alt_outlined, onOpenTasks));
    }

    return items;
  }

  if (capabilities.isApproved) {
    return [
      action('Apply', Icons.add_business_outlined, onOpenServices),
      action('Documents', Icons.folder_copy_outlined, onOpenDocuments),
      action('Payments', Icons.account_balance_wallet_outlined, onOpenPayments),
      action('Track', Icons.timeline_rounded, onOpenTrack),
      action('Tax Calc', Icons.calculate_outlined, onOpenTaxCalculator),
      action('Support', Icons.support_agent_outlined, onOpenSupport),
    ];
  }

  if (capabilities.isPending) {
    return [
      action('Services', Icons.grid_view_rounded, onOpenServices),
      action('Tax', Icons.calculate_outlined, onOpenTaxCalculator),
      action('Knowledge', Icons.menu_book_outlined, onOpenKnowledge),
      action('Support', Icons.support_agent_outlined, onOpenSupport),
      action('Status', Icons.verified_user_outlined, onOpenProfile),
    ];
  }

  return [
    action('Services', Icons.grid_view_rounded, onOpenServices),
    action('Tax', Icons.calculate_outlined, onOpenTaxCalculator),
    action('Knowledge', Icons.menu_book_outlined, onOpenKnowledge),
    action('Support', Icons.support_agent_outlined, onOpenSupport),
    action('Sign Up', Icons.person_add_alt_1_outlined, onOpenProfile),
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.55,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
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
              'Start common work without searching through the app.',
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
                mainAxisSpacing: 12,
                crossAxisSpacing: 10,
                childAspectRatio: 1.10,
              ),
              itemBuilder: (context, index) =>
                  _SheetActionButton(action: actions[index]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  const _SheetActionButton({required this.action});

  final OmcSheetAction action;

  @override
  Widget build(BuildContext context) {
    final color = action.isDestructive
        ? OmcPremium.danger
        : OmcPremium.moduleColor(action.label);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action.icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: action.isDestructive
                      ? OmcPremium.danger
                      : AppTheme.textPrimary,
                  fontSize: 10.5,
                  height: 1.08,
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
