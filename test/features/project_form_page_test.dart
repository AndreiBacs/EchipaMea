import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echipa_mea/src/core/i18n/app_localizations.dart';
import 'package:echipa_mea/src/features/foreman/presentation/pages/project_form_page.dart';

void main() {
  Future<void> pumpProjectForm(
    WidgetTester tester, {
    String? projectId,
    String? initialClientId,
    int initialTabIndex = 0,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProjectFormPage(
            projectId: projectId,
            initialClientId: initialClientId,
            initialTabIndex: initialTabIndex,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'create from client projects preselects and locks client selector',
    (tester) async {
      await pumpProjectForm(tester, initialClientId: 'c1');

      final clientDropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>).first,
      );

      expect(clientDropdown.initialValue, 'c1');
      expect(clientDropdown.onChanged, isNull);
    },
  );

  testWidgets('normal create keeps client selector editable', (tester) async {
    await pumpProjectForm(tester);

    final clientDropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).first,
    );

    expect(clientDropdown.onChanged, isNotNull);
  });

  testWidgets('edit keeps client selector editable', (tester) async {
    await pumpProjectForm(tester, projectId: 'p1');

    final clientDropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).first,
    );

    expect(clientDropdown.initialValue, 'c1');
    expect(clientDropdown.onChanged, isNotNull);
  });

  testWidgets('use client address toggle unlocks address fields for manual editing', (
    tester,
  ) async {
    await pumpProjectForm(tester, initialClientId: 'c1');

    expect(find.text('Str. Victoriei 12'), findsOneWidget);

    await tester.tap(find.text('Use client address'));
    await tester.pumpAndSettle();

    final addressField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Project address'),
    );
    expect(addressField.enabled, isTrue);
  });

  testWidgets('initialTabIndex opens phases tab with add phase', (tester) async {
    await pumpProjectForm(tester, projectId: 'p1', initialTabIndex: 1);

    expect(find.text('Add phase'), findsOneWidget);
  });

  testWidgets('swipe on draft phase opens edit phase dialog', (tester) async {
    await pumpProjectForm(tester, initialTabIndex: 1);

    await tester.tap(find.text('Add phase'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Phase name'),
      'Swipe edit phase',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add phase'));
    await tester.pumpAndSettle();

    expect(find.text('Swipe edit phase'), findsOneWidget);

    await tester.drag(find.text('Swipe edit phase'), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Edit phase'), findsOneWidget);
  });
}
