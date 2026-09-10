import 'dart:io';

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
