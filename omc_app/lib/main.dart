import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/api_config.dart';
import 'core/push/firebase_push_source.dart';
import 'core/push/push_registration.dart';
import 'core/diagnostics/diagnostics_reporter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Color(0xFFE5E7EB),
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  ApiConfig.validateBuildProfile();

  await DiagnosticsReporter.run(() async {
    PushTokenSource source = const UnavailablePushTokenSource();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final firebase = FirebasePushSource();
      await firebase.initialize().timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
      source = firebase;
    }
    runApp(
      ProviderScope(
        overrides: [pushTokenSourceProvider.overrideWithValue(source)],
        child: const OmcApp(),
      ),
    );
  });
}
