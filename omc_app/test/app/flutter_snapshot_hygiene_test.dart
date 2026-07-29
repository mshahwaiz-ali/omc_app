import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter lib tree contains no historical source snapshots', () {
    final snapshots =
        Directory('lib')
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .map((file) => file.path)
            .where((path) => path.contains('.before_'))
            .toList()
          ..sort();

    expect(
      snapshots,
      isEmpty,
      reason:
          'Historical source snapshots must not be stored inside lib/. '
          'Use Git history instead.',
    );
  });
}
