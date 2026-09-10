from pathlib import Path
import re

ROOT = Path('omc_app')
LIB = ROOT / 'lib'


def text(rel):
    return (ROOT / rel).read_text()


def require(source, needle, label):
    if needle not in source:
        raise SystemExit(f'MISSING {label}: {needle!r}')


def forbid(source, needle, label):
    if needle in source:
        raise SystemExit(f'FORBIDDEN {label}: {needle!r}')


def hits(needle):
    found = []
    for path in LIB.rglob('*.dart'):
        data = path.read_text()
        for line_no, line in enumerate(data.splitlines(), 1):
            if needle in line:
                found.append((str(path.relative_to(ROOT)), line_no, line.strip()))
    return found


print('=== ROUTE OWNER AUTHORITY ===')
router = text('lib/app/router.dart')
for needle in [
    'const ProfileV2Screen()',
    'const SettingsV2Screen()',
    'const MyServicesScreen()',
    'PaymentDetailScreen(',
    'SupportTicketDetailScreen(ticketId: ticketId)',
    'return ServiceRequestDraftScreen(',
    'TaxCalculationHistoryScreen()',
    'const InternalWorkspaceScreen()',
    'const InternalDocumentReviewScreen()',
    'InternalOperationArea.payments',
]:
    require(router, needle, f'router owner {needle}')
print('route authority: OK')

print('=== RESPONSIVE / BOUNDED ROOT CONTRACTS ===')
responsive_files = {
    'lib/features/profile/presentation/profile_v2_screen.dart': 'OmcPageListView',
    'lib/features/settings/presentation/settings_v2_screen.dart': 'OmcPageListView',
    'lib/features/dashboard/presentation/dashboard_screen.dart': 'OmcPageListView',
    'lib/features/notifications/presentation/notifications_screen.dart': 'OmcPageListView',
    'lib/features/payments/presentation/payments_screen.dart': 'OmcPageListView',
    'lib/features/payments/presentation/payment_detail_screen.dart': 'OmcPageListView',
    'lib/features/expense_tracker/presentation/expense_tracker_v2_screen.dart': 'OmcPageListView',
    'lib/features/expense_tracker/presentation/expense_budget_v2_screen.dart': 'OmcPageListView',
    'lib/features/internal_workspace/presentation/internal_workspace_screen.dart': 'OmcPageListView',
    'lib/features/documents/presentation/internal_document_review_screen.dart': 'OmcPageListView',
    'lib/features/service_requests/presentation/my_services_screen.dart': 'OmcPageListView',
    'lib/features/service_requests/presentation/customer_service_case_detail_screen.dart': 'OmcPageListView',
    'lib/features/service_requests/presentation/operational_service_case_detail_screen.dart': 'OmcPageListView',
    'lib/features/service_requests/presentation/service_request_draft_screen.dart': 'OmcPageListView',
    'lib/features/tax_calculator/presentation/tax_calculator_screen.dart': 'OmcPageListView',
    'lib/features/tax_calculator/presentation/tax_calculation_history_screen.dart': 'OmcPageListView',
    'lib/features/support/presentation/support_screen_legacy.dart': 'OmcPageListView',
    'lib/features/support/presentation/support_ticket_detail_legacy_screen.dart': 'OmcPageListView',
}
for rel, primitive in responsive_files.items():
    require(text(rel), primitive, f'responsive root {rel}')

for rel, old_gap in [
    ('lib/features/service_requests/presentation/my_services_screen.dart', 'EdgeInsets.fromLTRB(20, 10, 20, 148)'),
    ('lib/features/service_requests/presentation/service_request_draft_screen.dart', 'EdgeInsets.fromLTRB(20, 12, 20, 104)'),
    ('lib/features/support/presentation/support_screen_legacy.dart', 'EdgeInsets.fromLTRB(20, 18, 20, 112)'),
    ('lib/features/internal_workspace/presentation/internal_workspace_screen.dart', '_pagePadding'),
    ('lib/features/documents/presentation/internal_document_review_screen.dart', 'EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl)'),
]:
    forbid(text(rel), old_gap, f'obsolete root gap {rel}')

premium = text('lib/core/widgets/omc_premium.dart')
require(premium, 'AppLayout.pageInsetFor(constraints.maxWidth)', 'responsive inset primitive')
require(premium, 'maxWidth = AppLayout.generalMaxWidth', 'general max width')
print('responsive roots: OK')

print('=== SHELL / BOTTOM GAP AUTHORITY ===')
for rel in ['lib/app/main_shell.dart', 'lib/app/shell_nav_scaffold.dart']:
    data = text(rel)
    require(data, 'extendBody: false', f'non-overlay shell {rel}')
    require(data, 'bottomNavigationBar: OmcBottomNav', f'bottom nav owner {rel}')
print('shell authority: OK')

print('=== C1 / C5 SEMANTIC ROLE CONTRACTS ===')
for rel in [
    'lib/features/home/presentation/approved_customer_home_actions.dart',
    'lib/features/home/presentation/customer_guest_home_view.dart',
    'lib/features/home/presentation/internal_home_view.dart',
]:
    require(text(rel), 'fontSize: 16', f'quick action label 16 {rel}')

