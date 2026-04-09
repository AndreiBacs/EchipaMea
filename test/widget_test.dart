import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echipa_mea/src/app.dart';
import 'package:echipa_mea/src/core/config/app_env.dart';

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: '', isOptional: true);
    AppEnv.initialize();
  });

  testWidgets('App shows login after initial setup is complete',
      (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'app_initial_setup_completed': true,
    });

    await tester.pumpWidget(const ProviderScope(child: EchipaMeaApp()));
    await tester.pumpAndSettle();

    // Default locale is Romanian; login screen title from l10n.loginTitle.
    expect(find.text('Autentificare'), findsOneWidget);
  });
}
