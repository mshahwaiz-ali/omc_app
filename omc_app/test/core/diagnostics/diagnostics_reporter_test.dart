import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/diagnostics/diagnostics_reporter.dart';

void main() {
  test('scrubs OMC identity, auth and secret query values', () {
    final scrubbed = DiagnosticsReporter.scrubText(
      'user boss@example.com CNIC 35202-1234567-1 phone +923001234567 '
      'Authorization=Bearer123 https://erp.omchouse.com/app/reset?token=abc',
    );

    expect(scrubbed, isNot(contains('boss@example.com')));
    expect(scrubbed, isNot(contains('35202-1234567-1')));
    expect(scrubbed, isNot(contains('+923001234567')));
    expect(scrubbed, isNot(contains('Bearer123')));
    expect(scrubbed, isNot(contains('token=abc')));
  });
}