require(text('lib/features/dashboard/presentation/dashboard_screen.dart'), 'textTheme.labelMedium', 'dashboard status role')
alerts = text('lib/features/notifications/presentation/notifications_screen.dart')
for role in ['.titleMedium', '.bodyMedium', '.labelMedium']:
    require(alerts, role, f'alerts role {role}')
require(text('lib/features/payments/presentation/widgets/payment_action_card.dart'), 'textTheme.labelMedium', 'payment status role')
require(text('lib/features/tax_calculator/presentation/tax_calculator_screen.dart'), 'textTheme.labelMedium', 'tax status role')
require(text('lib/features/service_requests/presentation/operational_service_case_detail_screen.dart'), 'class _MetaPill', 'operational meta pill')
operational = text('lib/features/service_requests/presentation/operational_service_case_detail_screen.dart')
pill_start = operational.index('class _MetaPill')
pill_end = operational.index('\n}', pill_start) + 2
pill = operational[pill_start:pill_end]
require(pill, 'textTheme.labelMedium', 'operational workflow pill 14 role')
forbid(pill, 'fontSize: 13', 'operational workflow pill caption role')
print('semantic roles: OK')

print('=== C6 MODAL CONTRACTS ===')
theme = text('lib/app/theme.dart')
require(theme, 'bottomSheetTheme: const BottomSheetThemeData', 'bottom sheet theme')
require(theme, 'showDragHandle: true', 'native sheet handle')
require(theme, 'top: Radius.circular(AppRadius.sheet)', '24px sheet top radius')

home = text('lib/features/home/presentation/home_screen_role_aware.dart')
a = home.index('void _showGuestAccessSheet(')
b = home.index('void _showLockedSnack(', a)
guest_sheet = home[a:b]
for needle in ['useSafeArea: true', 'isScrollControlled: true', 'height * 0.90', "context.push('/signup')", "context.push('/login')"]:
    require(guest_sheet, needle, f'E094 {needle}')
for needle in ['backgroundColor: Colors.transparent', 'BoxShadow(', 'width: 42', 'backgroundColor: AppTheme.primary', 'BorderRadius.circular(28)', 'BorderRadius.circular(22)', 'BorderRadius.circular(17)']:
    forbid(guest_sheet, needle, f'E094 legacy modal styling {needle}')

for rel in [
    'lib/features/leads/presentation/leads_screen.dart',
    'lib/features/service_requests/presentation/operational_service_case_detail_screen.dart',
]:
    data = text(rel)
    require(data, 'enableDrag: false', f'controlled no-drag sheet {rel}')
    require(data, 'showDragHandle: false', f'controlled hidden handle {rel}')
print('modal contracts: OK')

print('=== PROHIBITED GLOBAL PATTERN CLASSIFICATION ===')
# The sole no-op/tiny-target relics are intentionally retained in the explicitly
# unrouted non-payment legacy branch of InternalOperationsCenterScreen.
allowed_dead = 'lib/features/internal_workspace/presentation/internal_operations_center_screen.dart'
for needle in ['onPressed: () {}', 'minimumSize: Size.zero', 'tapTargetSize: MaterialTapTargetSize.shrinkWrap']:
    found = hits(needle)
    print(needle, found)
    if any(path != allowed_dead for path, _, _ in found):
        raise SystemExit(f'live/unclassified prohibited hit for {needle}: {found}')

# Hard legacy typography may remain in known dead historical implementations,
# but not in the routed V2/detail owners covered by this final audit.
routed_live = set(responsive_files) | {
    'lib/features/home/presentation/approved_customer_home_view.dart',
    'lib/features/home/presentation/approved_customer_home_actions.dart',
    'lib/features/home/presentation/customer_guest_home_view.dart',
    'lib/features/home/presentation/internal_home_view.dart',
    'lib/features/documents/presentation/documents_screen.dart',
    'lib/features/documents/presentation/document_detail_screen.dart',
    'lib/features/notifications/presentation/notification_detail_screen.dart',
    'lib/features/customers/presentation/customers_screen.dart',
    'lib/features/customers/presentation/customer_detail_screen.dart',
}
for rel in routed_live:
    forbid(text(rel), 'FontWeight.w900', f'w900 routed owner {rel}')
print('prohibited patterns: classified/OK')

print('=== PERSISTENT FIELD LABEL / SEARCH EXCEPTION CHECK ===')
# Non-search form owners closed in prior batches must not regress to floating labels.
for rel in [
    'lib/features/profile/presentation/edit_profile_v2_screen.dart',
    'lib/features/expense_tracker/presentation/expense_tracker_v2_screen.dart',
    'lib/features/expense_tracker/presentation/expense_budget_v2_screen.dart',
    'lib/features/support/presentation/support_screen_legacy.dart',
    'lib/features/service_requests/presentation/service_request_draft_screen.dart',
]:
    forbid(text(rel), 'labelText:', f'floating non-search form label {rel}')
print('persistent labels: OK')

print('=== BOTTOM NAV BADGE ===')
nav = text('lib/app/navigation/omc_bottom_nav.dart')
require(nav, 'fontSize: 11', 'numeric badge count token')
print('bottom nav badge: OK')

print('FINAL EXACT SOURCE AUDIT: CLEAN')
