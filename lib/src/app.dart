import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/i18n/app_localizations.dart';
import 'core/i18n/locale_controller.dart';
import 'core/routing/app_router.dart';
import 'features/foreman/application/foreman_notifications_coordinator.dart';
import 'features/worker/application/worker_telemetry_coordinator.dart';

const _primaryColor = Color(0xFFF4511E);
const _secondaryColor = Color(0xFF263238);
const _tertiaryColor = Color(0xFFA15AB8);
const _neutralColor = Color(0xFF121212);

class EchipaMeaApp extends ConsumerWidget {
  const EchipaMeaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(workerTelemetryCoordinatorProvider);
    ref.watch(foremanNotificationsProvider);
    final router = ref.watch(appRouterProvider);
    final selectedLocale = ref.watch(localeProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: _primaryColor,
          onPrimary: Colors.white,
          secondary: _secondaryColor,
          onSecondary: Colors.white,
          tertiary: _tertiaryColor,
          onTertiary: Colors.white,
          error: Color(0xFFB3261E),
          onError: Colors.white,
          surface: Colors.white,
          onSurface: _neutralColor,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: _primaryColor,
          onPrimary: Colors.white,
          secondary: _secondaryColor,
          onSecondary: Colors.white,
          tertiary: _tertiaryColor,
          onTertiary: Colors.white,
          error: Color(0xFFF2B8B5),
          onError: Color(0xFF601410),
          surface: _neutralColor,
          onSurface: Colors.white,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      locale: selectedLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
