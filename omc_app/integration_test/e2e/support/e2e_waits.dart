import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/diagnostics/e2e_network_audit.dart';
import 'package:omc_app/core/diagnostics/omc_widget_keys.dart';

class E2eWaits {
  E2eWaits(this.tester);

  final WidgetTester tester;

  Future<void> waitFor(
    Finder finder, {
    required String description,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      _failOnFrameworkException(description);
    }

    if (finder.evaluate().isEmpty) {
      fail('$description did not render within ${timeout.inSeconds}s.');
    }
  }

  Future<String> waitForAny(
    Map<String, Finder> candidates, {
    required String description,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      for (final candidate in candidates.entries) {
        if (candidate.value.evaluate().isNotEmpty) return candidate.key;
      }
      await tester.pump(const Duration(milliseconds: 100));
      _failOnFrameworkException(description);
    }

    fail(
      '$description did not reach any expected state within '
      '${timeout.inSeconds}s: ${candidates.keys.join(', ')}.',
    );
  }

  Future<void> tapAndWait({
    required Finder target,
    required Finder destination,
    required String description,
  }) async {
    await waitFor(target, description: '$description: action');
    await tester.ensureVisible(target);
    await tester.pump(const Duration(milliseconds: 100));
    final hitTarget = target.hitTestable();
    if (hitTarget.evaluate().isEmpty) {
      fail('$description: action rendered but was not tappable.');
    }
    await tester.tap(hitTarget.first);
    await tester.pump();
    await waitForScreen(destination, description: description);
  }

  Future<void> waitForScreen(
    Finder screen, {
    required String description,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await waitFor(screen, description: description, timeout: timeout);
    await waitForNetworkIdle(description: description, timeout: timeout);
    await _waitForBlockingProgress(description: description, timeout: timeout);
    await _boundedSettle(description);
    assertHealthy(description);
  }

  Future<void> waitForNetworkIdle({
    required String description,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    var idlePumps = 0;

    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      _failOnFrameworkException(description);
      if (E2eNetworkAudit.pendingRequestCount == 0) {
        idlePumps++;
        if (idlePumps >= 5) return;
      } else {
        idlePumps = 0;
      }
    }

    final pending = E2eNetworkAudit.pendingRequests.join(', ');
    fail(
      '$description did not become network-idle within ${timeout.inSeconds}s. '
      'Pending requests: ${pending.isEmpty ? 'unknown' : pending}.',
    );
  }

  void assertHealthy(String description) {
    _failOnFrameworkException(description);

    if (find.byKey(OmcWidgetKeys.routeFailure).evaluate().isNotEmpty) {
      fail('$description rendered the unexpected RouteFailureScreen.');
    }
    if (find.byKey(OmcWidgetKeys.startupError).evaluate().isNotEmpty) {
      fail('$description rendered the app startup failure screen.');
    }
    if (find.byKey(OmcWidgetKeys.appError).evaluate().isNotEmpty) {
      fail('$description rendered an app-level error state.');
    }
    if (find.byKey(OmcWidgetKeys.loginError).evaluate().isNotEmpty) {
      fail('$description rendered an authentication error.');
    }

    final snackbars = find.byType(SnackBar);
    if (snackbars.evaluate().isNotEmpty) {
      final messages = find
          .descendant(of: snackbars, matching: find.byType(Text))
          .evaluate()
          .map((element) => element.widget)
          .whereType<Text>()
          .map((widget) => widget.data)
          .whereType<String>()
          .where((message) => message.trim().isNotEmpty)
          .join(' | ');
      fail(
        '$description displayed an unexpected snackbar'
        '${messages.isEmpty ? '.' : ': $messages'}',
      );
    }

    final failures = E2eNetworkAudit.failures;
    if (failures.isNotEmpty) {
      fail(
        'Unexpected API response during $description: '
        '${failures.join(', ')}',
      );
    }
  }

  Future<void> _waitForBlockingProgress({
    required String description,
    required Duration timeout,
  }) async {
    final deadline = DateTime.now().add(timeout);
    final progress = find.byType(CircularProgressIndicator);
    while (progress.evaluate().isNotEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      _failOnFrameworkException(description);
    }
    if (progress.evaluate().isNotEmpty) {
      fail(
        '$description still showed a blocking progress indicator after '
        '${timeout.inSeconds}s.',
      );
    }
  }

  Future<void> _boundedSettle(String description) async {
    var quietPumps = 0;
    for (var pump = 0; pump < 30; pump++) {
      await tester.pump(const Duration(milliseconds: 100));
      _failOnFrameworkException(description);
      if (tester.binding.hasScheduledFrame) {
        quietPumps = 0;
      } else {
        quietPumps++;
        if (quietPumps >= 3) return;
      }
    }
  }

  void _failOnFrameworkException(String description) {
    final exceptions = <Object>[];
    Object? exception;
    while ((exception = tester.takeException()) != null) {
      exceptions.add(exception!);
    }
    if (exceptions.isNotEmpty) {
      fail(
        '$description raised a Flutter exception: ${exceptions.join(' | ')}',
      );
    }
  }
}
