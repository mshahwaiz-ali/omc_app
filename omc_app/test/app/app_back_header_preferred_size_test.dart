import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omc_app/app/theme.dart';
import 'package:omc_app/core/widgets/app_back_header.dart';

void _setView(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpHeader(
  WidgetTester tester, {
  required AppBackHeader header,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            Scaffold(appBar: header, body: const SizedBox()),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('subtitle header reserves its complete measured height', (
    tester,
  ) async {
    _setView(tester, 430);

    await _pumpHeader(
      tester,
      header: AppBackHeader(
        title: 'Service Details',
        subtitle: 'Review requirements and start service',
        actionIcon: Icons.support_agent_outlined,
        actionTooltip: 'Support',
        onAction: () {},
      ),
    );

    expect(find.text('Service Details'), findsOneWidget);
    expect(find.text('Review requirements and start service'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plain header still satisfies the minimum touch row', (
    tester,
  ) async {
    _setView(tester, 320);

    await _pumpHeader(
      tester,
      header: const AppBackHeader(title: 'Task details'),
    );

    expect(find.text('Task details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
