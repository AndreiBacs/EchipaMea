import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  static const _themeModeKey = 'theme_mode';
  static const _themeSystem = 'system';
  static const _themeLight = 'light';
  static const _themeDark = 'dark';

  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final storedValue = prefs.getString(_themeModeKey);
    return _decodeThemeMode(storedValue);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _encodeThemeMode(mode));
    state = AsyncData(mode);
  }

  ThemeMode _decodeThemeMode(String? rawValue) {
    switch (rawValue) {
      case _themeLight:
        return ThemeMode.light;
      case _themeDark:
        return ThemeMode.dark;
      case _themeSystem:
      default:
        return ThemeMode.system;
    }
  }

  String _encodeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return _themeLight;
      case ThemeMode.dark:
        return _themeDark;
      case ThemeMode.system:
        return _themeSystem;
    }
  }
}
