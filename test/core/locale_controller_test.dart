import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echipa_mea/src/core/i18n/locale_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  group('LocaleNotifier initial state', () {
    test('starts with Romanian as default app locale', () {
      expect(container.read(localeProvider), const Locale('ro'));
    });
  });

  group('LocaleNotifier.setLocale', () {
    test('sets locale to English', () {
      container.read(localeProvider.notifier).setLocale(const Locale('en'));
      expect(container.read(localeProvider), const Locale('en'));
    });

    test('sets locale to Romanian', () {
      container.read(localeProvider.notifier).setLocale(const Locale('ro'));
      expect(container.read(localeProvider), const Locale('ro'));
    });

    test('sets locale to Hungarian', () {
      container.read(localeProvider.notifier).setLocale(const Locale('hu'));
      expect(container.read(localeProvider), const Locale('hu'));
    });

    test('sets locale back to null', () {
      container.read(localeProvider.notifier).setLocale(const Locale('en'));
      container.read(localeProvider.notifier).setLocale(null);
      expect(container.read(localeProvider), isNull);
    });

    test('updates locale on repeated calls', () {
      container.read(localeProvider.notifier).setLocale(const Locale('en'));
      container.read(localeProvider.notifier).setLocale(const Locale('ro'));
      expect(container.read(localeProvider), const Locale('ro'));
    });
  });
}
