import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echipa_mea/src/core/auth/auth_session_controller.dart';
import 'package:echipa_mea/src/core/auth/token_store.dart';
import 'package:echipa_mea/src/core/network/api_exception.dart';

import '../support/fake_api.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<String?> storedSession(MemoryTokenStore store) =>
      store.read('foreman_session');

  group('build: restoring the session', () {
    test('is null when nothing is stored', () async {
      final container = makeApiContainer();
      expect(await container.read(authSessionProvider.future), isNull);
    });

    test('restores a session saved by an earlier run', () async {
      final store = MemoryTokenStore({
        'foreman_session': const AuthSession(
          token: 'saved-token',
          email: 'user@example.com',
          refreshToken: 'saved-refresh',
        ).encode(),
      });
      final container = makeApiContainer(store: store);

      final session = await container.read(authSessionProvider.future);
      expect(session!.token, 'saved-token');
      expect(session.refreshToken, 'saved-refresh');
      expect(session.email, 'user@example.com');
    });

    test('moves a pre-upgrade token out of SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'foreman_auth_token': 'legacy-token',
        'foreman_auth_email': 'old@example.com',
      });
      final store = MemoryTokenStore();
      final container = makeApiContainer(store: store);

      final session = await container.read(authSessionProvider.future);
      expect(session!.token, 'legacy-token');
      expect(session.email, 'old@example.com');
      expect(await storedSession(store), isNotNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('foreman_auth_token'), isNull);
      expect(prefs.getString('foreman_auth_email'), isNull);
    });

    test('drops a demo-mode token once a backend is configured', () async {
      useFakeBackend();
      final store = MemoryTokenStore({
        'foreman_session': const AuthSession(
          token: 'mock-foreman-token-a-b-c',
          email: 'a@b.c',
        ).encode(),
      });
      final container = makeApiContainer(store: store);

      expect(await container.read(authSessionProvider.future), isNull);
      expect(await storedSession(store), isNull);
    });
  });

  group('loginForeman in mock mode', () {
    test('signs in with a mock token for plausible credentials', () async {
      final store = MemoryTokenStore();
      final container = makeApiContainer(store: store);
      await container.read(authSessionProvider.future);

      await container
          .read(authSessionProvider.notifier)
          .loginForeman(email: 'User@Example.Com', password: 'pass123');

      final session = container.read(authSessionProvider).value!;
      expect(session.token, 'mock-foreman-token-user-example-com');
      expect(session.isMock, isTrue);
      expect(await storedSession(store), isNotNull);
    });

    for (final (email, password) in [
      ('', 'pass'),
      ('notanemail', 'pass123'),
      ('valid@example.com', 'ab'),
    ]) {
      test('rejects "$email" / "$password" as invalid credentials', () async {
        final container = makeApiContainer();
        await container.read(authSessionProvider.future);

        await container
            .read(authSessionProvider.notifier)
            .loginForeman(email: email, password: password);

        final state = container.read(authSessionProvider);
        expect(
          state.error,
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'INVALID_CREDENTIALS',
          ),
        );
      });
    }

    test('keeps the previous session when a new login fails', () async {
      final store = MemoryTokenStore({
        'foreman_session': const AuthSession(
          token: 'existing-token',
          email: 'existing@example.com',
        ).encode(),
      });
      final container = makeApiContainer(store: store);
      await container.read(authSessionProvider.future);

      await container
          .read(authSessionProvider.notifier)
          .loginForeman(email: 'bad-email', password: 'x');

      expect(
        container.read(authSessionProvider).value!.token,
        'existing-token',
      );
    });
  });

  group('with a server', () {
    late FakeServer server;
    late MemoryTokenStore store;

    setUp(() {
      useFakeBackend();
      server = FakeServer();
      store = MemoryTokenStore();
    });

    test('login keeps the refresh token and who the user is', () async {
      server.on('POST', '/foreman/login', (r) {
        expect(jsonBodyOf(r), {'email': 'f@x.ro', 'password': 'secret'});
        return jsonResponse(loginBody(access: 'a1', refresh: 'r1'));
      });
      final container = makeApiContainer(server: server, store: store);
      await container.read(authSessionProvider.future);

      await container
          .read(authSessionProvider.notifier)
          .loginForeman(email: 'f@x.ro', password: 'secret');

      final session = container.read(authSessionProvider).value!;
      expect(session.token, 'a1');
      expect(session.refreshToken, 'r1');
      expect(session.companyId, 'demo-company');
      expect(
        AuthSession.tryDecode(await storedSession(store))!.refreshToken,
        'r1',
      );
    });

    test('a rejected login surfaces the server code', () async {
      server.on(
        'POST',
        '/foreman/login',
        (_) => errorResponse(401, 'INVALID_CREDENTIALS'),
      );
      final container = makeApiContainer(server: server, store: store);
      await container.read(authSessionProvider.future);

      await container
          .read(authSessionProvider.notifier)
          .loginForeman(email: 'f@x.ro', password: 'wrong');

      expect(
        container.read(authSessionProvider).error,
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'INVALID_CREDENTIALS',
        ),
      );
    });

    test('an expired token is refreshed transparently, and stored', () async {
      store = MemoryTokenStore({
        'foreman_session': const AuthSession(
          token: 'old',
          email: 'f@x.ro',
          refreshToken: 'r-old',
        ).encode(),
      });
      server
        ..on('POST', '/auth/refresh', (r) {
          expect(jsonBodyOf(r), {'refreshToken': 'r-old'});
          return jsonResponse(loginBody(access: 'new', refresh: 'r-new'));
        })
        ..on(
          'GET',
          '/clients',
          (r) => bearerOf(r) == 'new'
              ? jsonResponse({'items': [], 'page': {}})
              : errorResponse(401, 'TOKEN_EXPIRED'),
        );
      final container = makeApiContainer(server: server, store: store);
      await container.read(authSessionProvider.future);

      await container.read(foremanApiProvider).get('/clients');

      expect(container.read(authSessionProvider).value!.token, 'new');
      expect(
        AuthSession.tryDecode(await storedSession(store))!.refreshToken,
        'r-new',
      );
    });

    test('concurrent 401s share one refresh', () async {
      // Refresh tokens rotate: a second parallel refresh would replay the
      // spent one, which the server treats as theft.
      store = MemoryTokenStore({
        'foreman_session': const AuthSession(
          token: 'old',
          email: 'f@x.ro',
          refreshToken: 'r-old',
        ).encode(),
      });
      server
        ..on('POST', '/auth/refresh', (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return jsonResponse(loginBody(access: 'new', refresh: 'r-new'));
        })
        ..on(
          'GET',
          '/clients',
          (r) => bearerOf(r) == 'new'
              ? jsonResponse({'ok': true})
              : errorResponse(401, 'TOKEN_EXPIRED'),
        );
      final container = makeApiContainer(server: server, store: store);
      await container.read(authSessionProvider.future);
      final api = container.read(foremanApiProvider);

      await Future.wait([
        api.get('/clients'),
        api.get('/clients'),
        api.get('/clients'),
      ]);

      expect(server.count('POST', '/auth/refresh'), 1);
    });

    test('a refused refresh signs the foreman out', () async {
      store = MemoryTokenStore({
        'foreman_session': const AuthSession(
          token: 'old',
          email: 'f@x.ro',
          refreshToken: 'r-revoked',
        ).encode(),
      });
      server
        ..on('POST', '/auth/refresh', (_) => errorResponse(401, 'TOKEN_REUSED'))
        ..on('GET', '/clients', (_) => errorResponse(401, 'TOKEN_EXPIRED'));
      final container = makeApiContainer(server: server, store: store);
      await container.read(authSessionProvider.future);

      await expectLater(
        container.read(foremanApiProvider).get('/clients'),
        throwsA(isA<ApiException>()),
      );

      expect(container.read(authSessionProvider).value, isNull);
      expect(await storedSession(store), isNull);
    });

    test('logout revokes on the server and clears the device', () async {
      store = MemoryTokenStore({
        'foreman_session': const AuthSession(
          token: 'a1',
          email: 'f@x.ro',
          refreshToken: 'r1',
        ).encode(),
      });
      server.on('POST', '/auth/logout', (_) => http204());
      final container = makeApiContainer(server: server, store: store);
      await container.read(authSessionProvider.future);

      await container.read(authSessionProvider.notifier).logout();

      expect(bearerOf(server.requests.single), 'a1');
      expect(container.read(authSessionProvider).value, isNull);
      expect(await storedSession(store), isNull);
    });

    test(
      'logout still clears the device when the server is unreachable',
      () async {
        store = MemoryTokenStore({
          'foreman_session': const AuthSession(
            token: 'a1',
            email: 'f@x.ro',
          ).encode(),
        });
        server.on('POST', '/auth/logout', (_) => throw Exception('offline'));
        final container = makeApiContainer(server: server, store: store);
        await container.read(authSessionProvider.future);

        await container.read(authSessionProvider.notifier).logout();

        expect(container.read(authSessionProvider).value, isNull);
      },
    );
  });
}
