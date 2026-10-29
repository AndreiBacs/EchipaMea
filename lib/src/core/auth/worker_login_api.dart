import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_env.dart';

/// Result of redeeming a scanned QR login ticket.
class WorkerLoginResult {
  const WorkerLoginResult({
    required this.token,
    required this.employeeId,
    required this.employeeName,
    required this.companyId,
  });

  final String token;
  final String employeeId;
  final String employeeName;
  final String companyId;
}

/// Why a scan did not produce a session, in terms the UI can translate.
enum WorkerLoginFailure {
  /// The scanned code is not one of ours, or is unreadable.
  malformed,

  /// Well-formed, but the server does not know it.
  notFound,

  /// Past its expiry. QR codes are short-lived on purpose.
  expired,

  /// Someone already scanned this one.
  alreadyUsed,

  /// The employee has been deactivated.
  accountDisabled,

  /// Could not reach the server at all.
  network,
}

class WorkerLoginException implements Exception {
  const WorkerLoginException(this.failure);
  final WorkerLoginFailure failure;
}

/// Exchanges a scanned QR ticket for a real worker session.
///
/// Worker login used to be entirely local: the phone parsed the QR code, checked
/// the expiry itself, and minted its own `mock-worker-session-…` token. Nothing
/// verified that the code was ever issued, and the token proved nothing, so the
/// server had to accept unauthenticated worker traffic. This is what replaces
/// that -- the ticket is redeemed server-side and comes back as a real JWT.
class WorkerLoginApi {
  WorkerLoginApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 20);

  Future<WorkerLoginResult> redeem({required String ticketId}) async {
    final base = AppEnv.authApiBaseUrl.trim();
    if (base.isEmpty) {
      throw const WorkerLoginException(WorkerLoginFailure.network);
    }

    final uri = Uri.tryParse(
      '${base.replaceAll(RegExp(r'/+$'), '')}/worker/login-tickets/redeem',
    );
    if (uri == null) {
      throw const WorkerLoginException(WorkerLoginFailure.network);
    }

    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'ticketId': ticketId}),
          )
          .timeout(_timeout);
    } catch (_) {
      throw const WorkerLoginException(WorkerLoginFailure.network);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WorkerLoginException(_failureFor(response));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const WorkerLoginException(WorkerLoginFailure.malformed);
    }

    // The server emits the token under both `token` and `accessToken`.
    final token = (decoded['token'] ?? decoded['accessToken']) as String?;
    final worker = decoded['worker'];
    if (token == null || token.isEmpty || worker is! Map<String, dynamic>) {
      throw const WorkerLoginException(WorkerLoginFailure.malformed);
    }

    return WorkerLoginResult(
      token: token,
      employeeId: (worker['employeeId'] as String?) ?? '',
      employeeName: (worker['employeeName'] as String?) ?? '',
      companyId: (worker['companyId'] as String?) ?? '',
    );
  }

  /// Maps the documented `error.code` envelope onto something translatable.
  WorkerLoginFailure _failureFor(http.Response response) {
    String? code;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) code = error['code'] as String?;
      }
    } catch (_) {
      code = null;
    }

    switch (code) {
      case 'TICKET_EXPIRED':
        return WorkerLoginFailure.expired;
      case 'TICKET_ALREADY_REDEEMED':
        return WorkerLoginFailure.alreadyUsed;
      case 'ACCOUNT_DISABLED':
        return WorkerLoginFailure.accountDisabled;
      case 'TICKET_NOT_FOUND':
      case 'TICKET_MALFORMED':
        return WorkerLoginFailure.notFound;
      default:
        return response.statusCode >= 500
            ? WorkerLoginFailure.network
            : WorkerLoginFailure.notFound;
    }
  }
}
