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


# Shared non-scroll page padding for live error/empty states.
premium_path = Path('omc_app/lib/core/widgets/omc_premium.dart')
premium = premium_path.read_text()
marker = 'class OmcSurface extends StatelessWidget {'
primitive = '''class OmcPagePadding extends StatelessWidget {
  const OmcPagePadding({
    required this.child,
    super.key,
    this.topPadding = AppSpacing.lg,
    this.bottomPadding = AppSpacing.xl,
    this.maxWidth = AppLayout.generalMaxWidth,
  });

  final Widget child;
  final double topPadding;
  final double bottomPadding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = AppLayout.pageInsetFor(constraints.maxWidth);
        final horizontal = constraints.maxWidth > maxWidth + inset * 2
            ? (constraints.maxWidth - maxWidth) / 2
            : inset;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            topPadding,
            horizontal,
            bottomPadding,
          ),
          child: child,
        );
      },
    );
  }
}

'''
if 'class OmcPagePadding extends StatelessWidget' not in premium:
    if premium.count(marker) != 1:
        raise SystemExit('page padding primitive insertion anchor mismatch')
    premium = premium.replace(marker, primitive + marker, 1)
premium_path.write_text(premium)

# Routed Profile V2: content, unavailable and loading roots.
path = Path('omc_app/lib/features/profile/presentation/profile_v2_screen.dart')
text = path.read_text()
text = replace_count(
    text,
    '''    return ListView(\n      physics: const AlwaysScrollableScrollPhysics(\n        parent: BouncingScrollPhysics(),\n      ),\n      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),\n''',
    '''    return OmcPageListView(\n      topPadding: 18,\n      bottomPadding: 40,\n''',
    1,
    'profile content root',
)
text = replace_count(
    text,
    '''    return ListView(\n      physics: const AlwaysScrollableScrollPhysics(),\n      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),\n''',
    '''    return OmcPageListView(\n      topPadding: 18,\n      bottomPadding: 40,\n      physics: const AlwaysScrollableScrollPhysics(),\n''',
    2,
    'profile state roots',
)
path.write_text(text)

# Routed Edit Profile V2: overview/loading plus non-scroll unavailable/error roots.
path = Path('omc_app/lib/features/profile/presentation/edit_profile_v2_screen.dart')
text = path.read_text()
text = add_import(
    text,
    "import '../../../core/widgets/app_state.dart';\n",
    "import '../../../core/widgets/omc_premium.dart';\n",
    'edit profile premium import',
)
text = replace_count(
    text,
    '''      child: ListView(\n        physics: const AlwaysScrollableScrollPhysics(\n          parent: BouncingScrollPhysics(),\n        ),\n        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),\n''',
    '''      child: OmcPageListView(\n        topPadding: 12,\n        bottomPadding: 40,\n''',
    1,
    'edit profile overview root',
)
text = replace_count(
    text,
    '''    return ListView(\n      physics: const AlwaysScrollableScrollPhysics(),\n      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),\n''',
    '''    return OmcPageListView(\n      topPadding: 12,\n      bottomPadding: 40,\n      physics: const AlwaysScrollableScrollPhysics(),\n''',
    1,
    'edit profile loading root',
)
text = replace_count(
    text,
    '''    return const Padding(\n      padding: EdgeInsets.all(20),\n      child: AppEmptyState(''',
    '''    return const OmcPagePadding(\n      topPadding: 20,\n      bottomPadding: 20,\n      child: AppEmptyState(''',
    1,
    'edit profile unavailable root',
)
text = replace_count(
    text,
    '''    return Padding(\n      padding: const EdgeInsets.all(20),\n      child: AppErrorState.fromError(''',
    '''    return OmcPagePadding(\n      topPadding: 20,\n      bottomPadding: 20,\n      child: AppErrorState.fromError(''',
    1,
    'edit profile error root',
)
path.write_text(text)

# Routed Settings V2 root. Preserve its explicit BouncingScrollPhysics behavior.
path = Path('omc_app/lib/features/settings/presentation/settings_v2_screen.dart')
text = path.read_text()
text = replace_count(
    text,
    '''        child: ListView(\n          physics: const BouncingScrollPhysics(),\n          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),\n''',
    '''        child: OmcPageListView(\n          topPadding: 18,\n          bottomPadding: 40,\n          physics: const BouncingScrollPhysics(),\n''',
    1,
    'settings root',
)
path.write_text(text)

