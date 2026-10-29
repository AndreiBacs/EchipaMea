import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echipa_mea/src/core/auth/session_controller.dart';
import 'package:echipa_mea/src/core/auth/worker_login_api.dart';

/// Payload parsing is covered exhaustively in `qr_ticket_payload_test.dart`.
/// What is left here is the session behaviour around it: mock mode, expiry, and
/// who the resulting session says you are.
///
/// Note these run with an empty `AUTH_API_BASE_URL` (nothing calls
/// `AppEnv.initialize`), which is the mock-mode path — the same one CI takes.
void main() {
  late ProviderContainer container;
  late SessionNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    notifier = container.read(sessionProvider.notifier);
  });

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

  group('SessionNotifier initial state', () {
    test('starts with null session', () {
      expect(container.read(sessionProvider), isNull);
    });
  });

  group('connectFromQrPayload in mock mode', () {
    test('signs in from a valid payload', () async {
      final result = await notifier.connectFromQrPayload(payload());

      expect(result, isTrue);
      final session = container.read(sessionProvider);
      expect(session, isNotNull);
      expect(session!.employeeId, 'emp1');
      expect(session.employeeName, 'John Doe');
      expect(session.sessionToken, startsWith('mock-worker-session-'));
    });

    test('the mock session does not claim to be authenticated', () async {
      // The distinction matters: a mock token proves nothing, and anything
      // deciding whether to open an authenticated socket must be able to tell.
      await notifier.connectFromQrPayload(payload());
      expect(container.read(sessionProvider)!.isAuthenticated, isFalse);
    });

    test('returns false for a code that is not one of ours', () async {
      expect(await notifier.connectFromQrPayload('not-json'), isFalse);
      expect(container.read(sessionProvider), isNull);
    });

    test('throws expired rather than returning a plain false', () async {
      // "Expired" and "not a valid code" send someone to different places, so
      // the caller gets told which one happened.
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
      expect(container.read(sessionProvider), isNull);
    });

    test('disconnect clears the session', () async {
      await notifier.connectFromQrPayload(payload());
      expect(container.read(sessionProvider), isNotNull);

      notifier.disconnect();
      expect(container.read(sessionProvider), isNull);
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
