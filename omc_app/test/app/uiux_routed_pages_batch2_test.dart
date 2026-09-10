import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

String block(String source, String start, String end) {
  final a = source.indexOf(start);
  final b = source.indexOf(end, a + start.length);
  expect(a, greaterThanOrEqualTo(0), reason: 'missing $start');
  expect(b, greaterThan(a), reason: 'missing $end');
  return source.substring(a, b);
}

void main() {
  test('shared V2 primitives cover scrolling and non-scrolling page roots', () {
    final source = read('lib/core/widgets/omc_premium.dart');
    expect(source, contains('class OmcPageListView extends StatelessWidget'));
    expect(source, contains('class OmcPagePadding extends StatelessWidget'));
    expect(
      'AppLayout.pageInsetFor(constraints.maxWidth)'.allMatches(source).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      '(constraints.maxWidth - maxWidth) / 2'.allMatches(source).length,
      greaterThanOrEqualTo(2),
    );
  });

  test('routed profile and settings owners use responsive roots', () {
    final router = read('lib/app/router.dart');
    final profile = read(
      'lib/features/profile/presentation/profile_v2_screen.dart',
    );
    final edit = read(
      'lib/features/profile/presentation/edit_profile_v2_screen.dart',
    );
    final settings = read(
      'lib/features/settings/presentation/settings_v2_screen.dart',
    );
    final password = read(
      'lib/features/settings/presentation/change_password_screen.dart',
    );
    expect(router, contains('const ProfileV2Screen()'));
    expect(router, contains('const EditProfileV2Screen()'));
    expect(router, contains('const SettingsV2Screen()'));
    expect(router, contains('const ChangePasswordScreen()'));
    expect(
      'OmcPageListView('.allMatches(profile).length,
      greaterThanOrEqualTo(3),
    );
    expect('OmcPageListView('.allMatches(edit).length, greaterThanOrEqualTo(2));
    expect('OmcPagePadding('.allMatches(edit).length, greaterThanOrEqualTo(2));
    expect(settings, contains('child: OmcPageListView('));
    expect(
      password,
      contains('AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width)'),
    );
  });

  test('routed customer directory and detail use C2 roots', () {
    final router = read('lib/app/router.dart');
    final customers = read(
      'lib/features/customers/presentation/customers_screen.dart',
    );
    final detail = read(
      'lib/features/customers/presentation/customer_detail_screen.dart',
    );
    expect(router, contains('const CustomersScreen()'));
    expect(router, contains('CustomerDetailScreen(customerId: customerId)'));
    expect(
      'OmcPageListView('.allMatches(customers).length,
      greaterThanOrEqualTo(3),
    );
    expect(detail, contains('return OmcPageListView('));
    expect(
      customers,
      isNot(contains('padding: const EdgeInsets.fromLTRB(20, 12, 20, 40)')),
    );
    expect(
      detail,
      isNot(contains('padding: const EdgeInsets.fromLTRB(20, 16, 20, 40)')),
    );
  });

  test(
    'routed document list and detail use responsive roots and bounded icons',
    () {
      final router = read('lib/app/router.dart');
      final documents = read(
        'lib/features/documents/presentation/documents_screen.dart',
      );
      final detail = read(
        'lib/features/documents/presentation/document_detail_screen.dart',
      );
      expect(router, contains('const DocumentsScreen()'));
      expect(router, contains('DocumentDetailScreen('));
      expect(
        'OmcPageListView('.allMatches(documents).length,
        greaterThanOrEqualTo(3),
      );
      expect(
        'OmcPageListView('.allMatches(detail).length,
        greaterThanOrEqualTo(2),
      );
      expect(
        'OmcPagePadding('.allMatches(detail).length,
        greaterThanOrEqualTo(2),
      );
      final filtered = block(
        documents,
        'class _FilteredEmptyView',
        'class _EmptyDocumentsView',
      );
      final empty = block(
        documents,
        'class _EmptyDocumentsView',
        'class _DocumentsErrorView',
      );
      expect(filtered, contains('size: 32'));
      expect(empty, contains('size: 32'));
      expect(filtered, isNot(contains('size: 36')));
      expect(empty, isNot(contains('size: 40')));
    },
  );

  test('routed notification detail uses responsive data and state roots', () {
    final router = read('lib/app/router.dart');
    final source = read(
      'lib/features/notifications/presentation/notification_detail_screen.dart',
    );
    expect(
      router,
      contains('NotificationDetailScreen(notificationId: notificationId)'),
    );
    expect(
      'OmcPageListView('.allMatches(source).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      'OmcPagePadding('.allMatches(source).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      source,
      isNot(contains('padding: const EdgeInsets.fromLTRB(20, 14, 20, 36)')),
    );
  });
}
