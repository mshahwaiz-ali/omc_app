import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remaining UI mutations stay guarded and recoverable', () {
    final mainShell = File('lib/app/main_shell.dart').readAsStringSync();
    final shellNav = File('lib/app/shell_nav_scaffold.dart').readAsStringSync();
    final support = File(
      'lib/features/support/presentation/'
      'support_ticket_detail_screen.dart',
    ).readAsStringSync();
    final documents = File(
      'lib/features/documents/presentation/'
      'internal_document_review_screen.dart',
    ).readAsStringSync();
    final notifications = File(
      'lib/features/notifications/presentation/'
      'notifications_screen.dart',
    ).readAsStringSync();

    expect(mainShell, contains('bool _isLoggingOut = false;'));
    expect(mainShell, contains("fallbackTitle: 'Logout incomplete'"));
    expect(mainShell, contains('if (_isLoggingOut) return;'));

    expect(shellNav, contains('_shellLogoutInFlight'));
    expect(shellNav, contains("fallbackTitle: 'Logout incomplete'"));

    expect(support, contains('if (!mounted) return;'));
    expect(support, contains('final file = result?.files.single;'));

    expect(
      documents,
      contains('if (!mounted || _busyDocumentId != null) return;'),
    );

    expect(notifications, contains('final Set<String> _mutationIds'));
    expect(notifications, contains('if (_mutationIds.contains(item.id))'));
    expect(notifications, contains('_mutationIds.remove(item.id)'));
  });
}
