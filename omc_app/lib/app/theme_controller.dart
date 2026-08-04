import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemeMode> {
  static const preferenceKey = 'omc_theme_mode';

  @override
  ThemeMode build() {
    Future<void>.microtask(_load);
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(preferenceKey);
    state = ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> select(ThemeMode mode) async {
    state = mode;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(preferenceKey, mode.name);
  }
}
