import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/design_tokens.dart';
import 'package:omc_app/app/theme.dart';

void main() {
  testWidgets('themed buttons remain finite inside a bounded row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SizedBox(
            width: 480,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(onPressed: () {}, child: const Text('Filter')),
                FilledButton(onPressed: () {}, child: const Text('Apply')),
                ElevatedButton(onPressed: () {}, child: const Text('Save')),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    for (final finder in <Finder>[
      find.byType(OutlinedButton),
      find.byType(FilledButton),
      find.byType(ElevatedButton),
    ]) {
      final size = tester.getSize(finder);
      expect(size.width.isFinite, isTrue);
      expect(size.width, greaterThanOrEqualTo(AppTouchTarget.minimum));
    }
  });

  test('runtime accent theme keeps finite button minimum widths', () {
    final source = File('lib/app/app.dart').readAsStringSync();
    expect(source, isNot(contains('minimumSize: const Size.fromHeight')));
    expect(
      RegExp(r'minimumSize: const Size\(\s*AppTouchTarget\.minimum,')
          .allMatches(source)
          .length,
      greaterThanOrEqualTo(3),
    );
  });
}
