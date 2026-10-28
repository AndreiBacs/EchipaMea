import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:echipa_mea/src/core/network/api_client.dart';
import 'package:echipa_mea/src/core/network/api_exception.dart';

import '../support/fake_api.dart';

class FakeTokens implements SessionTokens {
  FakeTokens(this.accessToken, {this.refreshTo, this.refreshError});

  @override
  String? accessToken;

  /// The token a refresh yields; null means the server refuses the refresh.
  String? refreshTo;
  Object? refreshError;
  int refreshCalls = 0;
  int expireCalls = 0;

  @override
  Future<bool> refresh() async {
    refreshCalls++;
    final error = refreshError;
    if (error != null) throw error;
    if (refreshTo == null) return false;
    accessToken = refreshTo;
    return true;
  }

  @override
  Future<void> expire() async {
    expireCalls++;
    accessToken = null;
  }
}

void main() {
  late FakeServer server;

  setUp(() => server = FakeServer());

  ApiClient client({SessionTokens? tokens, Duration? timeout}) => ApiClient(
    httpClient: server.client,
    baseUrl: testApiBase,
    tokens: tokens,
    timeout: timeout ?? const Duration(seconds: 5),
  );

  group('requests', () {
    test('sends the bearer token and decodes JSON', () async {
      server.on('GET', '/clients', (r) => jsonResponse({'ok': bearerOf(r)}));
      final body = await client(tokens: FakeTokens('t1')).get('/clients');
      expect(body, {'ok': 't1'});
      expect(server.requests.single.headers['Accept'], 'application/json');
    });

    test('a 204 decodes to null', () async {
      server.on('DELETE', '/clients/c1', (_) => http.Response('', 204));
      expect(
        await client(tokens: FakeTokens('t1')).delete('/clients/c1'),
        isNull,
      );
    });

    test('getAllPages follows nextCursor until the last page', () async {
      server.on('GET', '/clients', (r) {
        final cursor = r.url.queryParameters['cursor'];
        expect(r.url.queryParameters['limit'], '200');
        return jsonResponse(
          cursor == null
              ? {
                  'items': [
                    {'id': 'c1'},
                  ],
                  'page': {'limit': 200, 'nextCursor': 'next'},
                }
              : {
                  'items': [
                    {'id': 'c2'},
                  ],
                  'page': {'limit': 200},
                },
        );
      });
      final items = await client(
        tokens: FakeTokens('t1'),
      ).getAllPages('/clients');
      expect(items.map((i) => i['id']), ['c1', 'c2']);
    });
  });

  group('errors', () {
    test('carries the error envelope', () async {
      server.on(
        'POST',
        '/clients',
        (_) => errorResponse(400, 'VALIDATION_FAILED', field: 'name'),
      );
      await expectLater(
        client(tokens: FakeTokens('t1')).post('/clients', body: {}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 400)
              .having((e) => e.code, 'code', 'VALIDATION_FAILED')
              .having((e) => e.field, 'field', 'name')
              .having((e) => e.traceId, 'traceId', 'trace-VALIDATION_FAILED'),
        ),
      );
    });

    test('tolerates a body that is not the envelope', () async {
      server.on('GET', '/health/ready', (_) => http.Response('<html>', 502));
      await expectLater(
        client().get('/health/ready'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 502)
              .having((e) => e.code, 'code', isNull),
        ),
      );
    });

    test('a transport failure is a network error', () async {
      server.on('GET', '/clients', (_) => throw http.ClientException('down'));
      await expectLater(
        client(tokens: FakeTokens('t1')).get('/clients'),
        throwsA(
          isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true),
        ),
      );
    });

    test('a timeout is a network error', () async {
      server.on('GET', '/clients', (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return jsonResponse({});
      });
      await expectLater(
        client(
          tokens: FakeTokens('t1'),
          timeout: const Duration(milliseconds: 20),
        ).get('/clients'),
        throwsA(
          isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true),
        ),
      );
    });
  });

  group('401 handling', () {
    test('refreshes once and retries with the new token', () async {
      server.on(
        'GET',
        '/clients',
        (r) => bearerOf(r) == 'new'
            ? jsonResponse({'ok': true})
            : errorResponse(401, 'TOKEN_EXPIRED'),
      );
      final tokens = FakeTokens('old', refreshTo: 'new');

      expect(await client(tokens: tokens).get('/clients'), {'ok': true});
      expect(tokens.refreshCalls, 1);
      expect(server.requests.map(bearerOf), ['old', 'new']);
    });

    test('expires the session when the refresh is refused', () async {
      server.on('GET', '/clients', (_) => errorResponse(401, 'TOKEN_EXPIRED'));
      final tokens = FakeTokens('old');

      await expectLater(
        client(tokens: tokens).get('/clients'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      expect(tokens.expireCalls, 1);
      expect(server.count('GET', '/clients'), 1);
    });

    test('expires the session when the retry is refused too', () async {
      server.on('GET', '/clients', (_) => errorResponse(401, 'TOKEN_INVALID'));
      final tokens = FakeTokens('old', refreshTo: 'new');

      await expectLater(
        client(tokens: tokens).get('/clients'),
        throwsA(isA<ApiException>()),
      );
      expect(tokens.expireCalls, 1);
      expect(server.count('GET', '/clients'), 2);
    });

    test('being offline during refresh does not sign anyone out', () async {
      server.on('GET', '/clients', (_) => errorResponse(401, 'TOKEN_EXPIRED'));
      final tokens = FakeTokens(
        'old',
        refreshError: const ApiException.network(),
      );

      await expectLater(
        client(tokens: tokens).get('/clients'),
        throwsA(
          isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true),
        ),
      );
      expect(tokens.expireCalls, 0);
    });

    test('a disabled account ends the session', () async {
      server.on(
        'GET',
        '/worker/me',
        (_) => errorResponse(403, 'ACCOUNT_DISABLED'),
      );
      final tokens = FakeTokens('t1');

      await expectLater(
        client(tokens: tokens).get('/worker/me'),
        throwsA(isA<ApiException>()),
      );
      expect(tokens.expireCalls, 1);
    });

    test('a plain 403 does not', () async {
      server.on('GET', '/clients', (_) => errorResponse(403, 'FORBIDDEN'));
      final tokens = FakeTokens('t1');

      await expectLater(
        client(tokens: tokens).get('/clients'),
        throwsA(isA<ApiException>()),
      );
      expect(tokens.expireCalls, 0);
    });

    test('an unauthenticated call never refreshes', () async {
      server.on(
        'POST',
        '/foreman/login',
        (_) => errorResponse(401, 'INVALID_CREDENTIALS'),
      );
      await expectLater(
        client().post('/foreman/login', body: {}),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'INVALID_CREDENTIALS',
          ),
        ),
      );
    });

    test('a multipart retry rebuilds its file parts', () async {
      server.on(
        'POST',
        '/worker/reports',
        (r) => bearerOf(r) == 'new'
            ? jsonResponse({'id': 'r1'})
            : errorResponse(401, 'TOKEN_EXPIRED'),
      );
      var built = 0;

      final body = await client(tokens: FakeTokens('old', refreshTo: 'new'))
          .postMultipart(
            '/worker/reports',
            fields: {'phaseId': 'p1_phase_1'},
            files: () async {
              built++;
              return [http.MultipartFile.fromString('photos[]', 'jpeg')];
            },
          );
      expect(body, {'id': 'r1'});
      expect(built, 2);
    });
  });
}
