// Host side of `flutter drive` for running integration_test/ in a browser,
// where `flutter test` cannot: see scripts/e2e_app.sh.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
