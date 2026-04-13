import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echipa_mea/src/core/i18n/app_localizations.dart';
import 'package:echipa_mea/src/features/foreman/presentation/pages/project_phase_form_page.dart';

void main() {
  testWidgets('edit phase form shows description field', (tester) async {
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
          home: const ProjectPhaseFormPage(
            projectId: 'p1',
            phaseId: 'p1_phase_1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demolition'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
