import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification repository requests a bounded first page', () {
    final source = File(
      'lib/features/notifications/data/notifications_repository.dart',
    ).readAsStringSync();

    expect(source, contains("'start': 0"));
    expect(source, contains("'limit': 50"));
    expect(source, contains('queryParameters: const'));
  });

  test('repository keeps backward-compatible list parsing', () {
    final source = File(
      'lib/features/notifications/data/notifications_repository.dart',
    ).readAsStringSync();

    expect(source, contains("message['notifications']"));
    expect(source, contains("data['notifications']"));
  });
}
