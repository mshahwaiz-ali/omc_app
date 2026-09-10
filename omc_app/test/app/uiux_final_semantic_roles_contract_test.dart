import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('Home quick action labels use the C5 16px action role', () {
    final approved = source(
      'lib/features/home/presentation/approved_customer_home_actions.dart',
    );
    final guest = source(
      'lib/features/home/presentation/customer_guest_home_view.dart',
    );
    final internal = source(
      'lib/features/home/presentation/internal_home_view.dart',
    );

    expect(approved, contains('fontSize: 16'));
    expect(guest, contains('fontSize: 16'));
    expect(internal, contains('fontSize: 16'));
    expect(guest, contains('fontWeight: FontWeight.w400'));
  });

  test('Dashboard keeps timestamps caption-sized but promotes workflow state', () {
    final dashboard = source(
      'lib/features/dashboard/presentation/dashboard_screen.dart',
    );
    expect(dashboard, contains('textTheme.labelMedium'));
    expect(dashboard, contains('fontSize: 13'));
    expect(
      dashboard,
      isNot(contains("serviceCase.documentSummaryLabel.trim(),\n                      style: const TextStyle")),
    );
  });

  test('Alerts feed uses title, body, status and compact action roles', () {
    final alerts = source(
      'lib/features/notifications/presentation/notifications_screen.dart',
    );
    expect(alerts, contains('.titleMedium'));
    expect(alerts, contains('.bodyMedium'));
    expect(alerts, contains('.labelMedium'));
    expect(alerts, contains('fontSize: 14'));
    expect(alerts, isNot(contains("'Clear',\n                    style: TextStyle(\n                      color: Colors.white,\n                      fontSize: 13")));
  });

  test('Payment and upload guidance no longer use caption typography', () {
    final payment = source(
      'lib/features/payments/presentation/widgets/payment_action_card.dart',
    );
    final operational = source(
      'lib/features/service_requests/presentation/operational_service_case_detail_screen.dart',
    );
    final support = source(
      'lib/features/support/presentation/support_ticket_detail_legacy_screen.dart',
    );
    final preview = source(
      'lib/features/documents/presentation/document_preview_screen.dart',
    );

    expect(payment, contains('textTheme.titleMedium'));
    expect(payment, contains('textTheme.labelMedium'));
    expect(operational, contains("'PDF, JPG, JPEG, PNG, DOC or DOCX · maximum 10 MB'"));
    expect(support, contains("'PDF, JPG, PNG, DOC or DOCX · Maximum 10 MB'"));
    expect(preview, contains("'Pinch to zoom · drag to pan'"));

    for (final text in [operational, support, preview]) {
      expect(text, contains('fontSize: 14'));
    }
  });

  test('Tax rules and deadlines use the 14px status label role', () {
    final tax = source(
      'lib/features/tax_calculator/presentation/tax_calculator_screen.dart',
    );
    expect(tax, contains('textTheme.labelMedium'));
    expect(
      tax,
      isNot(contains("color: AppTheme.processing,\n                fontSize: 13")),
    );
  });

  test('Support conversation body stays at standard body weight', () {
    final detail = source(
      'lib/features/support/presentation/support_ticket_detail_legacy_screen.dart',
    );
    final hub = source(
      'lib/features/support/presentation/support_screen_legacy.dart',
    );
    expect(detail, contains('fontSize: 16'));
    expect(detail, contains('fontWeight: FontWeight.w400'));
    expect(hub, contains('fontSize: 15'));
    expect(hub, contains('fontWeight: FontWeight.w400'));
  });
}
