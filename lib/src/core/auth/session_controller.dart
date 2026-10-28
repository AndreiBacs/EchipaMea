import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_env.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../network/single_flight.dart';
import 'qr_ticket_payload.dart';
import 'token_store.dart';
import 'worker_login_api.dart';

final sessionProvider = AsyncNotifierProvider<SessionNotifier, WorkerSession?>(
  SessionNotifier.new,
);

/// The worker's API client: sends the worker's token, refreshes it on 401,
/// and returns the worker to the connect screen when the server ends the
/// session -- for example after the foreman deactivates them.
final workerApiProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    httpClient: ref.watch(httpClientProvider),
    baseUrl: AppEnv.apiBaseUrl,
    tokens: ref.watch(sessionProvider.notifier),
  ),
);

/// Worker data providers await this first in `build()`. It waits for the
/// session to be restored, then watches who is connected, so the provider
/// rebuilds when a different worker signs in on this phone; a token refresh
/// does not rebuild it. Null means no worker is signed in: load nothing.
Future<WorkerSession?> watchWorkerSession(Ref ref) async {
  final employeeId = await ref.watch(
    sessionProvider.selectAsync((session) => session?.employeeId),
  );
  if (employeeId == null) return null;
  return ref.read(sessionProvider).value;
}

const _mockWorkerTokenPrefix = 'mock-worker-session';

class SessionNotifier extends AsyncNotifier<WorkerSession?>
    implements SessionTokens {
  static const _sessionKey = 'worker_session';

  final _refreshFlight = SingleFlight<bool>();

  TokenStore get _store => ref.read(tokenStoreProvider);

  /// Restores the session saved at the last scan.
  ///
  /// Workers stay signed in across app restarts: without that, every restart
  /// on site meant finding the foreman to scan a new code. The refresh token
  /// lasts 7 days, and deactivating the worker ends it sooner.
  @override
  Future<WorkerSession?> build() async {
    final session = WorkerSession.tryDecode(await _store.read(_sessionKey));
    if (session == null) return null;
    if (AppEnv.hasBackend && !session.isAuthenticated) {
      await _store.delete(_sessionKey);
      return null;
    }
    return session;
  }

  @override
  String? get accessToken => state.asData?.value?.sessionToken;

  /// Signs the worker out, revoking the session on the server too. Best
  /// effort: the local session ends whether or not the server answers.
  Future<void> disconnect() async {
    final session = state.asData?.value;
    if (session != null && session.isAuthenticated && AppEnv.hasBackend) {
      try {
        await ref
            .read(publicApiProvider)
            .post(
              '/auth/logout',
              headers: {'Authorization': 'Bearer ${session.sessionToken}'},
            );
      } on ApiException {
        // Offline, or already expired: nothing left to revoke.
      }
    }
    await expire();
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

    final WorkerSession session;
    if (!AppEnv.hasBackend) {
      // Mock mode: no backend configured, so the ticket cannot be redeemed and
      // the app runs on seeded demo data. This is what keeps `flutter test` and
      // `flutter build` working with an empty `.env`, which CI depends on.
      session = WorkerSession(
        employeeId: ticket.employeeId,
        employeeName: ticket.employeeName,
        sessionToken: _buildMockSessionToken(
          ticket.ticketId,
          ticket.employeeId,
        ),
      );
    } else {
      final result = await ref
          .read(workerLoginApiProvider)
          .redeem(ticketId: ticket.ticketId);
      session = WorkerSession(
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
        refreshToken: result.refreshToken,
        companyId: result.companyId,
      );
    }

    await _store.write(_sessionKey, session.encode());
    state = AsyncData(session);
    return true;
  }

  @override
  Future<bool> refresh() => _refreshFlight.run(() async {
    final session = state.asData?.value;
    if (session == null || session.refreshToken.isEmpty) return false;
    try {
      final data = await ref
          .read(publicApiProvider)
          .post('/auth/refresh', body: {'refreshToken': session.refreshToken});
      final token = data is Map<String, dynamic>
          ? (data['accessToken'] ?? data['token']) as String?
          : null;
      if (token == null || token.isEmpty) return false;
      // Signed out while the refresh was in flight: do not bring it back.
      if (state.asData?.value != session) return false;
      final next = session.copyWithTokens(
        sessionToken: token,
        refreshToken: (data as Map<String, dynamic>)['refreshToken'] as String?,
      );
      await _store.write(_sessionKey, next.encode());
      state = AsyncData(next);
      return true;
    } on ApiException catch (error) {
      if (error.isNetwork) rethrow;
      return false;
    }
  });

  @override
  Future<void> expire() async {
    await _store.delete(_sessionKey);
    state = const AsyncData(null);
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
    this.refreshToken = '',
    this.companyId = '',
  });

  final String employeeId;
  final String employeeName;

  /// The access token.
  final String sessionToken;

  /// Empty in mock mode.
  final String refreshToken;

  /// Empty in mock mode, where there is no server to name a tenant.
  final String companyId;

  /// True when the token is a real server-issued one rather than a local stand-in.
  bool get isAuthenticated =>
      sessionToken.isNotEmpty &&
      !sessionToken.startsWith(_mockWorkerTokenPrefix);

  WorkerSession copyWithTokens({
    required String sessionToken,
    String? refreshToken,
  }) => WorkerSession(
    employeeId: employeeId,
    employeeName: employeeName,
    sessionToken: sessionToken,
    refreshToken: refreshToken ?? this.refreshToken,
    companyId: companyId,
  );

  String encode() => jsonEncode({
    'employeeId': employeeId,
    'employeeName': employeeName,
    'sessionToken': sessionToken,
    'refreshToken': refreshToken,
    'companyId': companyId,
  });

  static WorkerSession? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      final token = data['sessionToken'] as String?;
      final employeeId = data['employeeId'] as String?;
      if (token == null || token.isEmpty || employeeId == null) return null;
      return WorkerSession(
        employeeId: employeeId,
        employeeName: (data['employeeName'] as String?) ?? '',
        sessionToken: token,
        refreshToken: (data['refreshToken'] as String?) ?? '',
        companyId: (data['companyId'] as String?) ?? '',
      );
    } on FormatException {
      return null;
    }
  }
}
