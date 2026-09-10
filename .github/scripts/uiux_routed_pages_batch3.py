from pathlib import Path


def replace_count(text, old, new, count, label):
    actual = text.count(old)
    if actual != count:
        raise SystemExit(f'{label}: expected {count} anchors, found {actual}')
    return text.replace(old, new)


def add_import(text, anchor, import_line, label):
    if import_line in text:
        return text
    if text.count(anchor) != 1:
        raise SystemExit(f'{label}: import anchor mismatch')
    return text.replace(anchor, anchor + import_line, 1)


# Expense Tracker V2: close every routed root/state layout while preserving
# local/cloud storage, paging, sync and mutation authority.
path = Path('omc_app/lib/features/expense_tracker/presentation/expense_tracker_v2_screen.dart')
text = path.read_text()
text = add_import(
    text,
    "import '../../../core/widgets/app_labeled_field.dart';\n",
    "import '../../../core/widgets/omc_premium.dart';\n",
    'expense tracker premium import',
)
text = replace_count(
    text,
    '''        body: const SafeArea(\n          top: false,\n          child: PremiumEmptyState(''',
    '''        body: const SafeArea(\n          top: false,\n          child: OmcPagePadding(\n            topPadding: AppSpacing.lg,\n            bottomPadding: AppSpacing.lg,\n            child: PremiumEmptyState(''',
    1,
    'expense internal-hidden page',
)
# close the extra wrapper introduced above before SafeArea closes
old = '''            message:\n                'Internal users use the internal workspace for customer review. Personal customer tracking is hidden by default.',\n          ),\n        ),\n      );'''
new = '''            message:\n                'Internal users use the internal workspace for customer review. Personal customer tracking is hidden by default.',\n            ),\n          ),\n        ),\n      );'''
text = replace_count(text, old, new, 1, 'expense internal-hidden wrapper close')
text = replace_count(
    text,
    '''                error: (_, _) => Padding(\n                  padding: const EdgeInsets.all(AppSpacing.lg),\n                  child: PremiumEmptyState(''',
    '''                error: (_, _) => OmcPagePadding(\n                  topPadding: AppSpacing.lg,\n                  bottomPadding: AppSpacing.lg,\n                  child: PremiumEmptyState(''',
    1,
    'expense local error page',
)
text = replace_count(
    text,
    '''      child: ListView(\n        physics: const AlwaysScrollableScrollPhysics(\n          parent: BouncingScrollPhysics(),\n        ),\n        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),\n''',
    '''      child: OmcPageListView(\n        topPadding: 12,\n        bottomPadding: 40,\n''',
    1,
    'expense local ledger root',
)
text = replace_count(
    text,
    '''      error: (error, _) => ListView(\n        physics: const AlwaysScrollableScrollPhysics(),\n        padding: const EdgeInsets.all(20),\n''',
    '''      error: (error, _) => OmcPageListView(\n        topPadding: 20,\n        bottomPadding: 20,\n        physics: const AlwaysScrollableScrollPhysics(),\n''',
    1,
    'expense cloud error root',
)
text = replace_count(
    text,
    '''        child: ListView(\n          physics: const AlwaysScrollableScrollPhysics(\n            parent: BouncingScrollPhysics(),\n          ),\n          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),\n''',
    '''        child: OmcPageListView(\n          topPadding: 12,\n          bottomPadding: 40,\n''',
    1,
    'expense cloud ledger root',
)
text = replace_count(
    text,
    '''    return ListView(\n      physics: const AlwaysScrollableScrollPhysics(),\n      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),\n''',
    '''    return OmcPageListView(\n      topPadding: 12,\n      bottomPadding: 40,\n      physics: const AlwaysScrollableScrollPhysics(),\n''',
    1,
    'expense loading root',
)
path.write_text(text)

# Expense Budget V2: restricted state and main workspace roots.
path = Path('omc_app/lib/features/expense_tracker/presentation/expense_budget_v2_screen.dart')
text = path.read_text()
text = add_import(
    text,
    "import '../../../core/widgets/app_labeled_field.dart';\n",
    "import '../../../core/widgets/omc_premium.dart';\n",
    'expense budget premium import',
)
text = replace_count(
    text,
    '''          child: Padding(\n            padding: EdgeInsets.all(AppSpacing.lg),\n            child: PremiumEmptyState(''',
    '''          child: OmcPagePadding(\n            topPadding: AppSpacing.lg,\n            bottomPadding: AppSpacing.lg,\n            child: PremiumEmptyState(''',
    1,
    'budget restricted root',
)
text = replace_count(
    text,
    '''          child: ListView(\n            physics: const AlwaysScrollableScrollPhysics(\n              parent: BouncingScrollPhysics(),\n            ),\n            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),\n''',
    '''          child: OmcPageListView(\n            topPadding: 12,\n            bottomPadding: 40,\n''',
    1,
    'budget workspace root',
)
path.write_text(text)

