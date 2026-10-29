import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echipa_mea/src/core/auth/session_controller.dart';
import 'package:echipa_mea/src/core/i18n/app_localizations.dart';
import 'package:echipa_mea/src/features/worker/presentation/pages/worker_connect_page.dart';

/// A desktop has no camera scanner, so the code is typed or pasted.
void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  String payload() => jsonEncode({
    'type': 'foreman_worker_login_ticket',
    'ticketId': 't1',
    'employeeId': 'e1',
    'employeeName': 'Andrei D.',
    'expiresAt': DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 1))
        .toIso8601String(),
  });

  Future<void> pumpConnectPage(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: WorkerConnectPage.routePath,
      routes: [
        GoRoute(
          path: WorkerConnectPage.routePath,
          builder: (_, _) => const WorkerConnectPage(),
        ),
        GoRoute(path: '/worker/work', builder: (_, _) => const Text('work')),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final desktop = TargetPlatformVariant.only(TargetPlatform.windows);

  final codeField = find.byKey(const ValueKey('worker-login-code-field'));

  testWidgets('shows the code field and no scanner', (tester) async {
    await pumpConnectPage(tester);

    expect(codeField, findsOneWidget);
    expect(find.byType(MobileScanner), findsNothing);
  }, variant: desktop);

  testWidgets('a pasted code signs the worker in', (tester) async {
    await pumpConnectPage(tester);

    await tester.enterText(codeField, payload());
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text('work'), findsOneWidget);
    expect(container.read(sessionProvider).value!.employeeId, 'e1');
  }, variant: desktop);

  testWidgets('a bad code keeps the worker on the page', (tester) async {
    await pumpConnectPage(tester);

    await tester.enterText(codeField, 'not a code');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(codeField, findsOneWidget);
    expect(container.read(sessionProvider).value, isNull);
  }, variant: desktop);
}
