import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('analysis options do not globally suppress dead-code diagnostics', () {
    final source = File('analysis_options.yaml').readAsStringSync();

    expect(source, isNot(contains('unused_element_parameter: ignore')));
    expect(
      source,
      isNot(
        contains(
          RegExp(
            r'^\s*unused_element_parameter\s*:\s*ignore\s*$',
            multiLine: true,
          ),
        ),
      ),
      reason:
          'Unused element parameters must be fixed or suppressed narrowly at '
          'the exact intentional site.',
    );
  });
}
