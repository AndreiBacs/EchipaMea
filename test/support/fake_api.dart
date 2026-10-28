import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:echipa_mea/src/core/auth/auth_session_controller.dart';
import 'package:echipa_mea/src/core/auth/token_store.dart';
import 'package:echipa_mea/src/core/config/app_env.dart';
import 'package:echipa_mea/src/core/network/api_client.dart';

const testApiBase = 'http://api.test';

/// Switches the app out of mock mode for one test, pointing it at [testApiBase].
void useFakeBackend() {
  AppEnv.authApiBaseUrl = testApiBase;
  addTearDown(() => AppEnv.authApiBaseUrl = '');
}

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response http204() => http.Response('', 204);

http.Response errorResponse(int status, String code, {String? field}) =>
    jsonResponse({
      'error': {'code': code, 'message': 'server says $code', 'field': ?field},
      'traceId': 'trace-$code',
    }, status);

typedef Handler = FutureOr<http.Response> Function(http.Request request);

/// A scripted API: routes `METHOD /path` to a handler and records every request.
/// Unrouted calls answer 404 NOT_FOUND, like the real server.
class FakeServer {
  final requests = <http.Request>[];
  final _routes = <String, Handler>{};

  void on(String method, String path, Handler handler) =>
      _routes['$method $path'] = handler;

  late final http.Client client = MockClient((request) async {
    requests.add(request);
    final handler = _routes['${request.method} ${request.url.path}'];
    if (handler == null) return errorResponse(404, 'NOT_FOUND');
    return handler(request);
  });

  int count(String method, String path) =>
      requests.where((r) => r.method == method && r.url.path == path).length;
}

/// The bearer token a request carried, or null.
String? bearerOf(http.Request request) {
  final header = request.headers['Authorization'];
  return header != null && header.startsWith('Bearer ')
      ? header.substring(7)
      : null;
}

Map<String, dynamic> jsonBodyOf(http.Request request) =>
    jsonDecode(request.body) as Map<String, dynamic>;

ProviderContainer makeApiContainer({FakeServer? server, TokenStore? store}) {
  final container = ProviderContainer(
    overrides: [
      if (server != null) httpClientProvider.overrideWithValue(server.client),
      tokenStoreProvider.overrideWithValue(store ?? MemoryTokenStore()),
    ],
    // A failed load stays failed, so a test sees exactly the requests it made.
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  return container;
}

/// A store holding a signed-in foreman, as if restored at startup.
MemoryTokenStore foremanStore({
  String userId = 'foreman_local',
  String access = 'access-1',
}) => MemoryTokenStore({
  'foreman_session': AuthSession(
    token: access,
    email: 'foreman@echipamea.local',
    refreshToken: 'refresh-1',
    userId: userId,
    companyId: 'demo-company',
  ).encode(),
});

/// A login/refresh response as the server shapes it.
Map<String, dynamic> loginBody({
  required String access,
  required String refresh,
  String email = 'foreman@echipamea.local',
}) => {
  'token': access,
  'accessToken': access,
  'tokenType': 'Bearer',
  'expiresIn': 3600,
  'refreshToken': refresh,
  'refreshExpiresIn': 2592000,
  'user': {
    'id': 'foreman_local',
    'email': email,
    'role': 'foreman',
    'companyId': 'demo-company',
    'fullName': 'Sef de echipa',
  },
};
