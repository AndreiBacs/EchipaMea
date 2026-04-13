import 'package:echipa_mea/src/core/theme/theme_mode_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  group('ThemeModeNotifier initial state', () {
    test('starts with system mode by default', () async {
      expect(await container.read(themeModeProvider.future), ThemeMode.system);
    });

    test('loads light mode from preferences', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      final localContainer = ProviderContainer();
      addTearDown(localContainer.dispose);

      expect(
        await localContainer.read(themeModeProvider.future),
        ThemeMode.light,
      );
    });

    test('loads dark mode from preferences', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final localContainer = ProviderContainer();
      addTearDown(localContainer.dispose);

      expect(
        await localContainer.read(themeModeProvider.future),
        ThemeMode.dark,
      );
    });
  });

  group('ThemeModeNotifier.setThemeMode', () {
    test('updates state and persists selected value', () async {
      await container.read(themeModeProvider.future);
      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);

      expect(container.read(themeModeProvider).value, ThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });
  });
}
