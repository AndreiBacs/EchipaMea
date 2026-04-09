import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:echipa_mea/src/app.dart';

void main() {
  testWidgets('App renders home page', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EchipaMeaApp()));
    await tester.pumpAndSettle();

    expect(find.text('EchipaMea'), findsOneWidget);
    expect(find.text('Flutter starter is ready'), findsOneWidget);
  });
}