# Routed Change Password is already form-width constrained. Only make its root
# inset responsive at 320 while preserving the existing ListView and physics.
path = Path('omc_app/lib/features/settings/presentation/change_password_screen.dart')
text = path.read_text()
text = replace_count(
    text,
    'padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),',
    '''padding: EdgeInsets.fromLTRB(\n                  AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width),\n                  18,\n                  AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width),\n                  40,\n                ),''',
    1,
    'change password responsive form inset',
)
path.write_text(text)

# Routed customer directory: data/loading/error roots.
path = Path('omc_app/lib/features/customers/presentation/customers_screen.dart')
text = path.read_text()
text = add_import(
    text,
    "import '../../../core/widgets/app_back_header.dart';\n",
    "import '../../../core/widgets/omc_premium.dart';\n",
    'customers premium import',
)
text = replace_count(
    text,
    '''    return ListView(\n      physics: const AlwaysScrollableScrollPhysics(\n        parent: BouncingScrollPhysics(),\n      ),\n      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),\n''',
    '''    return OmcPageListView(\n      topPadding: 12,\n      bottomPadding: 40,\n''',
    1,
    'customers data root',
)
text = replace_count(
    text,
    '''    return ListView(\n      physics: const AlwaysScrollableScrollPhysics(),\n      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),\n''',
    '''    return OmcPageListView(\n      topPadding: 12,\n      bottomPadding: 40,\n      physics: const AlwaysScrollableScrollPhysics(),\n''',
    2,
    'customers state roots',
)
text = text.replace(
    'borderRadius: BorderRadius.circular(999),',
    'borderRadius: BorderRadius.circular(AppRadius.pill),',
)
path.write_text(text)

# Routed customer detail body.
path = Path('omc_app/lib/features/customers/presentation/customer_detail_screen.dart')
text = path.read_text()
text = add_import(
    text,
    "import '../../../core/widgets/app_back_header.dart';\n",
    "import '../../../core/widgets/omc_premium.dart';\n",
    'customer detail premium import',
)
text = replace_count(
    text,
    '''    return ListView(\n      physics: const AlwaysScrollableScrollPhysics(\n        parent: BouncingScrollPhysics(),\n      ),\n      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),\n''',
    '''    return OmcPageListView(\n      topPadding: 16,\n      bottomPadding: 40,\n''',
    1,
    'customer detail root',
)
path.write_text(text)

# Routed customer Documents: workspace/error/loading roots and the two ordinary
# empty-state icons that exceed the C4 decorative-icon cap.
path = Path('omc_app/lib/features/documents/presentation/documents_screen.dart')
text = path.read_text()
text = replace_count(
    text,
    '''    return ListView(\n      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,\n      physics: const AlwaysScrollableScrollPhysics(\n        parent: BouncingScrollPhysics(),\n      ),\n      padding: const EdgeInsets.fromLTRB(20, 16, 20, AppSpacing.xl),\n''',
    '''    return OmcPageListView(\n      topPadding: 16,\n      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,\n''',
    1,
    'documents workspace root',
)
text = replace_count(
    text,
    '''    return ListView(\n      physics: const AlwaysScrollableScrollPhysics(),\n      padding: const EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl),\n''',
    '''    return OmcPageListView(\n      topPadding: 18,\n      physics: const AlwaysScrollableScrollPhysics(),\n''',
    1,
    'documents error root',
)
text = replace_count(
    text,
    '''    return ListView.separated(\n      physics: const AlwaysScrollableScrollPhysics(),\n      padding: const EdgeInsets.fromLTRB(20, 28, 20, AppSpacing.xl),\n      itemBuilder: (context, index) => PremiumCard(\n        padding: const EdgeInsets.all(16),\n        child: Container(\n          height: index == 0 ? 76 : 108,\n          decoration: BoxDecoration(\n            color: Theme.of(context).colorScheme.surfaceContainerLow,\n            borderRadius: BorderRadius.circular(12),\n          ),\n        ),\n      ),\n      separatorBuilder: (_, _) => const SizedBox(height: 10),\n      itemCount: 6,\n    );''',
    '''    return OmcPageListView(\n      topPadding: 28,\n      physics: const AlwaysScrollableScrollPhysics(),\n      children: [\n        for (var index = 0; index < 6; index++) ...[\n          PremiumCard(\n            padding: const EdgeInsets.all(16),\n            child: Container(\n              height: index == 0 ? 76 : 108,\n              decoration: BoxDecoration(\n                color: Theme.of(context).colorScheme.surfaceContainerLow,\n                borderRadius: BorderRadius.circular(12),\n              ),\n            ),\n          ),\n          if (index != 5) const SizedBox(height: 10),\n        ],\n      ],\n    );''',
    1,
    'documents loading root',
)
# Class-local icon replacements avoid touching functional/action glyphs.
filtered_start = text.index('class _FilteredEmptyView')
empty_start = text.index('class _EmptyDocumentsView', filtered_start)
error_start = text.index('class _DocumentsErrorView', empty_start)
if min(filtered_start, empty_start, error_start) < 0:
    raise SystemExit('documents empty-state class anchors missing')
