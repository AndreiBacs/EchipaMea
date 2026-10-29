import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs around every test file.
///
/// Sessions live in flutter_secure_storage, which needs a platform channel the
/// test runner does not have. Each test starts with an empty in-memory
/// keystore, the same way tests reset SharedPreferences.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  await testMain();
}