# Onboarding is form-width bounded already; make only the viewport inset C2 adaptive.
path = Path('omc_app/lib/features/onboarding/presentation/onboarding_screen.dart')
text = path.read_text()
text = replace_count(
    text,
    'padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),',
    '''padding: EdgeInsets.fromLTRB(\n                AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width),\n                12,\n                AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width),\n                20,\n              ),''',
    1,
    'onboarding viewport inset',
)
path.write_text(text)

# Under-review account state is already form-width bounded and centered.
path = Path('omc_app/lib/features/auth/presentation/under_review_screen.dart')
text = path.read_text()
text = add_import(
    text,
    "import 'package:go_router/go_router.dart';\n\n",
    "import '../../../app/design_tokens.dart';\n",
    'under review design tokens import',
)
text = replace_count(
    text,
    'padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),',
    '''padding: EdgeInsets.fromLTRB(\n              AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width),\n              24,\n              AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width),\n              28,\n            ),''',
    1,
    'under review viewport inset',
)
text = replace_count(
    text,
    'top: Radius.circular(24)',
    'top: Radius.circular(AppRadius.sheet)',
    1,
    'under review sheet radius token',
)
path.write_text(text)

# Knowledge detail body/loading are already reading-width bounded; close only
# the routed error/empty states.
path = Path('omc_app/lib/features/knowledge/presentation/knowledge_detail_screen.dart')
text = path.read_text()
text = add_import(
    text,
    "import '../../../core/widgets/app_state.dart';\n",
    "import '../../../core/widgets/omc_premium.dart';\n",
    'knowledge detail premium import',
)
text = replace_count(
    text,
    '''          error: (error, _) => Padding(\n            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),\n            child: AppErrorState.fromError(''',
    '''          error: (error, _) => OmcPagePadding(\n            topPadding: 24,\n            bottomPadding: 28,\n            child: AppErrorState.fromError(''',
    1,
    'knowledge error root',
)
text = replace_count(
    text,
    '''              return const Padding(\n                padding: EdgeInsets.fromLTRB(20, 24, 20, 28),\n                child: AppEmptyState(''',
    '''              return const OmcPagePadding(\n                topPadding: 24,\n                bottomPadding: 28,\n                child: AppEmptyState(''',
    1,
    'knowledge empty root',
)
path.write_text(text)

# Tax Calculator: all configuration/error roots and main calculator list.
path = Path('omc_app/lib/features/tax_calculator/presentation/tax_calculator_screen.dart')
text = path.read_text()
text = add_import(
    text,
    "import '../../../core/widgets/loading_view.dart';\n",
    "import '../../../core/widgets/omc_premium.dart';\n",
    'tax premium import',
)
text = replace_count(
    text,
    '''            return Padding(\n              padding: const EdgeInsets.all(20),\n              child: AppErrorState.fromError(''',
    '''            return OmcPagePadding(\n              topPadding: 20,\n              bottomPadding: 20,\n              child: AppErrorState.fromError(''',
    1,
    'tax config error root',
)
text = replace_count(
    text,
    '''            return Padding(\n              padding: const EdgeInsets.all(20),\n              child: AppErrorState(''',
    '''            return OmcPagePadding(\n              topPadding: 20,\n              bottomPadding: 20,\n              child: AppErrorState(''',
    1,
    'tax null config root',
)
text = replace_count(
    text,
    '''            return Padding(\n              padding: const EdgeInsets.all(20),\n              child: AppConfigurationState(''',
    '''            return OmcPagePadding(\n              topPadding: 20,\n              bottomPadding: 20,\n              child: AppConfigurationState(''',
    1,
    'tax disabled root',
)
text = replace_count(
    text,
    '''            return const Padding(\n              padding: EdgeInsets.all(20),\n              child: AppConfigurationState(''',
    '''            return const OmcPagePadding(\n              topPadding: 20,\n              bottomPadding: 20,\n              child: AppConfigurationState(''',
    1,
    'tax unconfigured root',
)
text = replace_count(
    text,
    '''            child: ListView(\n              physics: const AlwaysScrollableScrollPhysics(\n                parent: BouncingScrollPhysics(),\n              ),\n              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),\n''',
    '''            child: OmcPageListView(\n              topPadding: 8,\n              bottomPadding: 40,\n''',
    1,
    'tax calculator root',
)
path.write_text(text)