filtered = text[filtered_start:empty_start]
empty = text[empty_start:error_start]
filtered = replace_count(filtered, 'size: 36,', 'size: 32,', 1, 'filtered empty icon')
empty = replace_count(empty, 'size: 40,', 'size: 32,', 1, 'documents empty icon')
text = text[:filtered_start] + filtered + empty + text[error_start:]
path.write_text(text)

# Routed document detail: data/loading/error/empty roots.
path = Path('omc_app/lib/features/documents/presentation/document_detail_screen.dart')
text = path.read_text()
text = add_import(
    text,
    "import '../../../core/widgets/app_state.dart';\n",
    "import '../../../core/widgets/omc_premium.dart';\n",
    'document detail premium import',
)
text = replace_count(
    text,
    '''            return const Padding(\n              padding: EdgeInsets.all(20),\n              child: AppEmptyState(''',
    '''            return const OmcPagePadding(\n              topPadding: 20,\n              bottomPadding: 20,\n              child: AppEmptyState(''',
    1,
    'document detail empty root',
)
text = replace_count(
    text,
    '''          error: (error, _) => Padding(\n            padding: const EdgeInsets.all(20),\n            child: AppErrorState.fromError(''',
    '''          error: (error, _) => OmcPagePadding(\n            topPadding: 20,\n            bottomPadding: 20,\n            child: AppErrorState.fromError(''',
    1,
    'document detail error root',
)
text = replace_count(
    text,
    '''    return ListView(\n      padding: const EdgeInsets.all(20),\n''',
    '''    return OmcPageListView(\n      topPadding: 20,\n      bottomPadding: 20,\n''',
    1,
    'document detail loading root',
)
text = replace_count(
    text,
    '''    return ListView(\n      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,\n      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),\n''',
    '''    return OmcPageListView(\n      topPadding: 12,\n      bottomPadding: 32,\n      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,\n''',
    1,
    'document detail data root',
)
path.write_text(text)

# Routed notification detail: data/loading/error/empty roots.
path = Path('omc_app/lib/features/notifications/presentation/notification_detail_screen.dart')
text = path.read_text()
text = replace_count(
    text,
    '''              return const Padding(\n                padding: EdgeInsets.all(20),\n                child: AppEmptyState(''',
    '''              return const OmcPagePadding(\n                topPadding: 20,\n                bottomPadding: 20,\n                child: AppEmptyState(''',
    1,
    'notification detail empty root',
)
text = replace_count(
    text,
    '''          error: (error, _) => Padding(\n            padding: const EdgeInsets.all(20),\n            child: AppErrorState.fromError(''',
    '''          error: (error, _) => OmcPagePadding(\n            topPadding: 20,\n            bottomPadding: 20,\n            child: AppErrorState.fromError(''',
    1,
    'notification detail error root',
)
text = replace_count(
    text,
    '''    return ListView(\n      padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),\n''',
    '''    return OmcPageListView(\n      topPadding: 14,\n      bottomPadding: 36,\n''',
    2,
    'notification detail data/loading roots',
)
path.write_text(text)

# Focused routed-source contract.
test = Path('omc_app/test/app/uiux_routed_pages_batch2_test.dart')
test.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

