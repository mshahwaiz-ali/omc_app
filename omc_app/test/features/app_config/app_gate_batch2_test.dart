import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/app_config/application/app_gate_controller.dart';
import 'package:omc_app/features/app_config/application/app_gate_policy.dart';
import 'package:omc_app/features/app_config/data/mobile_app_config.dart';
import 'package:omc_app/features/app_config/data/mobile_app_config_repository.dart';
import 'package:omc_app/features/app_config/data/mobile_release_controls.dart';
import 'package:omc_app/features/app_config/presentation/app_readiness_gate.dart';

Map<String, dynamic> payload({
  bool maintenance = false,
  bool force = false,
  String minimum = '',
  bool features = true,
}) => {
  'features': {
    'guest_mode_enabled': features,
    'payments_enabled': features,
    'support_enabled': features,
    'expense_tracker_enabled': features,
    'knowledge_enabled': features,
    'tax_calculator_enabled': features,
    'internal_workspace_enabled': features,
  },
  'meta': {
    'maintenance_mode': maintenance,
    'force_update': force,
    'minimum_app_version': minimum,
  },
};

void main() {
  final now = DateTime.utc(2026, 9, 8, 12);
  MobileAppConfig config({
    bool maintenance = false,
    bool force = false,
    String minimum = '',
    bool features = true,
  }) => MobileAppConfig.fromApiResponse(
    payload(
      maintenance: maintenance,
      force: force,
      minimum: minimum,
      features: features,
    ),
    fetchedAt: now,
  );

  test(
    'fallback disables all business entry points and remains unavailable',
    () {
      final fallback = MobileAppConfig.fallback;
      expect(fallback.features.paymentsEnabled, isFalse);
      expect(fallback.features.supportEnabled, isFalse);
      expect(fallback.features.internalWorkspaceEnabled, isFalse);
      expect(fallback.features.expenseTrackerEnabled, isFalse);
      expect(fallback.features.guestModeEnabled, isFalse);
      expect(
        evaluateMobileGate(config: fallback, now: now).kind,
        AppGateKind.unavailable,
      );
    },
  );
  test('missing or malformed required control metadata is rejected', () {
    for (final raw in <Map<String, dynamic>>[
      {},
      {'features': {}},
      {'features': {}, 'meta': {}},
      {
        'features': {},
        'meta': {
          'maintenance_mode': 'maybe',
          'force_update': false,
          'minimum_app_version': '',
        },
      },
      payload(force: true),
      payload(minimum: '9.0'),
    ]) {
      expect(() => MobileAppConfig.fromApiResponse(raw), throwsFormatException);
    }
  });
  test('unknown feature values never enable access', () {
    final value = MobileFeatureConfig.fromJson({'payments_enabled': 'unknown'});
    expect(value.paymentsEnabled, isFalse);
    expect(value.knowledgeEnabled, isFalse);
  });
  test('support fallback marker does not replace valid controls', () {
    final raw = payload();
    (raw['meta'] as Map<String, dynamic>)['fallback'] = true;
    final value = MobileAppConfig.fromApiResponse(raw, fetchedAt: now);
    expect(value.isCurrentAt(now), isTrue);
    expect(value.isFallback, isTrue);
  });
  test('explicit blocking load remains blocked', () {
    expect(
      evaluateMobileGate(config: config(), now: now, loading: true).kind,
      AppGateKind.loading,
    );
  });
  test(
    'current config remains open while a background refresh is loading',
    () async {
      final firstConfig = MobileAppConfig.fromApiResponse(
        payload(),
        fetchedAt: DateTime.now().toUtc(),
      );
      final refreshedConfig = MobileAppConfig.fromApiResponse(
        payload(),
        fetchedAt: DateTime.now().toUtc(),
      );
      final refreshCompleter = Completer<MobileAppConfig>();
      var loadCount = 0;

      final container = ProviderContainer(
        overrides: [
          mobileAppConfigProvider.overrideWith((ref) async {
            loadCount += 1;
            if (loadCount == 1) {
              return firstConfig;
            }
            return refreshCompleter.future;
          }),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen<AppGateDecision>(
        appGateDecisionProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container.read(mobileAppConfigProvider.future);

      expect(container.read(appGateDecisionProvider).kind, AppGateKind.open);

      container.invalidate(mobileAppConfigProvider);
      await Future<void>.delayed(Duration.zero);

      final refreshing = container.read(mobileAppConfigProvider);

      expect(refreshing.isRefreshing, isTrue);
      expect(refreshing.value, same(firstConfig));
      expect(container.read(appGateDecisionProvider).kind, AppGateKind.open);

      refreshCompleter.complete(refreshedConfig);
      await container.read(mobileAppConfigProvider.future);

      expect(container.read(appGateDecisionProvider).kind, AppGateKind.open);
    },
  );

  test('expired enabled config cannot unlock normal usage', () {
    expect(
      evaluateMobileGate(
        config: config(),
        now: now.add(const Duration(minutes: 5)),
      ).kind,
      AppGateKind.unavailable,
    );
  });
  test('stale config disables features and cannot unlock usage', () {
    final stale = config().asStale();
    expect(stale.availability, MobileConfigAvailability.stale);
    expect(stale.features.paymentsEnabled, isFalse);
    expect(
      evaluateMobileGate(config: stale, now: now).kind,
      AppGateKind.unavailable,
    );
  });
  test('maintenance blocks every persona with no admin exception', () {
    expect(
      evaluateMobileGate(config: config(maintenance: true), now: now).kind,
      AppGateKind.maintenance,
    );
    expect(
      evaluateMobileGate(
        config: config(maintenance: true).asStale(),
        now: now,
      ).kind,
      AppGateKind.maintenance,
    );
  });
  test('numeric semantic comparison handles 9.10 versus 9.9', () {
    expect(
      evaluateMobileGate(
        config: config(minimum: '9.10.0', force: true),
        installedVersion: '9.9.0',
        now: now,
      ).kind,
      AppGateKind.forcedUpdate,
    );
  });
  test('build metadata is ignored but prerelease precedence is retained', () {
    expect(
      mobileSemanticVersion('9.0.0+13'),
      mobileSemanticVersion('9.0.0+999'),
    );
    expect(
      mobileSemanticVersion(
        '9.0.0-rc.1',
      ).compareTo(mobileSemanticVersion('9.0.0')),
      lessThan(0),
    );
    expect(
      evaluateMobileGate(
        config: config(minimum: '9.0.0+99', force: true),
        installedVersion: '9.0.0+13',
        now: now,
      ).kind,
      AppGateKind.open,
    );
  });
  test('invalid installed version cannot silently bypass minimum', () {
    expect(
      evaluateMobileGate(
        config: config(minimum: '9.0.0'),
        installedVersion: 'unknown',
        now: now,
      ).kind,
      AppGateKind.unavailable,
    );
  });
  test('optional update is dismissible; forced update ignores dismissal', () {
    expect(
      evaluateMobileGate(
        config: config(minimum: '10.0.0'),
        installedVersion: '9.0.0',
        now: now,
      ).kind,
      AppGateKind.recommendedUpdate,
    );
    expect(
      evaluateMobileGate(
        config: config(minimum: '10.0.0'),
        installedVersion: '9.0.0',
        now: now,
        optionalUpdateSuppressed: true,
      ).kind,
      AppGateKind.open,
    );
    expect(
      evaluateMobileGate(
        config: config(minimum: '10.0.0', force: true),
        installedVersion: '9.0.0',
        now: now,
        optionalUpdateSuppressed: true,
      ).kind,
      AppGateKind.forcedUpdate,
    );
  });
  test('dismissal expires at 24h and rejects future timestamps', () {
    expect(optionalUpdateSuppressedAt(now.millisecondsSinceEpoch, now), isTrue);
    expect(
      optionalUpdateSuppressedAt(
        now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch,
        now,
      ),
      isFalse,
    );
    expect(
      optionalUpdateSuppressedAt(
        now.add(const Duration(seconds: 1)).millisecondsSinceEpoch,
        now,
      ),
      isFalse,
    );
    expect(updateDismissalPair('9.0.0+13', '10.0.0'), '9.0.0|10.0.0');
    expect(
      updateDismissalPair('9.0.0', '10.0.0'),
      isNot(updateDismissalPair('9.0.0', '10.1.0')),
    );
  });
  test('direct/restored feature routes use the same availability policy', () {
    for (final route in [
      '/payments/PAY-1',
      '/expense-tracker',
      '/expense-budget',
      '/tax-calculator/history',
      '/knowledge/ARTICLE-1',
      '/support-tickets/T-1',
      '/internal-workspace/service-cases/CASE-1',
      '/tasks/TASK-1',
      '/customers/C-1',
      '/leads/L-1',
    ]) {
      expect(
        mobileFeatureRouteEnabled(route, const MobileFeatureConfig()),
        isFalse,
        reason: route,
      );
      expect(
        mobileFeatureRouteEnabled(route, config().features),
        isTrue,
        reason: route,
      );
    }
    expect(
      mobileFeatureRouteEnabled(
        '/home',
        const MobileFeatureConfig(),
        guest: true,
      ),
      isFalse,
    );
    expect(
      mobileFeatureRouteEnabled(
        '/login',
        const MobileFeatureConfig(),
        guest: true,
      ),
      isTrue,
    );
  });
  testWidgets('mandatory gate offers no continue action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppGatePanel(
          decision: const AppGateDecision(
            AppGateKind.forcedUpdate,
            minimumVersion: '10.0.0',
          ),
          onRetry: () {},
          onUpdate: () {},
          onDismissUpdate: () {},
        ),
      ),
    );
    expect(find.text('Continue for now'), findsNothing);
    expect(find.text('Open Google Play'), findsOneWidget);
  });
  testWidgets('gate retains form state and blocks interaction behind it', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Unsaved draft');
    addTearDown(controller.dispose);
    var pressed = 0;
    Widget app(bool blocked) => MaterialApp(
      home: MobileReadinessOverlay(
        blocked: blocked,
        panel: const Material(child: Center(child: Text('Blocked'))),
        child: Scaffold(
          body: Column(
            children: [
              TextField(controller: controller),
              TextButton(
                onPressed: () => pressed++,
                child: const Text('Submit draft'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(true));
    await tester.tap(find.text('Submit draft'), warnIfMissed: false);
    expect(pressed, 0);
    await tester.pumpWidget(app(false));
    expect(controller.text, 'Unsaved draft');
    await tester.tap(find.text('Submit draft'));
    expect(pressed, 1);
  });
}
