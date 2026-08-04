import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/api_config.dart';
import 'core/diagnostics/diagnostics_reporter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiConfig.validateBuildProfile();

  await DiagnosticsReporter.run(
    () => runApp(const ProviderScope(child: OmcApp())),
  );
}
