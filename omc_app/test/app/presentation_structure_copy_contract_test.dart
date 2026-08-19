import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('active customer presentation structure', () {
    test('keeps customer home entrypoint focused', () {
      final file = File(
        'lib/features/home/presentation/approved_customer_home_view.dart',
      );
      final source = file.readAsStringSync();

      expect(file.lengthSync(), lessThan(12000));
      expect(source, contains("part 'approved_customer_home_actions.dart';"));
      expect(
        source,
        contains("part 'approved_customer_home_service_widgets.dart';"),
      );
      expect(source, contains("part 'approved_customer_home_support.dart';"));
    });

    test('keeps customer service detail entrypoint focused', () {
      final file = File(
        'lib/features/service_requests/presentation/customer_service_case_detail_screen.dart',
      );
      final source = file.readAsStringSync();

      expect(file.lengthSync(), lessThan(12000));
      expect(
        source,
        contains("part 'customer_service_case_detail_evidence.dart';"),
      );
      expect(
        source,
        contains("part 'customer_service_case_detail_sections.dart';"),
      );
      expect(
        source,
        contains("part 'customer_service_case_detail_support.dart';"),
      );
    });

    test('keeps request draft controller separate from presentation sections', () {
      final file = File(
        'lib/features/service_requests/presentation/service_request_draft_screen.dart',
      );
      final source = file.readAsStringSync();

      expect(file.lengthSync(), lessThan(30000));
      expect(
        source,
        contains("part 'service_request_draft_form_sections.dart';"),
      );
      expect(
        source,
        contains("part 'service_request_draft_service_sections.dart';"),
      );
    });
  });

  group('user-facing terminology', () {
    test('customer request surfaces avoid implementation jargon', () {
      final source = [
        'lib/features/service_requests/presentation/customer_service_case_detail_screen.dart',
        'lib/features/service_requests/presentation/customer_service_case_detail_sections.dart',
        'lib/features/service_requests/presentation/customer_service_case_detail_evidence.dart',
        'lib/features/service_requests/presentation/customer_service_case_detail_support.dart',
        'lib/features/home/presentation/approved_customer_home_view.dart',
        'lib/features/home/presentation/approved_customer_home_actions.dart',
        'lib/features/home/presentation/approved_customer_home_service_widgets.dart',
        'lib/features/home/presentation/approved_customer_home_support.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n').toLowerCase();

      expect(source, isNot(contains('frappe desk')));
      expect(source, isNot(contains('erpnext')));
      expect(source, isNot(contains('payment evidence')));
      expect(source, isNot(contains('backend still considers')));
    });

    test('administration copy avoids platform implementation names', () {
      final source = File(
        'lib/features/admin_control/presentation/admin_control_screen.dart',
      ).readAsStringSync().toLowerCase();

      expect(source, isNot(contains('frappe desk')));
      expect(source, isNot(contains('erpnext roles')));
      expect(source, isNot(contains('system user full name')));
      expect(source, isNot(contains('system user email')));
      expect(source, isNot(contains('backend configuration contract')));
    });
  });
}
