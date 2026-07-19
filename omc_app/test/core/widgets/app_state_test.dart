import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/theme.dart';
import 'package:omc_app/core/network/api_error.dart';
import 'package:omc_app/core/widgets/app_state.dart';

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('empty state renders provided content', (tester) async {
    await tester.pumpWidget(
      _app(
        const AppEmptyState(
          title: 'No notifications yet',
          message: 'Updates about your services will appear here.',
        ),
      ),
    );

    expect(find.text('No notifications yet'), findsOneWidget);
    expect(
      find.text('Updates about your services will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets('error state maps raw error and offers retry', (tester) async {
    var retries = 0;

    await tester.pumpWidget(
      _app(
        AppErrorState.fromError(
          error: const ApiError(
            message: 'Internal traceback /srv/frappe/apps/private.py',
            statusCode: 503,
          ),
          onRetry: () => retries++,
        ),
      ),
    );

    expect(find.text('Service temporarily unavailable'), findsOneWidget);
    expect(find.textContaining('/srv/frappe'), findsNothing);

    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('non-retryable access error hides retry control', (tester) async {
    await tester.pumpWidget(
      _app(
        AppErrorState.fromError(
          error: const ApiError(message: 'Permission denied', statusCode: 403),
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('Access unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });
}
