from pathlib import Path

ROOT = Path('omc_app')


def read(rel):
    return (ROOT / rel).read_text()


def write(rel, text):
    (ROOT / rel).write_text(text)


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 anchor, found {count}')
    return text.replace(old, new, 1)


def replace_count(text, old, new, expected, label):
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{label}: expected {expected} anchors, found {count}')
    return text.replace(old, new)


# 1) Internal workspace: all three live page states use the C2 page primitive.
rel = 'lib/features/internal_workspace/presentation/internal_workspace_screen.dart'
text = read(rel)
text = replace_once(
    text,
    "import '../../../core/widgets/premium_card.dart';\n",
    "import '../../../core/widgets/omc_premium.dart';\nimport '../../../core/widgets/premium_card.dart';\n",
    'internal workspace import',
)
text = replace_once(
    text,
    "\nconst EdgeInsets _pagePadding = EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl);\n",
    "\n",
    'internal workspace fixed page padding',
)
text = replace_once(
    text,
    """    return ListView(\n      physics: const AlwaysScrollableScrollPhysics(\n        parent: BouncingScrollPhysics(),\n      ),\n      padding: _pagePadding,\n      children: [\n""",
    """    return OmcPageListView(\n      topPadding: 18,\n      bottomPadding: AppSpacing.xl,\n      children: [\n""",
    'internal workspace data page',
)
text = replace_count(
    text,
    """    return ListView(\n      physics: const AlwaysScrollableScrollPhysics(),\n      padding: _pagePadding,\n      children: [\n""",
    """    return OmcPageListView(\n      topPadding: 18,\n      bottomPadding: AppSpacing.xl,\n      physics: const AlwaysScrollableScrollPhysics(),\n      children: [\n""",
    2,
    'internal workspace loading/error pages',
)
write(rel, text)

# 2) Internal document review: error, data and loading use bounded responsive pages.
rel = 'lib/features/documents/presentation/internal_document_review_screen.dart'
text = read(rel)
text = replace_once(
    text,
    """                return ListView(\n                  physics: const AlwaysScrollableScrollPhysics(),\n                  padding: const EdgeInsets.all(20),\n                  children: [\n""",
    """                return OmcPageListView(\n                  topPadding: AppSpacing.lg,\n                  bottomPadding: AppSpacing.xl,\n                  physics: const AlwaysScrollableScrollPhysics(),\n                  children: [\n""",
    'document review error page',
)
text = replace_once(
    text,
    """    return ListView(\n      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,\n      physics: const AlwaysScrollableScrollPhysics(),\n      padding: const EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl),\n      children: [\n""",
    """    return OmcPageListView(\n      topPadding: 18,\n      bottomPadding: AppSpacing.xl,\n      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,\n      physics: const AlwaysScrollableScrollPhysics(),\n      children: [\n""",
    'document review data page',
)
text = replace_once(
    text,
    """    return ListView(\n      physics: const AlwaysScrollableScrollPhysics(),\n      padding: const EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl),\n      children: const [\n""",
    """    return OmcPageListView(\n      topPadding: 18,\n      bottomPadding: AppSpacing.xl,\n      physics: const AlwaysScrollableScrollPhysics(),\n      children: const [\n""",
    'document review loading page',
)
write(rel, text)

# 3) My Services: remove the obsolete assumed 148px shell-bar gap and bound live lists.
rel = 'lib/features/service_requests/presentation/my_services_screen.dart'
text = read(rel)
text = replace_once(
    text,
    "import '../../../app/providers/effective_capabilities_provider.dart';\n",
    "import '../../../app/design_tokens.dart';\nimport '../../../app/providers/effective_capabilities_provider.dart';\n",
    'my services tokens import',
)
text = replace_once(
    text,
    """              child: ListView(\n                physics: const AlwaysScrollableScrollPhysics(\n                  parent: BouncingScrollPhysics(),\n                ),\n                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,\n                padding: const EdgeInsets.fromLTRB(20, 10, 20, 148),\n                children: [\n""",
    """              child: OmcPageListView(\n                topPadding: 10,\n                bottomPadding: AppSpacing.xl,\n                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,\n                children: [\n""",
    'my services data page',
)
text = replace_once(
    text,
    """    return ListView(\n      physics: const AlwaysScrollableScrollPhysics(\n        parent: BouncingScrollPhysics(),\n      ),\n      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),\n      children: [\n""",
    """    return OmcPageListView(\n      topPadding: 14,\n      bottomPadding: AppSpacing.xl,\n      children: [\n""",
    'my services loading page',
)
write(rel, text)

