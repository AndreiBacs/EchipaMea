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
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
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
}