# Approved-customer service-case detail is the canonical customer route owner.
path = Path('omc_app/lib/features/service_requests/presentation/customer_service_case_detail_screen.dart')
text = path.read_text()
text = add_import(
    text,
    "import '../../../core/widgets/app_state.dart';\n",
    "import '../../../core/widgets/omc_premium.dart';\n",
    'customer case premium import',
)
text = replace_count(
    text,
    '''                    child: ListView(\n                      physics: const AlwaysScrollableScrollPhysics(\n                        parent: BouncingScrollPhysics(),\n                      ),\n                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),\n''',
    '''                    child: OmcPageListView(\n                      topPadding: 12,\n                      bottomPadding: 40,\n''',
    1,
    'customer case data root',
)
path.write_text(text)

path = Path('omc_app/lib/features/service_requests/presentation/customer_service_case_detail_support.dart')
text = path.read_text()
text = replace_count(
    text,
    '''    return ListView(\n      padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),\n''',
    '''    return OmcPageListView(\n      topPadding: 10,\n      bottomPadding: 36,\n''',
    1,
    'customer case loading root',
)
text = replace_count(
    text,
    '''    return Center(\n      child: SingleChildScrollView(\n        padding: const EdgeInsets.all(22),\n        child: AppErrorState(title: title, message: message, onRetry: onRetry),\n      ),\n    );''',
    '''    return OmcPagePadding(\n      topPadding: 22,\n      bottomPadding: 22,\n      child: AppErrorState(title: title, message: message, onRetry: onRetry),\n    );''',
    1,
    'customer case error root',
)
path.write_text(text)

# Focused current-route source contract.
test = Path('omc_app/test/app/uiux_routed_pages_batch3_test.dart')
test.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('routed expense V2 screens use bounded responsive roots', () {
    final router = read('lib/app/router.dart');
    final tracker = read('lib/features/expense_tracker/presentation/expense_tracker_v2_screen.dart');
    final budget = read('lib/features/expense_tracker/presentation/expense_budget_v2_screen.dart');
    expect(router, contains('const ExpenseTrackerV2Screen()'));
    expect(router, contains('const ExpenseBudgetV2Screen()'));
    expect('OmcPageListView('.allMatches(tracker).length, greaterThanOrEqualTo(4));
    expect('OmcPagePadding('.allMatches(tracker).length, greaterThanOrEqualTo(2));
    expect(budget, contains('child: OmcPageListView('));
    expect(budget, contains('child: OmcPagePadding('));
    expect(tracker, isNot(contains('padding: const EdgeInsets.fromLTRB(20, 12, 20, 40)')));
    expect(budget, isNot(contains('padding: const EdgeInsets.fromLTRB(20, 12, 20, 40)')));
  });

  test('routed entry and account-state roots honor the C2 viewport inset', () {
    final router = read('lib/app/router.dart');
    final onboarding = read('lib/features/onboarding/presentation/onboarding_screen.dart');
    final review = read('lib/features/auth/presentation/under_review_screen.dart');
    expect(router, contains('const OnboardingScreen()'));
    expect(router, contains('const UnderReviewScreen()'));
    expect(onboarding, contains('AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width)'));
    expect(review, contains('AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width)'));
    expect(review, contains('Radius.circular(AppRadius.sheet)'));
  });

  test('knowledge and tax routed states are responsive without altering data authority', () {
    final router = read('lib/app/router.dart');
    final knowledge = read('lib/features/knowledge/presentation/knowledge_detail_screen.dart');
    final tax = read('lib/features/tax_calculator/presentation/tax_calculator_screen.dart');
    expect(router, contains('KnowledgeDetailScreen(articleId: articleId)'));
    expect(router, contains('const TaxCalculatorScreen()'));
    expect('OmcPagePadding('.allMatches(knowledge).length, greaterThanOrEqualTo(2));
    expect('OmcPagePadding('.allMatches(tax).length, greaterThanOrEqualTo(4));
    expect(tax, contains('child: OmcPageListView('));
    expect(tax, contains('taxCalculationRepositoryProvider'));
    expect(knowledge, contains('knowledgeArticleDetailProvider(articleId)'));
  });

  test('canonical approved-customer service case uses responsive data and state roots', () {
    final dispatcher = read('lib/features/service_requests/presentation/service_case_detail_screen.dart');
    final screen = read('lib/features/service_requests/presentation/customer_service_case_detail_screen.dart');
    final support = read('lib/features/service_requests/presentation/customer_service_case_detail_support.dart');
    expect(dispatcher, contains('return CustomerServiceCaseDetailScreen(caseId: caseId)'));
    expect(screen, contains('child: OmcPageListView('));
    expect(support, contains('return OmcPageListView('));
    expect(support, contains('return OmcPagePadding('));
    expect(screen, contains('customerServiceCaseDetailProvider(widget.caseId)'));
    expect(screen, contains('.cancelRequest('));
  });
}
''')