# 4) Payment detail: make data/loading/empty/error states responsive and bounded.
rel = 'lib/features/payments/presentation/payment_detail_screen.dart'
text = read(rel)
text = replace_once(
    text,
    """            return const Padding(\n              padding: EdgeInsets.all(20),\n              child: AppEmptyState(\n""",
    """            return const OmcPagePadding(\n              topPadding: AppSpacing.lg,\n              bottomPadding: AppSpacing.xl,\n              child: AppEmptyState(\n""",
    'payment empty page',
)
text = replace_once(
    text,
    """        error: (error, _) => Padding(\n          padding: const EdgeInsets.all(20),\n          child: AppErrorState.fromError(\n""",
    """        error: (error, _) => OmcPagePadding(\n          topPadding: AppSpacing.lg,\n          bottomPadding: AppSpacing.xl,\n          child: AppErrorState.fromError(\n""",
    'payment error page',
)
text = replace_once(
    text,
    """    return ListView(\n      padding: const EdgeInsets.fromLTRB(20, 20, 20, AppSpacing.xl),\n      children: [\n""",
    """    return OmcPageListView(\n      topPadding: AppSpacing.lg,\n      bottomPadding: AppSpacing.xl,\n      children: [\n""",
    'payment loading page',
)
text = replace_once(
    text,
    """    return ListView(\n      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,\n      padding: const EdgeInsets.fromLTRB(20, 16, 20, AppSpacing.xl),\n      children: [\n""",
    """    return OmcPageListView(\n      topPadding: AppSpacing.md,\n      bottomPadding: AppSpacing.xl,\n      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,\n      children: [\n""",
    'payment data page',
)
write(rel, text)

# 5) Operational service case: responsive live error/null/data paths only.
rel = 'lib/features/service_requests/presentation/operational_service_case_detail_screen.dart'
text = read(rel)
text = replace_once(
    text,
    "import '../../../app/mutation_invalidation.dart';\n",
    "import '../../../app/design_tokens.dart';\nimport '../../../app/mutation_invalidation.dart';\n",
    'operational detail tokens import',
)
text = replace_count(
    text,
    """          error: (error, _) => ListView(\n            physics: const AlwaysScrollableScrollPhysics(),\n            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),\n            children: [\n""",
    """          error: (error, _) => OmcPageListView(\n            topPadding: AppSpacing.lg,\n            bottomPadding: AppSpacing.xxl,\n            physics: const AlwaysScrollableScrollPhysics(),\n            children: [\n""",
    1,
    'operational error page',
)
text = replace_once(
    text,
    """              return ListView(\n                physics: const AlwaysScrollableScrollPhysics(),\n                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),\n                children: [\n""",
    """              return OmcPageListView(\n                topPadding: AppSpacing.lg,\n                bottomPadding: AppSpacing.xxl,\n                physics: const AlwaysScrollableScrollPhysics(),\n                children: [\n""",
    'operational null page',
)
text = replace_once(
    text,
    """              child: ListView(\n                physics: const AlwaysScrollableScrollPhysics(\n                  parent: BouncingScrollPhysics(),\n                ),\n                padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),\n                children: [\n""",
    """              child: OmcPageListView(\n                topPadding: AppSpacing.sm,\n                bottomPadding: AppSpacing.xxl,\n                children: [\n""",
    'operational data page',
)
write(rel, text)

