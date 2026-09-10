import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('remaining routed list owners use the responsive page contract', () {
    final workspace = source(
      'lib/features/internal_workspace/presentation/internal_workspace_screen.dart',
    );
    final review = source(
      'lib/features/documents/presentation/internal_document_review_screen.dart',
    );
    final services = source(
      'lib/features/service_requests/presentation/my_services_screen.dart',
    );
    final payment = source(
      'lib/features/payments/presentation/payment_detail_screen.dart',
    );
    final operational = source(
      'lib/features/service_requests/presentation/operational_service_case_detail_screen.dart',
    );
    final history = source(
      'lib/features/tax_calculator/presentation/tax_calculation_history_screen.dart',
    );
    final support = source(
      'lib/features/support/presentation/support_screen_legacy.dart',
    );
    final supportDetail = source(
      'lib/features/support/presentation/support_ticket_detail_legacy_screen.dart',
    );

    for (final text in [
      workspace,
      review,
      services,
      payment,
      operational,
      history,
      support,
      supportDetail,
    ]) {
      expect(text, contains('OmcPageListView'));
    }

    expect(workspace, isNot(contains('_pagePadding')));
    expect(review, isNot(contains('EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl)')));
    expect(services, isNot(contains('EdgeInsets.fromLTRB(20, 10, 20, 148)')));
    expect(support, isNot(contains('EdgeInsets.fromLTRB(20, 18, 20, 112)')));
  });

  test('detail empty and error states are also bounded', () {
    final payment = source(
      'lib/features/payments/presentation/payment_detail_screen.dart',
    );
    final supportDetail = source(
      'lib/features/support/presentation/support_ticket_detail_legacy_screen.dart',
    );
    final history = source(
      'lib/features/tax_calculator/presentation/tax_calculation_history_screen.dart',
    );

    expect(payment, contains('OmcPagePadding'));
    expect(supportDetail, contains('OmcPagePadding'));
    expect(history, contains('OmcPagePadding'));
  });

  test('request draft keeps form authority while closing C2 and status gaps', () {
    final draft = source(
      'lib/features/service_requests/presentation/service_request_draft_screen.dart',
    );
    final sections = source(
      'lib/features/service_requests/presentation/service_request_draft_form_sections.dart',
    );

    expect(draft, contains('OmcPageListView'));
    expect(draft, contains('maxWidth: AppLayout.formMaxWidth'));
    expect(draft, isNot(contains('EdgeInsets.fromLTRB(20, 12, 20, 104)')));
    expect(draft, contains('MutationIntent()'));
    expect(draft, contains('UnsavedChangesGuard'));
    expect(draft, contains('_submit(service, fields)'));
    expect(sections, contains('theme.textTheme.labelMedium'));
    expect(sections, isNot(contains('theme.textTheme.bodySmall?.copyWith(\n                      color: AppTheme.textSecondary,\n                      fontWeight: FontWeight.w600')));
  });

  test('shell bottom bar is layout-owned rather than body-overlay owned', () {
    final mainShell = source('lib/app/main_shell.dart');
    final nestedShell = source('lib/app/shell_nav_scaffold.dart');
    expect(mainShell, contains('extendBody: false'));
    expect(mainShell, contains('bottomNavigationBar: OmcBottomNav'));
    expect(nestedShell, contains('extendBody: false'));
    expect(nestedShell, contains('bottomNavigationBar: OmcBottomNav'));
  });

  test('support section titles use the semantic section token', () {
    final detail = source(
      'lib/features/support/presentation/support_ticket_detail_legacy_screen.dart',
    );
    expect(detail, contains("'Conversation'"));
    expect(detail, contains('textTheme.titleLarge'));
    expect(detail, isNot(contains('fontSize: 21,\n                        height: 1.2,\n                        fontWeight: FontWeight.w700')));
  });
}
