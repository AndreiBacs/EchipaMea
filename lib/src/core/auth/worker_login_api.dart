import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';

/// Result of redeeming a scanned QR login ticket.
class WorkerLoginResult {
  const WorkerLoginResult({
    required this.token,
    required this.refreshToken,
    required this.employeeId,
    required this.employeeName,
    required this.companyId,
  });

  final String token;
  final String refreshToken;
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

final workerLoginApiProvider = Provider<WorkerLoginApi>(
  (ref) => WorkerLoginApi(ref.watch(publicApiProvider)),
);

/// Exchanges a scanned QR ticket for a real worker session.
///
/// Worker login used to be entirely local: the phone parsed the QR code, checked
/// the expiry itself, and minted its own `mock-worker-session-…` token. Nothing
/// verified that the code was ever issued, and the token proved nothing, so the
/// server had to accept unauthenticated worker traffic. This is what replaces
/// that -- the ticket is redeemed server-side and comes back as a real JWT.
class WorkerLoginApi {
  WorkerLoginApi(this._api);

  final ApiClient _api;

  Future<WorkerLoginResult> redeem({required String ticketId}) async {
    Object? decoded;
    try {
      decoded = await _api.post(
        '/worker/login-tickets/redeem',
        body: {'ticketId': ticketId},
      );
    } on ApiException catch (error) {
      throw WorkerLoginException(_failureFor(error));
    }

    if (decoded is! Map<String, dynamic>) {
      throw const WorkerLoginException(WorkerLoginFailure.malformed);
    }

    // The server emits the token under both `token` and `accessToken`.
    final token = (decoded['accessToken'] ?? decoded['token']) as String?;
    final worker = decoded['worker'];
    if (token == null || token.isEmpty || worker is! Map<String, dynamic>) {
      throw const WorkerLoginException(WorkerLoginFailure.malformed);
    }

    return WorkerLoginResult(
      token: token,
      refreshToken: (decoded['refreshToken'] as String?) ?? '',
      employeeId: (worker['employeeId'] as String?) ?? '',
      employeeName: (worker['employeeName'] as String?) ?? '',
      companyId: (worker['companyId'] as String?) ?? '',
    );
  }

  /// Maps the documented `error.code` envelope onto something translatable.
  WorkerLoginFailure _failureFor(ApiException error) {
    if (error.isNetwork) return WorkerLoginFailure.network;
    switch (error.code) {
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
        return error.status >= 500
            ? WorkerLoginFailure.network
            : WorkerLoginFailure.notFound;
    }
  }
}
