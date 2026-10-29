import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echipa_mea/src/core/auth/session_controller.dart';
import 'package:echipa_mea/src/core/auth/token_store.dart';
import 'package:echipa_mea/src/core/auth/worker_login_api.dart';
import 'package:echipa_mea/src/core/network/api_exception.dart';

import '../support/fake_api.dart';

/// Payload parsing is covered exhaustively in `qr_ticket_payload_test.dart`.
/// What is left here is the session behaviour around it: mock mode, expiry,
/// who the resulting session says you are, and that it survives a restart.
void main() {
  String payload({
    String ticketId = 't1',
    String employeeId = 'emp1',
    String employeeName = 'John Doe',
    Duration expiresIn = const Duration(minutes: 1),
  }) {
    return jsonEncode({
      'type': 'foreman_worker_login_ticket',
      'ticketId': ticketId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'expiresAt': DateTime.now().toUtc().add(expiresIn).toIso8601String(),
    });
  }

  Future<SessionNotifier> ready(ProviderContainer container) async {
    await container.read(sessionProvider.future);
    return container.read(sessionProvider.notifier);
  }

  WorkerSession? current(ProviderContainer container) =>
      container.read(sessionProvider).value;

  group('in mock mode', () {
    test('starts signed out', () async {
      final container = makeApiContainer();
      expect(await container.read(sessionProvider.future), isNull);
    });

    test('signs in from a valid payload', () async {
      final container = makeApiContainer();
      final notifier = await ready(container);

      expect(await notifier.connectFromQrPayload(payload()), isTrue);

      final session = current(container)!;
      expect(session.employeeId, 'emp1');
      expect(session.employeeName, 'John Doe');
      expect(session.sessionToken, startsWith('mock-worker-session-'));
    });

    test('the mock session does not claim to be authenticated', () async {
      // The distinction matters: a mock token proves nothing, and anything
      // deciding whether to open an authenticated socket must be able to tell.
      final container = makeApiContainer();
      await (await ready(container)).connectFromQrPayload(payload());
      expect(current(container)!.isAuthenticated, isFalse);
    });

    test('returns false for a code that is not one of ours', () async {
      final container = makeApiContainer();
      final notifier = await ready(container);
      expect(await notifier.connectFromQrPayload('not-json'), isFalse);
      expect(current(container), isNull);
    });

    test('throws expired rather than returning a plain false', () async {
      // "Expired" and "not a valid code" send someone to different places, so
      // the caller gets told which one happened.
      final container = makeApiContainer();
      final notifier = await ready(container);
      await expectLater(
        notifier.connectFromQrPayload(
          payload(expiresIn: const Duration(minutes: -1)),
        ),
        throwsA(
          isA<WorkerLoginException>().having(
            (e) => e.failure,
            'failure',
            WorkerLoginFailure.expired,
          ),
        ),
      );
      expect(current(container), isNull);
    });

    test('disconnect clears the session', () async {
      final container = makeApiContainer();
      final notifier = await ready(container);
      await notifier.connectFromQrPayload(payload());

      await notifier.disconnect();
      expect(current(container), isNull);
    });
  });

  group('across restarts', () {
    test('a worker stays signed in', () async {
      final store = MemoryTokenStore();
      final first = makeApiContainer(store: store);
      await (await ready(first)).connectFromQrPayload(payload());

      final second = makeApiContainer(store: store);
      final restored = await second.read(sessionProvider.future);
      expect(restored!.employeeId, 'emp1');
    });

    test('a demo session is dropped once a backend is configured', () async {
      final store = MemoryTokenStore();
      await (await ready(
        makeApiContainer(store: store),
      )).connectFromQrPayload(payload());

      useFakeBackend();
      final container = makeApiContainer(store: store);
      expect(await container.read(sessionProvider.future), isNull);
      expect(await store.read('worker_session'), isNull);
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

    Map<String, dynamic> redeemBody({
      String access = 'w1',
      String refresh = 'wr1',
    }) => {
      'token': access,
      'accessToken': access,
      'refreshToken': refresh,
      'worker': {
        'employeeId': 'e1',
        'employeeName': 'Andrei D.',
        'role': 'worker',
        'companyId': 'demo-company',
      },
    };

    test('identity and tokens come from the server, not the code', () async {
      server.on('POST', '/worker/login-tickets/redeem', (r) {
        expect(jsonBodyOf(r), {'ticketId': 't1'});
        return jsonResponse(redeemBody());
      });
      final container = makeApiContainer(server: server, store: store);

      await (await ready(
        container,
      )).connectFromQrPayload(payload(employeeId: 'someone-else'));

      final session = current(container)!;
      expect(session.employeeId, 'e1');
      expect(session.sessionToken, 'w1');
      expect(session.refreshToken, 'wr1');
      expect(session.isAuthenticated, isTrue);
    });

    test('a used code reports alreadyUsed', () async {
      server.on(
        'POST',
        '/worker/login-tickets/redeem',
        (_) => errorResponse(409, 'TICKET_ALREADY_REDEEMED'),
      );
      final container = makeApiContainer(server: server, store: store);
      final notifier = await ready(container);

      await expectLater(
        notifier.connectFromQrPayload(payload()),
        throwsA(
          isA<WorkerLoginException>().having(
            (e) => e.failure,
            'failure',
            WorkerLoginFailure.alreadyUsed,
          ),
        ),
      );
    });

    test(
      'an expired worker token is refreshed, keeping who the worker is',
      () async {
        server
          ..on(
            'POST',
            '/worker/login-tickets/redeem',
            (_) => jsonResponse(redeemBody()),
          )
          ..on('POST', '/auth/refresh', (r) {
            expect(jsonBodyOf(r), {'refreshToken': 'wr1'});
            return jsonResponse({
              'accessToken': 'w2',
              'refreshToken': 'wr2',
              'user': {},
            });
          })
          ..on(
            'GET',
            '/worker/me',
            (r) => bearerOf(r) == 'w2'
                ? jsonResponse({'employeeId': 'e1'})
                : errorResponse(401, 'TOKEN_EXPIRED'),
          );
        final container = makeApiContainer(server: server, store: store);
        await (await ready(container)).connectFromQrPayload(payload());

        await container.read(workerApiProvider).get('/worker/me');

        final session = current(container)!;
        expect(session.sessionToken, 'w2');
        expect(session.refreshToken, 'wr2');
        expect(session.employeeId, 'e1');
        expect(
          WorkerSession.tryDecode(
            await store.read('worker_session'),
          )!.sessionToken,
          'w2',
        );
      },
    );

    test('deactivation ends the session on the next call', () async {
      server
        ..on(
          'POST',
          '/worker/login-tickets/redeem',
          (_) => jsonResponse(redeemBody()),
        )
        ..on(
          'GET',
          '/worker/me',
          (_) => errorResponse(403, 'ACCOUNT_DISABLED'),
        );
      final container = makeApiContainer(server: server, store: store);
      await (await ready(container)).connectFromQrPayload(payload());

      await expectLater(
        container.read(workerApiProvider).get('/worker/me'),
        throwsA(isA<ApiException>()),
      );
      expect(current(container), isNull);
      expect(await store.read('worker_session'), isNull);
    });

    test('disconnect revokes the session on the server', () async {
      server
        ..on(
          'POST',
          '/worker/login-tickets/redeem',
          (_) => jsonResponse(redeemBody()),
        )
        ..on('POST', '/auth/logout', (_) => http204());
      final container = makeApiContainer(server: server, store: store);
      final notifier = await ready(container);
      await notifier.connectFromQrPayload(payload());

      await notifier.disconnect();

      final logout = server.requests.lastWhere(
        (r) => r.url.path == '/auth/logout',
      );
      expect(bearerOf(logout), 'w1');
      expect(current(container), isNull);
    });
  });

  group('WorkerSession.isAuthenticated', () {
    test('is true for a server-issued token', () {
      const session = WorkerSession(
        employeeId: 'e1',
        employeeName: 'Andrei D.',
        sessionToken: 'eyJhbGciOiJIUzI1NiJ9.real.token',
        companyId: 'demo-company',
      );
      expect(session.isAuthenticated, isTrue);
    });

    test('is false for an empty token', () {
      const session = WorkerSession(
        employeeId: 'e1',
        employeeName: 'Andrei D.',
        sessionToken: '',
      );
      expect(session.isAuthenticated, isFalse);
    });
  });
}
