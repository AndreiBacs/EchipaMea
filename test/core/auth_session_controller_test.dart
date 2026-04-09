import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echipa_mea/src/core/auth/auth_session_controller.dart';
import 'package:echipa_mea/src/core/config/app_env.dart';

void main() {
  setUpAll(() async {
    // Load an empty dotenv so AppEnv.initialize() resolves all fields to
    // their defaults (authApiBaseUrl == '' → mock token path).
    dotenv.loadFromString(envString: '', isOptional: true);
    AppEnv.initialize();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  group('AuthSessionNotifier.build – initial load from SharedPreferences', () {
    test('returns null when no token is stored', () async {
      final container = makeContainer();
      final session = await container.read(authSessionProvider.future);
      expect(session, isNull);
    });

    test('returns AuthSession when token and email are stored', () async {
      SharedPreferences.setMockInitialValues({
        'foreman_auth_token': 'saved-token',
        'foreman_auth_email': 'user@example.com',
      });
      final container = makeContainer();
      final session = await container.read(authSessionProvider.future);
      expect(session, isNotNull);
      expect(session!.token, 'saved-token');
      expect(session.email, 'user@example.com');
    });

    test('returns null when token is empty string', () async {
      SharedPreferences.setMockInitialValues({
        'foreman_auth_token': '',
        'foreman_auth_email': 'user@example.com',
      });
      final container = makeContainer();
      final session = await container.read(authSessionProvider.future);
      expect(session, isNull);
    });

    test('returns session with empty email when email is not stored', () async {
      SharedPreferences.setMockInitialValues({
        'foreman_auth_token': 'some-token',
      });
      final container = makeContainer();
      final session = await container.read(authSessionProvider.future);
      expect(session, isNotNull);
      expect(session!.email, '');
    });
  });

  group('AuthSessionNotifier.loginForeman – mock token path', () {
    test('sets session with mock token for valid credentials', () async {
      final container = makeContainer();
      await container.read(authSessionProvider.future);

      await container
          .read(authSessionProvider.notifier)
          .loginForeman(email: 'test@example.com', password: 'abc');

      final session = container.read(authSessionProvider).value;
      expect(session, isNotNull);
      expect(session!.email, 'test@example.com');
      expect(session.token, startsWith('mock-foreman-token-'));
    });

    test('mock token uses sanitised email characters', () async {
      final container = makeContainer();
      await container.read(authSessionProvider.future);

      await container
          .read(authSessionProvider.notifier)
          .loginForeman(email: 'User@Example.Com', password: 'pass123');

      final session = container.read(authSessionProvider).value;
      expect(session, isNotNull);
      expect(session!.token, 'mock-foreman-token-user-example-com');
    });

    test('persists token and email to SharedPreferences', () async {
      final container = makeContainer();
      await container.read(authSessionProvider.future);

      await container
          .read(authSessionProvider.notifier)
          .loginForeman(email: 'stored@example.com', password: 'pass');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('foreman_auth_token'), isNotNull);
      expect(prefs.getString('foreman_auth_email'), 'stored@example.com');
    });

    test('sets error state for empty email', () async {
      final container = makeContainer();
      await container.read(authSessionProvider.future);

      await container
          .read(authSessionProvider.notifier)
          .loginForeman(email: '', password: 'pass');

      expect(container.read(authSessionProvider).hasError, isTrue);
    });

    test('sets error state for empty password', () async {
      final container = makeContainer();
      await container.read(authSessionProvider.future);

      await container
          .read(authSessionProvider.notifier)
          .loginForeman(email: 'user@example.com', password: '');

      expect(container.read(authSessionProvider).hasError, isTrue);
    });

    test('sets error state for email without @', () async {
      final container = makeContainer();
      await container.read(authSessionProvider.future);

      await container
          .read(authSessionProvider.notifier)
          .loginForeman(email: 'notanemail', password: 'pass123');

      expect(container.read(authSessionProvider).hasError, isTrue);
    });

    test('sets error state when password is shorter than 3 characters', () async {
      final container = makeContainer();
      await container.read(authSessionProvider.future);

      await container
          .read(authSessionProvider.notifier)
          .loginForeman(email: 'valid@example.com', password: 'ab');

      expect(container.read(authSessionProvider).hasError, isTrue);
    });

    test('restores previous session on login error when one existed', () async {
      SharedPreferences.setMockInitialValues({
        'foreman_auth_token': 'existing-token',
        'foreman_auth_email': 'existing@example.com',
      });
      final container = makeContainer();
      await container.read(authSessionProvider.future);

      // Attempt bad login
      await container
          .read(authSessionProvider.notifier)
          .loginForeman(email: 'bad-email', password: 'x');

      final session = container.read(authSessionProvider).value;
      expect(session, isNotNull);
      expect(session!.token, 'existing-token');
    });
  });

  group('AuthSessionNotifier.logout', () {
    test('clears session state', () async {
      SharedPreferences.setMockInitialValues({
        'foreman_auth_token': 'tok',
        'foreman_auth_email': 'u@e.com',
      });
      final container = makeContainer();
      await container.read(authSessionProvider.future);

      await container.read(authSessionProvider.notifier).logout();

      final session = container.read(authSessionProvider).value;
      expect(session, isNull);
    });

    test('removes token and email from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'foreman_auth_token': 'tok',
        'foreman_auth_email': 'u@e.com',
      });
      final container = makeContainer();
      await container.read(authSessionProvider.future);

      await container.read(authSessionProvider.notifier).logout();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('foreman_auth_token'), isNull);
      expect(prefs.getString('foreman_auth_email'), isNull);
    });
  });

  group('AuthSession model', () {
    test('stores token and email', () {
      const session = AuthSession(token: 'tok', email: 'u@e.com');
      expect(session.token, 'tok');
      expect(session.email, 'u@e.com');
    });
  });
}
