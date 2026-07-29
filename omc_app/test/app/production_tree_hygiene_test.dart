import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter production tree contains no backup source snapshots', () {
    final libDirectory = Directory('lib');
    final snapshots =
        libDirectory
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
          'Historical source snapshots must not be tracked inside lib/. '
          'Use Git history instead.',
    );
  });
}
