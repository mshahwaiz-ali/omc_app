import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remaining async audit findings are intentionally handled', () {
    final login = File(
      'lib/features/auth/presentation/login_screen.dart',
    ).readAsStringSync();
    final authController = File(
      'lib/features/auth/application/auth_controller.dart',
    ).readAsStringSync();
    final onboarding = File(
      'lib/features/onboarding/presentation/onboarding_screen.dart',
    ).readAsStringSync();
    final onboardingRepository = File(
      'lib/features/onboarding/data/onboarding_repository.dart',
    ).readAsStringSync();
    final workspaceProviders = File(
      'lib/features/internal_workspace/presentation/'
      'internal_workspace_providers.dart',
    ).readAsStringSync();
    final workspaceScreen = File(
      'lib/features/internal_workspace/presentation/'
      'internal_workspace_screen.dart',
    ).readAsStringSync();

    // Login is synchronous Notifier state, not AsyncValue.
    expect(
      authController,
      contains('NotifierProvider<AuthController, AuthState>'),
    );
    expect(login, contains('ref.watch(authControllerProvider)'));
    expect(login, contains('AuthErrorBanner'));
    expect(login, contains('authState.message'));
    expect(login, isNot(contains('AsyncValue')));

    // Onboarding intentionally remains usable with local fallback slides.
    expect(onboarding, contains('OnboardingSlide.fallbackSlides'));
    expect(onboarding, contains('AppFailureClassifier.classify'));
    expect(onboarding, contains('ScaffoldMessenger.of'));
    expect(onboarding, contains('_isFinishing = false'));
    expect(
      onboardingRepository,
      contains('return OnboardingSlide.fallbackSlides'),
    );

    // Session-owned provider declarations dispose between personas and are
    // backed by explicit screen recovery.
    expect(
      workspaceProviders,
      contains('FutureProvider.autoDispose<InternalWorkspaceSummary>'),
    );
    expect(
      workspaceProviders,
      contains('FutureProvider.autoDispose<InternalServiceCaseQueue>'),
    );
    expect(workspaceScreen, contains('summaryAsync.when('));
    expect(workspaceScreen, contains('queueAsync.when('));
    expect(workspaceScreen, contains('error:'));
    expect(workspaceScreen, contains('onRetry:'));
    expect(
      workspaceScreen,
      contains('ref.invalidate(internalWorkspaceSummaryProvider)'),
    );
    expect(
      workspaceScreen,
      contains('ref.invalidate(internalServiceCasesProvider)'),
    );
  });
}