# 6) Service request draft: C2 form width + sticky action contract + 14px workflow status.
rel = 'lib/features/service_requests/presentation/service_request_draft_screen.dart'
text = read(rel)
text = replace_once(
    text,
    "import '../../../app/theme.dart';\n",
    "import '../../../app/design_tokens.dart';\nimport '../../../app/theme.dart';\n",
    'draft tokens import',
)
text = replace_once(
    text,
    "import '../../../core/widgets/loading_view.dart';\n",
    "import '../../../core/widgets/loading_view.dart';\nimport '../../../core/widgets/omc_premium.dart';\n",
    'draft page primitive import',
)
text = replace_once(
    text,
    """        body: Padding(\n          padding: const EdgeInsets.all(20),\n          child: AppErrorState.fromError(\n""",
    """        body: OmcPagePadding(\n          topPadding: AppSpacing.lg,\n          bottomPadding: AppSpacing.xl,\n          maxWidth: AppLayout.formMaxWidth,\n          child: AppErrorState.fromError(\n""",
    'draft error page',
)
text = replace_once(
    text,
    """            body: EmptyState(\n              title: catalogueIsEmpty\n""",
    """            body: OmcPagePadding(\n              topPadding: AppSpacing.lg,\n              bottomPadding: AppSpacing.xl,\n              maxWidth: AppLayout.formMaxWidth,\n              child: EmptyState(\n                title: catalogueIsEmpty\n""",
    'draft unavailable page open',
)
text = replace_once(
    text,
    """              onAction: () => context.go('/services'),\n            ),\n          );\n""",
    """                onAction: () => context.go('/services'),\n              ),\n            ),\n          );\n""",
    'draft unavailable page close',
)
text = replace_once(
    text,
    """                child: ListView(\n                  physics: const BouncingScrollPhysics(),\n                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),\n                  children: [\n""",
    """                child: OmcPageListView(\n                  topPadding: AppSpacing.sm,\n                  bottomPadding: AppSpacing.xl,\n                  maxWidth: AppLayout.formMaxWidth,\n                  physics: const BouncingScrollPhysics(),\n                  children: [\n""",
    'draft form page',
)
write(rel, text)

rel = 'lib/features/service_requests/presentation/service_request_draft_form_sections.dart'
text = read(rel)
text = replace_once(
    text,
    """          child: Padding(\n            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),\n            child: LayoutBuilder(\n""",
    """          child: Center(\n            child: ConstrainedBox(\n              constraints: const BoxConstraints(\n                maxWidth: AppLayout.formMaxWidth + 32,\n              ),\n              child: Padding(\n                padding: const EdgeInsets.symmetric(\n                  horizontal: AppSpacing.md,\n                  vertical: AppSpacing.sm,\n                ),\n                child: LayoutBuilder(\n""",
    'draft sticky bar open',
)
# Close the two wrappers introduced around the existing LayoutBuilder.
old = """              },\n            ),\n          ),\n        ),\n      ),\n    );\n  }\n}\n\nclass _CardTitle"""
new = """                  },\n                ),\n              ),\n            ),\n          ),\n        ),\n      ),\n    );\n  }\n}\n\nclass _CardTitle"""
text = replace_once(text, old, new, 'draft sticky bar close')
text = replace_once(
    text,
    """                    style: theme.textTheme.bodySmall?.copyWith(\n                      color: AppTheme.textSecondary,\n                      fontWeight: FontWeight.w600,\n                      height: 1.35,\n                    ),\n""",
    """                    style: theme.textTheme.labelMedium?.copyWith(\n                      color: AppTheme.textSecondary,\n                      fontWeight: FontWeight.w500,\n                    ),\n""",
    'draft workflow status typography',
)
write(rel, text)

# 7) Tax history: bounded data and state pages.
rel = 'lib/features/tax_calculator/presentation/tax_calculation_history_screen.dart'
text = read(rel)
text = replace_once(
    text,
    "import '../../../app/theme.dart';\n",
    "import '../../../app/design_tokens.dart';\nimport '../../../app/theme.dart';\n",
    'tax history tokens import',
)
text = replace_once(
    text,
    """            child: ListView(\n              physics: const AlwaysScrollableScrollPhysics(\n                parent: BouncingScrollPhysics(),\n              ),\n              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),\n              children: [\n""",
    """            child: OmcPageListView(\n              topPadding: AppSpacing.sm,\n              bottomPadding: AppSpacing.xxl,\n              children: [\n""",
    'tax history data page',
)
text = replace_once(
    text,
    """    return Center(\n      child: Padding(\n        padding: const EdgeInsets.all(24),\n        child: Column(\n""",
    """    return OmcPagePadding(\n      topPadding: AppSpacing.xl,\n      bottomPadding: AppSpacing.xl,\n      child: Center(\n        child: Column(\n""",
    'tax history state open',
)
text = replace_once(
    text,
    """          ],\n        ),\n      ),\n    );\n  }\n}\n\nString _formatMoney""",
    """          ],\n        ),\n      ),\n    );\n  }\n}\n\nString _formatMoney""",
    'tax history state close',
)
write(rel, text)

