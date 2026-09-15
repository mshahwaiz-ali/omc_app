import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final dispatcher = File(
    'lib/features/home/presentation/home_screen_dispatcher.dart',
  ).readAsStringSync();
  final view = File(
    'lib/features/home/presentation/approved_customer_home_view.dart',
  ).readAsStringSync();
  final service = File(
    'lib/features/home/presentation/approved_customer_home_service_widgets.dart',
  ).readAsStringSync();
  final support = File(
    'lib/features/home/presentation/approved_customer_home_support.dart',
  ).readAsStringSync();

  test('approved customer home remains the lifecycle customer owner', () {
    expect(dispatcher, contains('ApprovedCustomerHomeView('));
    expect(dispatcher, contains('useLifecycleCustomerHome'));
  });

  test('approved home uses responsive V2 page insets and bounded width', () {
    expect(view, contains('class _CustomerHomeListView'));
    expect(view, contains('AppLayout.pageInsetFor(constraints.maxWidth)'));
    expect(view, contains('AppLayout.generalMaxWidth'));
    expect(view, contains('child: _CustomerHomeListView('));
    expect(view, contains('return _CustomerHomeListView('));
    expect(
      view,
      isNot(
        contains(
          'padding: const EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl)',
        ),
      ),
    );
    expect(support, contains('return const _CustomerHomeListView('));
  });

  test('approved home separates attention work into a manual carousel', () {
    expect(view, contains('.where((service) => service.actionRequired)'));
    expect(view, contains('.where((service) => !service.actionRequired)'));
    expect(
      view,
      contains('_AttentionServiceCarousel(services: attentionServices)'),
    );
    expect(
      service,
      contains('class _AttentionServiceCarousel extends StatefulWidget'),
    );
    expect(service, contains('onHorizontalDragEnd: _onHorizontalDragEnd'));
    expect(service, contains("'Previous service'"));
    expect(service, contains("'Next service'"));
    expect(service, contains(r"'${currentIndex + 1} of $count'"));
    expect(service, isNot(contains('Timer.periodic')));
  });

  test(
    'approved home live cards use the V2 badge, spacing and radius tokens',
    () {
      expect(service, contains('fontSize: 11'));
      expect(service, isNot(contains('fontSize: 10,')));
      expect(service, contains('padding: const EdgeInsets.all(AppSpacing.lg)'));
      expect(service, contains('padding: const EdgeInsets.all(AppSpacing.md)'));
      expect(service, contains('BorderRadius.circular(AppRadius.control)'));
      expect(service, contains('BorderRadius.circular(AppRadius.pill)'));
      expect(support, contains('BorderRadius.circular(AppRadius.card)'));
      expect(support, isNot(contains('BorderRadius.circular(22)')));
    },
  );
}
