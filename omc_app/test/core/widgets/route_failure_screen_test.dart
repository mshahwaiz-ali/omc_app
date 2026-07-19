import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/widgets/route_failure_screen.dart';

void main() {
  testWidgets('route failure screen exposes safe recovery actions', (
    tester,
  ) async {
    var wentHome = false;
    var wentBack = false;

    await tester.pumpWidget(
      MaterialApp(
        home: RouteFailureScreen(
          onGoHome: () => wentHome = true,
          onGoBack: () => wentBack = true,
        ),
      ),
    );

    expect(find.text('Page unavailable'), findsOneWidget);
    expect(find.textContaining('invalid, expired'), findsOneWidget);
    expect(find.text('Go to home'), findsOneWidget);
    expect(find.text('Go back'), findsOneWidget);

    await tester.tap(find.text('Go to home'));
    await tester.tap(find.text('Go back'));

    expect(wentHome, isTrue);
    expect(wentBack, isTrue);
  });

  testWidgets('route failure screen hides back action when unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: RouteFailureScreen(onGoHome: () {})),
    );

    expect(find.text('Go to home'), findsOneWidget);
    expect(find.text('Go back'), findsNothing);
  });
}
