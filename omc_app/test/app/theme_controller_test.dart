import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('theme starts at system and persists an explicit selection', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeControllerProvider), ThemeMode.system);
    await container
        .read(themeControllerProvider.notifier)
        .select(ThemeMode.dark);

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(ThemeController.preferenceKey),
      ThemeMode.dark.name,
    );
  });
}
