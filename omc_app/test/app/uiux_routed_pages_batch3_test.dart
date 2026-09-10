import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('routed expense V2 screens use bounded responsive roots', () {
    final router = read('lib/app/router.dart');
    final tracker = read(
      'lib/features/expense_tracker/presentation/expense_tracker_v2_screen.dart',
    );
    final budget = read(
      'lib/features/expense_tracker/presentation/expense_budget_v2_screen.dart',
    );
    expect(router, contains('const ExpenseTrackerV2Screen()'));
    expect(router, contains('const ExpenseBudgetV2Screen()'));
    expect(
      'OmcPageListView('.allMatches(tracker).length,
      greaterThanOrEqualTo(4),
    );
    expect(
      'OmcPagePadding('.allMatches(tracker).length,
      greaterThanOrEqualTo(2),
    );
    expect(budget, contains('child: OmcPageListView('));
    expect(budget, contains('child: OmcPagePadding('));
    expect(
      tracker,
      isNot(contains('padding: const EdgeInsets.fromLTRB(20, 12, 20, 40)')),
    );
    expect(
      budget,
      isNot(contains('padding: const EdgeInsets.fromLTRB(20, 12, 20, 40)')),
    );
  });

  test('routed entry and account-state roots honor the C2 viewport inset', () {
    final router = read('lib/app/router.dart');
    final onboarding = read(
      'lib/features/onboarding/presentation/onboarding_screen.dart',
    );
    final review = read(
      'lib/features/auth/presentation/under_review_screen.dart',
    );
    expect(router, contains('const OnboardingScreen()'));
    expect(router, contains('const UnderReviewScreen()'));
    expect(
      onboarding,
      contains('AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width)'),
    );
    expect(
      review,
      contains('AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width)'),
    );
    expect(review, contains('Radius.circular(AppRadius.sheet)'));
  });

  test(
    'knowledge and tax routed states are responsive without altering data authority',
    () {
      final router = read('lib/app/router.dart');
      final knowledge = read(
        'lib/features/knowledge/presentation/knowledge_detail_screen.dart',
      );
      final tax = read(
        'lib/features/tax_calculator/presentation/tax_calculator_screen.dart',
      );
      expect(router, contains('KnowledgeDetailScreen(articleId: articleId)'));
      expect(router, contains('const TaxCalculatorScreen()'));
      expect(
        'OmcPagePadding('.allMatches(knowledge).length,
        greaterThanOrEqualTo(2),
      );
      expect('OmcPagePadding('.allMatches(tax).length, greaterThanOrEqualTo(4));
      expect(tax, contains('child: OmcPageListView('));
      expect(tax, contains('taxCalculationRepositoryProvider'));
      expect(knowledge, contains('knowledgeArticleDetailProvider(articleId)'));
    },
  );

  test(
    'canonical approved-customer service case uses responsive data and state roots',
    () {
      final dispatcher = read(
        'lib/features/service_requests/presentation/service_case_detail_screen.dart',
      );
      final screen = read(
        'lib/features/service_requests/presentation/customer_service_case_detail_screen.dart',
      );
      final support = read(
        'lib/features/service_requests/presentation/customer_service_case_detail_support.dart',
      );
      expect(
        dispatcher,
        contains('return CustomerServiceCaseDetailScreen(caseId: caseId)'),
      );
      expect(screen, contains('child: OmcPageListView('));
      expect(support, contains('return OmcPageListView('));
      expect(support, contains('return OmcPagePadding('));
      expect(
        screen,
        contains('customerServiceCaseDetailProvider(widget.caseId)'),
      );
      expect(screen, contains('.cancelRequest('));
    },
  );
}
