// ignore_for_file: experimental_member_use

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/api_config.dart';
import '../config/env.dart';

class DiagnosticsReporter {
  const DiagnosticsReporter._();

  static Future<void> run(AppRunner appRunner) async {
    if (!kReleaseMode || !Env.isProduction) {
      appRunner();
      return;
    }

    await SentryFlutter.init((options) {
      options
        ..dsn = ApiConfig.sentryDsn
        ..environment = 'production'
        ..sendDefaultPii = false
        ..tracesSampleRate = 0
        ..profilesSampleRate = 0
        ..maxRequestBodySize = MaxRequestBodySize.never
        ..attachScreenshot = false
        ..attachViewHierarchy = false
        ..enableAutoNativeBreadcrumbs = false
        ..enableUserInteractionBreadcrumbs = false
        ..enablePrintBreadcrumbs = false
        ..enableAppLifecycleBreadcrumbs = false
        ..enableWindowMetricBreadcrumbs = false
        ..enableBrightnessChangeBreadcrumbs = false
        ..enableTextScaleChangeBreadcrumbs = false
        ..enableMemoryPressureBreadcrumbs = false
        ..reportSilentFlutterErrors = false
        ..beforeSend = _scrubEvent;
      options.replay
        ..sessionSampleRate = 0
        ..onErrorSampleRate = 0;
    }, appRunner: appRunner);
  }

  @visibleForTesting
  static String scrubText(String input) {
    var value = input;
    value = value.replaceAll(
      RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
      '[redacted-email]',
    );
    value = value.replaceAll(
      RegExp(r'(?<!\d)\d{5}-?\d{7}-?\d(?!\d)'),
      '[redacted-cnic]',
    );
    value = value.replaceAll(
      RegExp(
        r'(token|authorization|cookie|password|secret|api[_-]?key)(\s*[:=]\s*)[^\s&]+',
        caseSensitive: false,
      ),
      r'$1$2[redacted]',
    );
    value = value.replaceAll(
      RegExp(r'([?&](?:token|key|code)=)[^&#\s]+', caseSensitive: false),
      r'$1[redacted]',
    );
    value = value.replaceAll(
      RegExp(r'(?<!\d)(?:\+?92|0)?3\d{9}(?!\d)'),
      '[redacted-phone]',
    );
    return value;
  }

  static SentryEvent _scrubEvent(SentryEvent event, Hint hint) {
    final safeExceptions = event.exceptions
        ?.map(
          (exception) => SentryException(
            type: exception.type,
            value: scrubText(exception.value ?? exception.type ?? 'App error'),
            module: exception.module,
            stackTrace: exception.stackTrace,
            mechanism: exception.mechanism,
            threadId: exception.threadId,
          ),
        )
        .toList(growable: false);
    final safeMessage = event.message == null
        ? null
        : SentryMessage(scrubText(event.message!.formatted));

    return SentryEvent(
      eventId: event.eventId,
      timestamp: event.timestamp,
      platform: event.platform,
      release: event.release,
      dist: event.dist,
      environment: 'production',
      message: safeMessage,
      level: event.level,
      exceptions: safeExceptions,
      fingerprint: event.fingerprint,
      modules: event.modules,
      debugMeta: event.debugMeta,
    );
  }
}
