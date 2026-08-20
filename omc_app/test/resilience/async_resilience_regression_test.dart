import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Batch E async resilience contract remains intact', () {
    final taskDetail = File(
      'lib/features/tasks/presentation/task_detail_screen.dart',
    ).readAsStringSync();
    final home = File(
      'lib/features/home/presentation/home_screen_role_aware.dart',
    ).readAsStringSync();
    final customerHome = File(
      'lib/features/home/presentation/customer_guest_home_view.dart',
    ).readAsStringSync();
    final internalHome = File(
      'lib/features/home/presentation/internal_home_view.dart',
    ).readAsStringSync();
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
    final workspace = File(
      'lib/features/internal_workspace/presentation/'
      'internal_workspace_screen.dart',
    ).readAsStringSync();

    final appState = File('lib/core/widgets/app_state.dart').readAsStringSync();

    // E1: task-detail failures remain recoverable through shared error state.
    expect(taskDetail, contains('AppErrorState.fromError('));
    expect(
      taskDetail,
      contains('ref.invalidate(taskDetailProvider(widget.taskId))'),
    );
    expect(taskDetail, contains("fallbackTitle: 'Task unavailable'"));
    expect(appState, contains("this.retryLabel = 'Try again'"));

    // E2: Home failures stay visible without replacing usable content.
    expect(home, contains('dashboardAsync.hasError'));
    expect(home, contains('quickActionsAsync.hasError'));
    expect(home, contains('final homeLoadMessage ='));
    expect(home, contains('void retryHomeLoad()'));
    expect(home, contains('onRetryHomeLoad: retryHomeLoad'));
    expect(customerHome, contains('final String? loadMessage;'));
    expect(customerHome, contains('message: loadMessage!'));
    expect(customerHome, contains('Try again'));
    expect(internalHome, contains('final String? loadMessage;'));
    expect(internalHome, contains('message: loadMessage!'));
    expect(internalHome, contains('Try again'));

    // E3: intentional non-AsyncValue state handling remains explicit.
    expect(
      authController,
      contains('NotifierProvider<AuthController, AuthState>'),
    );
    expect(login, contains('AuthErrorBanner'));
    expect(login, contains('authState.message'));
    expect(login, isNot(contains('AsyncValue')));

    expect(onboarding, contains('OnboardingSlide.fallbackSlides'));
    expect(onboarding, contains('AppFailureClassifier.classify'));
    expect(onboarding, contains('_isFinishing = false'));
    expect(
      onboardingRepository,
      contains('return OnboardingSlide.fallbackSlides'),
    );

    expect(workspace, contains('summaryAsync.when('));
    expect(workspace, contains('queueAsync.when('));
    expect(workspace, contains('error:'));
    expect(workspace, contains('onRetry:'));
    expect(
      workspace,
      contains('ref.invalidate(internalWorkspaceSummaryProvider)'),
    );
    expect(workspace, contains('ref.invalidate(internalServiceCasesProvider)'));
  });
}
