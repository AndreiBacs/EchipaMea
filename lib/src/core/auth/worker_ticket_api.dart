import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_env.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'auth_session_controller.dart';
import 'qr_ticket_payload.dart';

/// A QR login ticket for one employee, ready to render.
class IssuedWorkerTicket {
  const IssuedWorkerTicket({required this.qrPayload, required this.expiresAt});

  /// Exactly what goes into the QR image.
  final String qrPayload;
  final DateTime expiresAt;

  Duration get remaining {
    final left = expiresAt.toUtc().difference(DateTime.now().toUtc());
    return left.isNegative ? Duration.zero : left;
  }
}

final workerTicketApiProvider = Provider<WorkerTicketApi>(
  (ref) => WorkerTicketApi(ref.watch(foremanApiProvider)),
);

/// Asks the server for a worker login ticket.
///
/// The foreman device used to mint these itself:
/// `ticket-<employeeId>-<microseconds>-<hex>`, which is a known employee id and
/// a coarse timestamp around roughly 31 bits of randomness — guessable, and
/// nothing on the other side ever checked whether it had been issued at all.
/// Now the server generates the secret, stores only its hash, and is the one
/// that decides whether redeeming it works.
class WorkerTicketApi {
  WorkerTicketApi(this._api);

  final ApiClient _api;

  Future<IssuedWorkerTicket> issue({
    required String employeeId,
    required String employeeName,
  }) async {
    // Mock mode: no backend, so fall back to a locally built payload. It is only
    // ever redeemed by the matching local path in SessionNotifier, which also
    // does nothing but seed demo data.
    if (!AppEnv.hasBackend) {
      return _localMockTicket(
        employeeId: employeeId,
        employeeName: employeeName,
      );
    }

    final decoded = await _api.post('/employees/$employeeId/login-ticket');
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(status: 201, code: 'INVALID_RESPONSE');
    }

    final qrPayload = decoded['qrPayload'] as String?;
    final expiresAtRaw = decoded['expiresAt'] as String?;
    if (qrPayload == null || qrPayload.isEmpty) {
      throw const ApiException(status: 201, code: 'INVALID_RESPONSE');
    }

    return IssuedWorkerTicket(
      qrPayload: qrPayload,
      expiresAt:
          DateTime.tryParse(expiresAtRaw ?? '')?.toUtc() ??
          DateTime.now().toUtc().add(const Duration(seconds: 90)),
    );
  }

  IssuedWorkerTicket _localMockTicket({
    required String employeeId,
    required String employeeName,
  }) {
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(const Duration(seconds: 90));
    // Platform-safe random source; stays under the web integer edge cases.
    final random = Random().nextInt(0x7fffffff).toRadixString(16);
    return IssuedWorkerTicket(
      qrPayload: jsonEncode({
        'type': workerLoginTicketType,
        'ticketId': 'ticket-$employeeId-${now.microsecondsSinceEpoch}-$random',
        'employeeId': employeeId,
        'employeeName': employeeName,
        'issuedAt': now.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      }),
      expiresAt: expiresAt,
    );
  }
}
