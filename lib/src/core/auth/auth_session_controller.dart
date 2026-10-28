import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_env.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../network/single_flight.dart';
import 'token_store.dart';

final authSessionProvider =
    AsyncNotifierProvider<AuthSessionNotifier, AuthSession?>(
      AuthSessionNotifier.new,
    );

/// The foreman's API client: sends the foreman's token, refreshes it on 401,
/// and signs the foreman out when the server ends the session.
final foremanApiProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    httpClient: ref.watch(httpClientProvider),
    baseUrl: AppEnv.apiBaseUrl,
    tokens: ref.watch(authSessionProvider.notifier),
  ),
);

const _mockForemanTokenPrefix = 'mock-foreman-token';

class AuthSessionNotifier extends AsyncNotifier<AuthSession?>
    implements SessionTokens {
  static const _sessionKey = 'foreman_session';

  // Where the token lived before it moved to secure storage. Read once, then
  // deleted, so an upgrade does not sign anyone out.
  static const _legacyTokenKey = 'foreman_auth_token';
  static const _legacyEmailKey = 'foreman_auth_email';

  final _refreshFlight = SingleFlight<bool>();

  TokenStore get _store => ref.read(tokenStoreProvider);

  @override
  Future<AuthSession?> build() async {
    await _migrateLegacyToken();
    final session = AuthSession.tryDecode(await _store.read(_sessionKey));
    if (session == null) return null;

    // A demo-mode token saved before a backend was configured would go to the
    // server as a bearer token and bounce; start from the login screen instead.
    if (AppEnv.hasBackend && session.isMock) {
      await _store.delete(_sessionKey);
      return null;
    }
    return session;
  }

  @override
  String? get accessToken => state.asData?.value?.token;

  Future<void> loginForeman({
    required String email,
    required String password,
  }) async {
    final current = state.asData?.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = AppEnv.hasBackend
          ? AuthSession.fromLoginResponse(
              await ref
                  .read(publicApiProvider)
                  .post(
                    '/foreman/login',
                    body: {'email': email, 'password': password},
                  ),
              fallbackEmail: email,
            )
          : AuthSession(
              token: _mockTokenForEmail(email, password),
              email: email,
            );
      await _store.write(_sessionKey, session.encode());
      return session;
    });
    if (state.hasError && current != null) {
      state = AsyncData(current);
    }
  }

  /// Ends the session on the server too, so the refresh token cannot be reused.
  /// Best effort: the local session ends whether or not the server answers.
  Future<void> logout() async {
    final session = state.asData?.value;
    if (session != null && !session.isMock && AppEnv.hasBackend) {
      try {
        await ref
            .read(publicApiProvider)
            .post(
              '/auth/logout',
              headers: {'Authorization': 'Bearer ${session.token}'},
            );
      } on ApiException {
        // Offline, or the token already expired: nothing left to revoke here.
      }
    }
    await expire();
  }

  @override
  Future<bool> refresh() => _refreshFlight.run(() async {
    final session = state.asData?.value;
    if (session == null || session.refreshToken.isEmpty) return false;
    try {
      final next = AuthSession.fromLoginResponse(
        await ref
            .read(publicApiProvider)
            .post(
              '/auth/refresh',
              body: {'refreshToken': session.refreshToken},
            ),
        fallbackEmail: session.email,
      );
      // Signed out while the refresh was in flight: do not bring it back.
      if (state.asData?.value != session) return false;
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

  Future<void> _migrateLegacyToken() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_legacyTokenKey);
    if (legacyToken == null) return;
    if (legacyToken.isNotEmpty && await _store.read(_sessionKey) == null) {
      final legacy = AuthSession(
        token: legacyToken,
        email: prefs.getString(_legacyEmailKey) ?? '',
      );
      await _store.write(_sessionKey, legacy.encode());
    }
    await prefs.remove(_legacyTokenKey);
    await prefs.remove(_legacyEmailKey);
  }

  /// Demo-mode login: no server, so accept anything plausible. Rejections use
  /// the server's own error code so the login screen has one message to show.
  String _mockTokenForEmail(String email, String password) {
    if (!email.contains('@') || password.length < 3) {
      throw const ApiException(status: 401, code: 'INVALID_CREDENTIALS');
    }
    final safeEmail = email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
    return '$_mockForemanTokenPrefix-$safeEmail';
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.email,
    this.refreshToken = '',
    this.userId = '',
    this.companyId = '',
    this.fullName = '',
  });

  /// Parses `POST /foreman/login` and `POST /auth/refresh`, which share a shape.
  factory AuthSession.fromLoginResponse(
    Object? data, {
    required String fallbackEmail,
  }) {
    if (data is! Map<String, dynamic>) {
      throw const ApiException(status: 200, code: 'INVALID_RESPONSE');
    }
    final token = (data['accessToken'] ?? data['token']) as String?;
    if (token == null || token.isEmpty) {
      throw const ApiException(status: 200, code: 'INVALID_RESPONSE');
    }
    final user = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final email = user['email'] as String?;
    return AuthSession(
      token: token,
      refreshToken: (data['refreshToken'] as String?) ?? '',
      email: email == null || email.isEmpty ? fallbackEmail : email,
      userId: (user['id'] as String?) ?? '',
      companyId: (user['companyId'] as String?) ?? '',
      fullName: (user['fullName'] as String?) ?? '',
    );
  }

  /// The access token.
  final String token;
  final String email;

  /// Empty in demo mode, and for a session migrated from before refresh tokens
  /// were kept -- that one lasts until its access token expires.
  final String refreshToken;
  final String userId;
  final String companyId;
  final String fullName;

  bool get isMock => token.startsWith(_mockForemanTokenPrefix);

  String encode() => jsonEncode({
    'token': token,
    'email': email,
    'refreshToken': refreshToken,
    'userId': userId,
    'companyId': companyId,
    'fullName': fullName,
  });

  static AuthSession? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) return null;
      return AuthSession(
        token: token,
        email: (data['email'] as String?) ?? '',
        refreshToken: (data['refreshToken'] as String?) ?? '',
        userId: (data['userId'] as String?) ?? '',
        companyId: (data['companyId'] as String?) ?? '',
        fullName: (data['fullName'] as String?) ?? '',
      );
    } on FormatException {
      return null;
    }
  }
}
