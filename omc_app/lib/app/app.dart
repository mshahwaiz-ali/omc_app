import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/support/presentation/support_chat_bubble.dart';
import 'router.dart';
import 'theme.dart';

class OmcApp extends ConsumerWidget {
  const OmcApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'OMC App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (context, child) => SupportChatBubbleOverlay(
        router: router,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
