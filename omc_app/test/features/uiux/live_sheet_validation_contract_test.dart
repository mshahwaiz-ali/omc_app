import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live profile and settings sheets use persistent inline validation', () {
    final profile = File(
      'lib/features/profile/presentation/profile_v2_screen.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/settings/presentation/settings_v2_screen.dart',
    ).readAsStringSync();

    expect(profile, contains("label: 'How can OMC help?'"));
    expect(profile, contains("return 'Enter at least 10 characters.';"));
    expect(profile, isNot(contains("labelText: 'How can OMC help?'")));

    expect(settings, contains("label: 'Current password'"));
    expect(settings, contains("'Current password is required.'"));
    expect(settings, contains("label: widget.label"));
    expect(settings, contains("'Enter a reason or instruction.'"));
    expect(settings, isNot(contains("labelText: 'Current password'")));
    expect(settings, isNot(contains('labelText: label')));
  });
}