# 8) Support list: responsive bounded general page; shell already owns bottom bar space.
rel = 'lib/features/support/presentation/support_screen_legacy.dart'
text = read(rel)
text = replace_once(
    text,
    """        child: ListView(\n          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,\n          physics: const AlwaysScrollableScrollPhysics(\n            parent: BouncingScrollPhysics(),\n          ),\n          padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),\n          children: [\n""",
    """        child: OmcPageListView(\n          topPadding: 18,\n          bottomPadding: AppSpacing.xl,\n          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,\n          children: [\n""",
    'support root page',
)
write(rel, text)

# 9) Support ticket detail: bound all routed states/chat and normalize section headings.
rel = 'lib/features/support/presentation/support_ticket_detail_legacy_screen.dart'
text = read(rel)
text = replace_once(
    text,
    "import '../../../app/theme.dart';\n",
    "import '../../../app/design_tokens.dart';\nimport '../../../app/theme.dart';\n",
    'support detail tokens import',
)
text = replace_once(
    text,
    """        body: Padding(\n          padding: EdgeInsets.all(20),\n          child: AppEmptyState(\n""",
    """        body: OmcPagePadding(\n          topPadding: AppSpacing.lg,\n          bottomPadding: AppSpacing.xl,\n          child: AppEmptyState(\n""",
    'support invalid id page',
)
text = replace_once(
    text,
    """            return const Padding(\n              padding: EdgeInsets.all(20),\n              child: AppEmptyState(\n""",
    """            return const OmcPagePadding(\n              topPadding: AppSpacing.lg,\n              bottomPadding: AppSpacing.xl,\n              child: AppEmptyState(\n""",
    'support null page',
)
text = replace_once(
    text,
    """        error: (error, _) => Padding(\n          padding: const EdgeInsets.all(20),\n          child: AppErrorState.fromError(\n""",
    """        error: (error, _) => OmcPagePadding(\n          topPadding: AppSpacing.lg,\n          bottomPadding: AppSpacing.xl,\n          child: AppErrorState.fromError(\n""",
    'support error page',
)
text = replace_once(
    text,
    """              child: ListView(\n                controller: _scrollController,\n                keyboardDismissBehavior:\n                    ScrollViewKeyboardDismissBehavior.onDrag,\n                physics: const AlwaysScrollableScrollPhysics(\n                  parent: BouncingScrollPhysics(),\n                ),\n                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),\n                children: [\n""",
    """              child: OmcPageListView(\n                topPadding: 14,\n                bottomPadding: AppSpacing.xl,\n                controller: _scrollController,\n                keyboardDismissBehavior:\n                    ScrollViewKeyboardDismissBehavior.onDrag,\n                children: [\n""",
    'support chat page',
)
text = replace_once(
    text,
    """                  Semantics(\n                    header: true,\n                    child: const Text(\n                      'Conversation',\n                      style: TextStyle(\n                        color: AppTheme.textPrimary,\n                        fontSize: 21,\n                        height: 1.2,\n                        fontWeight: FontWeight.w700,\n                      ),\n                    ),\n                  ),\n""",
    """                  Semantics(\n                    header: true,\n                    child: Text(\n                      'Conversation',\n                      style: Theme.of(context).textTheme.titleLarge?.copyWith(\n                        color: AppTheme.textPrimary,\n                      ),\n                    ),\n                  ),\n""",
    'support conversation heading',
)
text = replace_once(
    text,
    """                child: const Text(\n                  'Update ticket status',\n                  style: TextStyle(\n                    color: AppTheme.textPrimary,\n                    fontSize: 21,\n                    fontWeight: FontWeight.w700,\n                  ),\n                ),\n""",
    """                child: Text(\n                  'Update ticket status',\n                  style: Theme.of(context).textTheme.titleLarge?.copyWith(\n                    color: AppTheme.textPrimary,\n                  ),\n                ),\n""",
    'support status sheet heading',
)
text = replace_once(
    text,
    """    return ListView(\n      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),\n      children: [\n""",
    """    return OmcPageListView(\n      topPadding: 18,\n      bottomPadding: AppSpacing.lg,\n      children: [\n""",
    'support loading page',
)
write(rel, text)

# Permanent source contract test for these audited owners.
test_rel = 'test/app/uiux_final_live_routed_contract_test.dart'
test = r'''import 'dart:io';

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
'''
write(test_rel, test)

print('Applied final live routed UI/UX closure.')