String block(String source, String start, String end) {
  final a = source.indexOf(start);
  final b = source.indexOf(end, a + start.length);
  expect(a, greaterThanOrEqualTo(0), reason: 'missing $start');
  expect(b, greaterThan(a), reason: 'missing $end');
  return source.substring(a, b);
}

void main() {
  test('shared V2 primitives cover scrolling and non-scrolling page roots', () {
    final source = read('lib/core/widgets/omc_premium.dart');
    expect(source, contains('class OmcPageListView extends StatelessWidget'));
    expect(source, contains('class OmcPagePadding extends StatelessWidget'));
    expect('AppLayout.pageInsetFor(constraints.maxWidth)'.allMatches(source).length,
        greaterThanOrEqualTo(2));
    expect('(constraints.maxWidth - maxWidth) / 2'.allMatches(source).length,
        greaterThanOrEqualTo(2));
  });

  test('routed profile and settings owners use responsive roots', () {
    final router = read('lib/app/router.dart');
    final profile = read('lib/features/profile/presentation/profile_v2_screen.dart');
    final edit = read('lib/features/profile/presentation/edit_profile_v2_screen.dart');
    final settings = read('lib/features/settings/presentation/settings_v2_screen.dart');
    final password = read('lib/features/settings/presentation/change_password_screen.dart');
    expect(router, contains('const ProfileV2Screen()'));
    expect(router, contains('const EditProfileV2Screen()'));
    expect(router, contains('const SettingsV2Screen()'));
    expect(router, contains('const ChangePasswordScreen()'));
    expect('OmcPageListView('.allMatches(profile).length, greaterThanOrEqualTo(3));
    expect('OmcPageListView('.allMatches(edit).length, greaterThanOrEqualTo(2));
    expect('OmcPagePadding('.allMatches(edit).length, greaterThanOrEqualTo(2));
    expect(settings, contains('child: OmcPageListView('));
    expect(password, contains('AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width)'));
  });

  test('routed customer directory and detail use C2 roots', () {
    final router = read('lib/app/router.dart');
    final customers = read('lib/features/customers/presentation/customers_screen.dart');
    final detail = read('lib/features/customers/presentation/customer_detail_screen.dart');
    expect(router, contains('const CustomersScreen()'));
    expect(router, contains('CustomerDetailScreen(customerId: customerId)'));
    expect('OmcPageListView('.allMatches(customers).length, greaterThanOrEqualTo(3));
    expect(detail, contains('return OmcPageListView('));
    expect(customers, isNot(contains('padding: const EdgeInsets.fromLTRB(20, 12, 20, 40)')));
    expect(detail, isNot(contains('padding: const EdgeInsets.fromLTRB(20, 16, 20, 40)')));
  });

  test('routed document list and detail use responsive roots and bounded icons', () {
    final router = read('lib/app/router.dart');
    final documents = read('lib/features/documents/presentation/documents_screen.dart');
    final detail = read('lib/features/documents/presentation/document_detail_screen.dart');
    expect(router, contains('const DocumentsScreen()'));
    expect(router, contains('DocumentDetailScreen('));
    expect('OmcPageListView('.allMatches(documents).length, greaterThanOrEqualTo(3));
    expect('OmcPageListView('.allMatches(detail).length, greaterThanOrEqualTo(2));
    expect('OmcPagePadding('.allMatches(detail).length, greaterThanOrEqualTo(2));
    final filtered = block(documents, 'class _FilteredEmptyView', 'class _EmptyDocumentsView');
    final empty = block(documents, 'class _EmptyDocumentsView', 'class _DocumentsErrorView');
    expect(filtered, contains('size: 32'));
    expect(empty, contains('size: 32'));
    expect(filtered, isNot(contains('size: 36')));
    expect(empty, isNot(contains('size: 40')));
  });

  test('routed notification detail uses responsive data and state roots', () {
    final router = read('lib/app/router.dart');
    final source = read('lib/features/notifications/presentation/notification_detail_screen.dart');
    expect(router, contains('NotificationDetailScreen(notificationId: notificationId)'));
    expect('OmcPageListView('.allMatches(source).length, greaterThanOrEqualTo(2));
    expect('OmcPagePadding('.allMatches(source).length, greaterThanOrEqualTo(2));
    expect(source, isNot(contains('padding: const EdgeInsets.fromLTRB(20, 14, 20, 36)')));
  });
}
''')
