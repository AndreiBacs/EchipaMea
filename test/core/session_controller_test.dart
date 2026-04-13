import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echipa_mea/src/core/auth/session_controller.dart';

void main() {
  late ProviderContainer container;
  late SessionNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    notifier = container.read(sessionProvider.notifier);
  });

  group('SessionNotifier initial state', () {
    test('starts with null session', () {
      expect(container.read(sessionProvider), isNull);
    });
  });

  group('SessionNotifier.connectFromQrPayload – direct JSON', () {
    test('returns true and sets state for valid direct JSON payload', () {
      final expiresAt = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 1))
          .toIso8601String();
      final payload =
          '{"type":"foreman_worker_login_ticket","ticketId":"t1","employeeId":"emp1","employeeName":"John Doe","expiresAt":"$expiresAt"}';
      final result = notifier.connectFromQrPayload(payload);

      expect(result, isTrue);
      final session = container.read(sessionProvider);
      expect(session, isNotNull);
      expect(session!.employeeId, 'emp1');
      expect(session.employeeName, 'John Doe');
      expect(session.sessionToken, startsWith('mock-worker-session-'));
    });

    test('returns false for wrong type field', () {
      final expiresAt = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 1))
          .toIso8601String();
      final payload =
          '{"type":"other_type","ticketId":"t1","employeeId":"emp1","employeeName":"John","expiresAt":"$expiresAt"}';
      expect(notifier.connectFromQrPayload(payload), isFalse);
    });

    test('returns false when employeeId is missing', () {
      final expiresAt = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 1))
          .toIso8601String();
      final payload =
          '{"type":"foreman_worker_login_ticket","ticketId":"t1","employeeName":"John","expiresAt":"$expiresAt"}';
      expect(notifier.connectFromQrPayload(payload), isFalse);
    });

    test('returns false when employeeId is empty', () {
      final expiresAt = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 1))
          .toIso8601String();
      final payload =
          '{"type":"foreman_worker_login_ticket","ticketId":"t1","employeeId":"","employeeName":"John","expiresAt":"$expiresAt"}';
      expect(notifier.connectFromQrPayload(payload), isFalse);
    });

    test('returns false when employeeName is missing', () {
      final expiresAt = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 1))
          .toIso8601String();
      final payload =
          '{"type":"foreman_worker_login_ticket","ticketId":"t1","employeeId":"emp1","expiresAt":"$expiresAt"}';
      expect(notifier.connectFromQrPayload(payload), isFalse);
    });

    test('returns false when employeeName is empty', () {
      final expiresAt = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 1))
          .toIso8601String();
      final payload =
          '{"type":"foreman_worker_login_ticket","ticketId":"t1","employeeId":"emp1","employeeName":"","expiresAt":"$expiresAt"}';
      expect(notifier.connectFromQrPayload(payload), isFalse);
    });

    test('returns false for invalid JSON', () {
      expect(notifier.connectFromQrPayload('not-json'), isFalse);
    });

    test('returns false for empty string', () {
      expect(notifier.connectFromQrPayload(''), isFalse);
    });

    test('returns false for JSON array (not a map)', () {
      expect(notifier.connectFromQrPayload('[1,2,3]'), isFalse);
    });

    test('returns false when ticketId is missing', () {
      final expiresAt = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 1))
          .toIso8601String();
      final payload =
          '{"type":"foreman_worker_login_ticket","employeeId":"emp1","employeeName":"John","expiresAt":"$expiresAt"}';
      expect(notifier.connectFromQrPayload(payload), isFalse);
    });

    test('returns false when ticket is expired', () {
      final expiresAt = DateTime.now()
          .toUtc()
          .subtract(const Duration(seconds: 1))
          .toIso8601String();
      final payload =
          '{"type":"foreman_worker_login_ticket","ticketId":"expired-1","employeeId":"emp1","employeeName":"John","expiresAt":"$expiresAt"}';
      expect(notifier.connectFromQrPayload(payload), isFalse);
    });
  });

  group('SessionNotifier.connectFromQrPayload – URL-wrapped JSON', () {
    test('parses JSON payload from https URL query parameter', () {
      final expiresAt = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 1))
          .toIso8601String();
      final jsonPayload =
          '{"type":"foreman_worker_login_ticket","ticketId":"t2","employeeId":"emp2","employeeName":"Jane","expiresAt":"$expiresAt"}';
      final encoded = Uri.encodeComponent(jsonPayload);
      final url = 'https://example.com/login?payload=$encoded';

      final result = notifier.connectFromQrPayload(url);

      expect(result, isTrue);
      final session = container.read(sessionProvider);
      expect(session!.employeeId, 'emp2');
      expect(session.employeeName, 'Jane');
    });

    test('parses JSON payload from custom scheme URL query parameter', () {
      final expiresAt = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 1))
          .toIso8601String();
      final jsonPayload =
          '{"type":"foreman_worker_login_ticket","ticketId":"t3","employeeId":"emp3","employeeName":"Bob","expiresAt":"$expiresAt"}';
      final encoded = Uri.encodeComponent(jsonPayload);
      final url = 'echipamea://worker-login?payload=$encoded';

      final result = notifier.connectFromQrPayload(url);

      expect(result, isTrue);
      final session = container.read(sessionProvider);
      expect(session!.employeeId, 'emp3');
      expect(session.employeeName, 'Bob');
    });

    test('parses Base64-encoded JSON from URL query parameter', () {
      final expiresAt = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 1))
          .toIso8601String();
      final jsonPayload =
          '{"type":"foreman_worker_login_ticket","ticketId":"t4","employeeId":"emp4","employeeName":"Alice","expiresAt":"$expiresAt"}';
      final base64Payload = base64Encode(utf8.encode(jsonPayload));
      // URL-encode so that any base64 characters (+, /, =) are preserved.
      final url =
          'https://example.com/login?payload=${Uri.encodeComponent(base64Payload)}';

      final result = notifier.connectFromQrPayload(url);

      expect(result, isTrue);
      final session = container.read(sessionProvider);
      expect(session!.employeeId, 'emp4');
      expect(session.employeeName, 'Alice');
    });

    test('returns false when URL has no payload query parameter', () {
      const url = 'https://example.com/login';
      expect(notifier.connectFromQrPayload(url), isFalse);
    });

    test('returns false when URL payload query parameter is empty', () {
      const url = 'https://example.com/login?payload=';
      expect(notifier.connectFromQrPayload(url), isFalse);
    });
  });

  group('SessionNotifier.connectFromQrPayload – whitespace handling', () {
    test('trims whitespace around JSON payload', () {
      final expiresAt = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 1))
          .toIso8601String();
      final payload =
          '  {"type":"foreman_worker_login_ticket","ticketId":"t5","employeeId":"emp5","employeeName":"Sam","expiresAt":"$expiresAt"}  ';
      final result = notifier.connectFromQrPayload(payload);
      expect(result, isTrue);
    });
  });

  group('WorkerSession model', () {
    test('stores employeeId and employeeName', () {
      const session = WorkerSession(
        employeeId: 'e42',
        employeeName: 'Test Worker',
        sessionToken: 'mock-worker-session-e42',
      );
      expect(session.employeeId, 'e42');
      expect(session.employeeName, 'Test Worker');
      expect(session.sessionToken, 'mock-worker-session-e42');
    });
  });
}
