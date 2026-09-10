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


# E094: use the shared BottomSheetTheme (24px top radius, native handle,
# runtime-accent button theme) instead of an independent floating sheet skin.
rel = 'lib/features/home/presentation/home_screen_role_aware.dart'
text = read(rel)
old = """    showModalBottomSheet<void>(\n      context: context,\n      useSafeArea: true,\n      isScrollControlled: true,\n      backgroundColor: Colors.transparent,\n      builder: (sheetContext) {\n        final theme = Theme.of(sheetContext);\n        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;\n        return ConstrainedBox(\n          constraints: BoxConstraints(\n            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.92,\n          ),\n          child: Container(\n            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),\n            decoration: BoxDecoration(\n              color: theme.colorScheme.surface,\n              borderRadius: BorderRadius.circular(28),\n              boxShadow: const [\n                BoxShadow(\n                  color: Color(0x240F172A),\n                  blurRadius: 32,\n                  offset: Offset(0, 14),\n                ),\n              ],\n            ),\n            child: SingleChildScrollView(\n              padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),\n              child: Column(\n                mainAxisSize: MainAxisSize.min,\n                children: [\n                  Container(\n                    width: 42,\n                    height: 5,\n                    decoration: BoxDecoration(\n                      color: theme.colorScheme.outlineVariant,\n                      borderRadius: BorderRadius.circular(999),\n                    ),\n                  ),\n                  const SizedBox(height: 22),\n                  Container(\n                    width: 64,\n                    height: 64,\n                    decoration: BoxDecoration(\n                      color: AppTheme.primary.withValues(alpha: 0.09),\n                      borderRadius: BorderRadius.circular(22),\n                    ),\n                    child: const Icon(\n                      Icons.lock_open_rounded,\n                      color: AppTheme.primary,\n                      size: 30,\n                    ),\n                  ),\n                  const SizedBox(height: 18),\n                  Semantics(\n                    header: true,\n                    child: Text(\n                      'Unlock your OMC workspace',\n                      textAlign: TextAlign.center,\n                      style: theme.textTheme.titleLarge?.copyWith(\n                        color: AppTheme.textPrimary,\n                      ),\n                    ),\n                  ),\n                  const SizedBox(height: 8),\n                  Text(\n                    'Create an account to use $featureName, track services, manage documents and access payments.',\n                    textAlign: TextAlign.center,\n                    style: theme.textTheme.bodyLarge?.copyWith(\n                      color: AppTheme.textSecondary,\n                    ),\n                  ),\n                  const SizedBox(height: 22),\n                  SizedBox(\n                    width: double.infinity,\n                    child: FilledButton(\n                      onPressed: () {\n                        Navigator.of(sheetContext).pop();\n                        context.push('/signup');\n                      },\n                      style: FilledButton.styleFrom(\n                        minimumSize: const Size.fromHeight(56),\n                        elevation: 0,\n                        backgroundColor: AppTheme.primary,\n                        foregroundColor: Colors.white,\n                        textStyle: const TextStyle(\n                          fontSize: 16,\n                          fontWeight: FontWeight.w600,\n                        ),\n                        shape: RoundedRectangleBorder(\n                          borderRadius: BorderRadius.circular(17),\n                        ),\n                      ),\n                      child: const Text('Create free account'),\n                    ),\n                  ),\n                  const SizedBox(height: 8),\n                  SizedBox(\n                    width: double.infinity,\n                    child: TextButton(\n                      style: TextButton.styleFrom(\n                        minimumSize: const Size.fromHeight(48),\n                        textStyle: const TextStyle(\n                          fontSize: 16,\n                          fontWeight: FontWeight.w600,\n                        ),\n                      ),\n                      onPressed: () {\n                        Navigator.of(sheetContext).pop();\n                        context.push('/login');\n                      },\n                      child: const Text('Already have an account? Sign in'),\n                    ),\n                  ),\n                ],\n              ),\n            ),\n          ),\n        );\n      },\n    );\n"""
new = """    showModalBottomSheet<void>(\n      context: context,\n      useSafeArea: true,\n      isScrollControlled: true,\n      builder: (sheetContext) {\n        final theme = Theme.of(sheetContext);\n        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;\n        return ConstrainedBox(\n          constraints: BoxConstraints(\n            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.90,\n          ),\n          child: SingleChildScrollView(\n            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,\n            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),\n            child: Column(\n              mainAxisSize: MainAxisSize.min,\n              children: [\n                Container(\n                  width: 64,\n                  height: 64,\n                  decoration: BoxDecoration(\n                    color: theme.colorScheme.primaryContainer,\n                    borderRadius: BorderRadius.circular(12),\n                  ),\n                  child: Icon(\n                    Icons.lock_open_rounded,\n                    color: theme.colorScheme.onPrimaryContainer,\n                    size: 30,\n                  ),\n                ),\n                const SizedBox(height: 18),\n                Semantics(\n                  header: true,\n                  child: Text(\n                    'Unlock your OMC workspace',\n                    textAlign: TextAlign.center,\n                    style: theme.textTheme.titleLarge?.copyWith(\n                      color: AppTheme.textPrimary,\n                    ),\n                  ),\n                ),\n                const SizedBox(height: 8),\n                Text(\n                  'Create an account to use $featureName, track services, manage documents and access payments.',\n                  textAlign: TextAlign.center,\n                  style: theme.textTheme.bodyLarge?.copyWith(\n                    color: AppTheme.textSecondary,\n                  ),\n                ),\n                const SizedBox(height: 22),\n                SizedBox(\n                  width: double.infinity,\n                  child: FilledButton(\n                    onPressed: () {\n                      Navigator.of(sheetContext).pop();\n                      context.push('/signup');\n                    },\n                    child: const Text('Create free account'),\n                  ),\n                ),\n                const SizedBox(height: 8),\n                SizedBox(\n                  width: double.infinity,\n                  child: TextButton(\n                    onPressed: () {\n                      Navigator.of(sheetContext).pop();\n                      context.push('/login');\n                    },\n                    child: const Text('Already have an account? Sign in'),\n                  ),\n                ),\n              ],\n            ),\n          ),\n        );\n      },\n    );\n"""
text = replace_once(text, old, new, 'E094 canonical sheet')
write(rel, text)

