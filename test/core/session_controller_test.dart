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
      const payload =
          '{"type":"employee_login","employeeId":"emp1","employeeName":"John Doe"}';
      final result = notifier.connectFromQrPayload(payload);

      expect(result, isTrue);
      final session = container.read(sessionProvider);
      expect(session, isNotNull);
      expect(session!.employeeId, 'emp1');
      expect(session.employeeName, 'John Doe');
    });

    test('returns false for wrong type field', () {
      const payload =
          '{"type":"other_type","employeeId":"emp1","employeeName":"John"}';
      expect(notifier.connectFromQrPayload(payload), isFalse);
    });

    test('returns false when employeeId is missing', () {
      const payload = '{"type":"employee_login","employeeName":"John"}';
      expect(notifier.connectFromQrPayload(payload), isFalse);
    });

    test('returns false when employeeId is empty', () {
      const payload =
          '{"type":"employee_login","employeeId":"","employeeName":"John"}';
      expect(notifier.connectFromQrPayload(payload), isFalse);
    });

    test('returns false when employeeName is missing', () {
      const payload = '{"type":"employee_login","employeeId":"emp1"}';
      expect(notifier.connectFromQrPayload(payload), isFalse);
    });

    test('returns false when employeeName is empty', () {
      const payload =
          '{"type":"employee_login","employeeId":"emp1","employeeName":""}';
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
  });

  group('SessionNotifier.connectFromQrPayload – URL-wrapped JSON', () {
    test('parses JSON payload from https URL query parameter', () {
      const jsonPayload =
          '{"type":"employee_login","employeeId":"emp2","employeeName":"Jane"}';
      final encoded = Uri.encodeComponent(jsonPayload);
      final url = 'https://example.com/login?payload=$encoded';

      final result = notifier.connectFromQrPayload(url);

      expect(result, isTrue);
      final session = container.read(sessionProvider);
      expect(session!.employeeId, 'emp2');
      expect(session.employeeName, 'Jane');
    });

    test('parses JSON payload from custom scheme URL query parameter', () {
      const jsonPayload =
          '{"type":"employee_login","employeeId":"emp3","employeeName":"Bob"}';
      final encoded = Uri.encodeComponent(jsonPayload);
      final url = 'echipamea://worker-login?payload=$encoded';

      final result = notifier.connectFromQrPayload(url);

      expect(result, isTrue);
      final session = container.read(sessionProvider);
      expect(session!.employeeId, 'emp3');
      expect(session.employeeName, 'Bob');
    });

    test('parses Base64-encoded JSON from URL query parameter', () {
      const jsonPayload =
          '{"type":"employee_login","employeeId":"emp4","employeeName":"Alice"}';
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
      const payload =
          '  {"type":"employee_login","employeeId":"emp5","employeeName":"Sam"}  ';
      final result = notifier.connectFromQrPayload(payload);
      expect(result, isTrue);
    });
  });

  group('WorkerSession model', () {
    test('stores employeeId and employeeName', () {
      const session = WorkerSession(
        employeeId: 'e42',
        employeeName: 'Test Worker',
      );
      expect(session.employeeId, 'e42');
      expect(session.employeeName, 'Test Worker');
    });
  });
}
