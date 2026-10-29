import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:echipa_mea/src/core/auth/qr_ticket_payload.dart';

/// Parsing used to live inside `SessionNotifier.connectFromQrPayload`, which is
/// now an async call that redeems the ticket server-side. The parsing itself is
/// still the part worth testing exhaustively, so it moved out into a pure
/// function and these tests came with it -- same cases, no network, no
/// container.
void main() {
  String future({Duration ahead = const Duration(minutes: 1)}) =>
      DateTime.now().toUtc().add(ahead).toIso8601String();

  String payloadJson({
    String type = workerLoginTicketType,
    String? ticketId = 't1',
    String? employeeId = 'emp1',
    String? employeeName = 'John Doe',
    String? expiresAt,
  }) {
    final map = <String, Object?>{
      'type': type,
      'expiresAt': expiresAt ?? future(),
    };
    if (ticketId != null) map['ticketId'] = ticketId;
    if (employeeId != null) map['employeeId'] = employeeId;
    if (employeeName != null) map['employeeName'] = employeeName;
    return jsonEncode(map);
  }

  group('parseWorkerLoginTicket – direct JSON', () {
    test('parses a valid payload', () {
      final ticket = parseWorkerLoginTicket(payloadJson());

      expect(ticket, isNotNull);
      expect(ticket!.ticketId, 't1');
      expect(ticket.employeeId, 'emp1');
      expect(ticket.employeeName, 'John Doe');
      expect(ticket.hasExpired, isFalse);
    });

    test('rejects the wrong type field', () {
      expect(parseWorkerLoginTicket(payloadJson(type: 'other_type')), isNull);
    });

    test('rejects a missing employeeId', () {
      expect(parseWorkerLoginTicket(payloadJson(employeeId: null)), isNull);
    });

    test('rejects an empty employeeId', () {
      expect(parseWorkerLoginTicket(payloadJson(employeeId: '')), isNull);
    });

    test('rejects a missing employeeName', () {
      expect(parseWorkerLoginTicket(payloadJson(employeeName: null)), isNull);
    });

    test('rejects an empty employeeName', () {
      expect(parseWorkerLoginTicket(payloadJson(employeeName: '')), isNull);
    });

    test('rejects a missing ticketId', () {
      expect(parseWorkerLoginTicket(payloadJson(ticketId: null)), isNull);
    });

    test('rejects invalid JSON', () {
      expect(parseWorkerLoginTicket('not-json'), isNull);
    });

    test('rejects an empty string', () {
      expect(parseWorkerLoginTicket(''), isNull);
    });

    test('rejects a JSON array', () {
      expect(parseWorkerLoginTicket('[1,2,3]'), isNull);
    });

    test('rejects an unparseable expiresAt', () {
      expect(parseWorkerLoginTicket(payloadJson(expiresAt: 'soon')), isNull);
    });

    test('parses an expired ticket but flags it', () {
      // Parsing and expiry are separate answers: the caller wants to say
      // "expired" rather than "invalid code", which sends someone hunting for
      // the wrong problem.
      final ticket = parseWorkerLoginTicket(
        payloadJson(expiresAt: future(ahead: const Duration(minutes: -1))),
      );

      expect(ticket, isNotNull);
      expect(ticket!.hasExpired, isTrue);
    });

    test('trims surrounding whitespace', () {
      expect(parseWorkerLoginTicket('  ${payloadJson()}  '), isNotNull);
    });
  });

  group('parseWorkerLoginTicket – URL-wrapped', () {
    test('reads the payload from an https URL query parameter', () {
      final url =
          'https://app.example.com/login?payload=${Uri.encodeComponent(payloadJson())}';
      expect(parseWorkerLoginTicket(url)?.employeeId, 'emp1');
    });

    test('reads the payload from a custom scheme URL', () {
      final url =
          'echipamea://worker-login?payload=${Uri.encodeComponent(payloadJson())}';
      expect(parseWorkerLoginTicket(url)?.employeeId, 'emp1');
    });

    test('reads a base64-encoded payload', () {
      final encoded = base64Encode(utf8.encode(payloadJson()));
      final url = 'https://app.example.com/login?payload=$encoded';
      expect(parseWorkerLoginTicket(url)?.employeeId, 'emp1');
    });

    test('rejects a URL with no payload parameter', () {
      expect(parseWorkerLoginTicket('https://app.example.com/login'), isNull);
    });

    test('rejects a URL with an empty payload parameter', () {
      expect(
        parseWorkerLoginTicket('https://app.example.com/login?payload='),
        isNull,
      );
    });
  });
}