# Non-draggable dirty/controlled sheets must not advertise a drag affordance
# inherited from the global BottomSheetTheme.
rel = 'lib/features/leads/presentation/leads_screen.dart'
text = read(rel)
text = replace_once(
    text,
    """      isDismissible: false,\n      enableDrag: false,\n      builder: (sheetContext) {\n""",
    """      isDismissible: false,\n      enableDrag: false,\n      showDragHandle: false,\n      builder: (sheetContext) {\n""",
    'lead non-draggable sheet handle',
)
write(rel, text)

rel = 'lib/features/service_requests/presentation/operational_service_case_detail_screen.dart'
text = read(rel)
text = replace_once(
    text,
    """      isDismissible: false,\n      enableDrag: false,\n      builder: (_) => _OperationalDocumentUploadSheet(\n""",
    """      isDismissible: false,\n      enableDrag: false,\n      showDragHandle: false,\n      builder: (_) => _OperationalDocumentUploadSheet(\n""",
    'operational non-draggable sheet handle',
)
text = replace_once(
    text,
    """      child: Text(\n        label,\n        style: const TextStyle(\n          color: AppTheme.processing,\n          fontSize: 13,\n          height: 1.35,\n        ),\n      ),\n""",
    """      child: Text(\n        label,\n        style: Theme.of(context).textTheme.labelMedium?.copyWith(\n          color: AppTheme.processing,\n        ),\n      ),\n""",
    'operational workflow meta pill role',
)
write(rel, text)

# Permanent source checks for the final C4/C6 edge audit.
test_rel = 'test/app/uiux_final_modal_edges_contract_test.dart'
test = r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

String between(String text, String start, String end) {
  final a = text.indexOf(start);
  final b = text.indexOf(end, a + start.length);
  expect(a, greaterThanOrEqualTo(0));
  expect(b, greaterThan(a));
  return text.substring(a, b);
}

void main() {
  test('global sheet theme owns the canonical native handle and 24px shape', () {
    final theme = source('lib/app/theme.dart');
    expect(theme, contains('bottomSheetTheme: const BottomSheetThemeData'));
    expect(theme, contains('showDragHandle: true'));
    expect(theme, contains('top: Radius.circular(AppRadius.sheet)'));
  });

  test('E094 uses canonical sheet skin and runtime themed primary action', () {
    final home = source(
      'lib/features/home/presentation/home_screen_role_aware.dart',
    );
    final sheet = between(home, 'void _showGuestAccessSheet(', 'void _showLockedSnack(');

    expect(sheet, contains('useSafeArea: true'));
    expect(sheet, contains('isScrollControlled: true'));
    expect(sheet, contains('height * 0.90'));
    expect(sheet, contains("context.push('/signup')"));
    expect(sheet, contains("context.push('/login')"));
    expect(sheet, isNot(contains('backgroundColor: Colors.transparent')));
    expect(sheet, isNot(contains('BoxShadow(')));
    expect(sheet, isNot(contains('width: 42')));
    expect(sheet, isNot(contains('backgroundColor: AppTheme.primary')));
    expect(sheet, isNot(contains('BorderRadius.circular(28)')));
    expect(sheet, isNot(contains('BorderRadius.circular(22)')));
    expect(sheet, isNot(contains('BorderRadius.circular(17)')));
  });

  test('non-draggable live sheets explicitly hide inherited drag handles', () {
    final leads = source('lib/features/leads/presentation/leads_screen.dart');
    final operational = source(
      'lib/features/service_requests/presentation/operational_service_case_detail_screen.dart',
    );

    for (final text in [leads, operational]) {
      expect(text, contains('enableDrag: false'));
      expect(text, contains('showDragHandle: false'));
    }
  });

  test('operational hold/history/submission pills use status typography', () {
    final operational = source(
      'lib/features/service_requests/presentation/operational_service_case_detail_screen.dart',
    );
    final pill = between(operational, 'class _MetaPill', '\n}');
    expect(pill, contains('textTheme.labelMedium'));
    expect(pill, isNot(contains('fontSize: 13')));
  });
}
'''
write(test_rel, test)

print('Applied final modal/status edge closure.')
