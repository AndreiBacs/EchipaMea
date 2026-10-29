import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_env.dart';
import 'qr_ticket_payload.dart';
import 'worker_login_api.dart';

final sessionProvider = NotifierProvider<SessionNotifier, WorkerSession?>(
  SessionNotifier.new,
);

class SessionNotifier extends Notifier<WorkerSession?> {
  static const _mockWorkerTokenPrefix = 'mock-worker-session';

  WorkerLoginApi _api = WorkerLoginApi();

  /// Swaps the HTTP layer, for tests.
  // ignore: use_setters_to_change_properties
  void debugUseApi(WorkerLoginApi api) => _api = api;

  @override
  WorkerSession? build() => null;

  void disconnect() {
    state = null;
  }

  /// Signs a worker in from a scanned QR code.
  ///
  /// The local expiry check is kept as a fast fail -- an obviously stale code
  /// should not cost a network round trip -- but it is no longer the decision.
  /// The device used to parse the code, check the clock, and mint its own
  /// `mock-worker-session-…` token, which proved nothing and forced the server
  /// to accept unauthenticated worker traffic. Now the ticket is redeemed
  /// server-side and the session carries a real JWT.
  ///
  /// Throws [WorkerLoginException] so the UI can say *why* a scan failed;
  /// returns false only for a code that is not one of ours at all.
  Future<bool> connectFromQrPayload(String payload) async {
    final ticket = parseWorkerLoginTicket(payload);
    if (ticket == null) return false;
    if (ticket.hasExpired) {
      throw const WorkerLoginException(WorkerLoginFailure.expired);
    }

    // Mock mode: no backend configured, so the ticket cannot be redeemed and
    // the app runs on seeded demo data. This is what keeps `flutter test` and
    // `flutter build` working with an empty `.env`, which CI depends on.
    if (AppEnv.authApiBaseUrl.trim().isEmpty) {
      state = WorkerSession(
        employeeId: ticket.employeeId,
        employeeName: ticket.employeeName,
        sessionToken: _buildMockSessionToken(
          ticket.ticketId,
          ticket.employeeId,
        ),
        companyId: '',
      );
      return true;
    }

    final result = await _api.redeem(ticketId: ticket.ticketId);
    state = WorkerSession(
      // Identity comes from the server's answer, not from the scanned code:
      // the code is an input, and only the server can say who redeeming it
      // makes you.
      employeeId: result.employeeId.isNotEmpty
          ? result.employeeId
          : ticket.employeeId,
      employeeName: result.employeeName.isNotEmpty
          ? result.employeeName
          : ticket.employeeName,
      sessionToken: result.token,
      companyId: result.companyId,
    );
    return true;
  }

  String _buildMockSessionToken(String ticketId, String employeeId) {
    final safeTicket = ticketId.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '-',
    );
    final safeEmployee = employeeId.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '-',
    );
    return '$_mockWorkerTokenPrefix-$safeEmployee-$safeTicket';
  }
}

class WorkerSession {
  const WorkerSession({
    required this.employeeId,
    required this.employeeName,
    required this.sessionToken,
    this.companyId = '',
  });

  final String employeeId;
  final String employeeName;
  final String sessionToken;

  /// Empty in mock mode, where there is no server to name a tenant.
  final String companyId;

  /// True when the token is a real server-issued one rather than a local stand-in.
  bool get isAuthenticated =>
      sessionToken.isNotEmpty &&
      !sessionToken.startsWith('mock-worker-session');
}
