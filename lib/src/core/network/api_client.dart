import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_env.dart';
import 'api_exception.dart';

typedef Json = Map<String, dynamic>;

/// The session an [ApiClient] authenticates as.
///
/// Implemented by the foreman and worker session notifiers. Both sessions can
/// exist on one device at once, so each gets its own client rather than one
/// client guessing whose token to send.
abstract interface class SessionTokens {
  /// The current access token, or null when signed out.
  String? get accessToken;

  /// Exchanges the refresh token for a new pair.
  ///
  /// Returns false when the server refused it -- the session is over. Throws an
  /// [ApiException] with [ApiException.isNetwork] when the server could not be
  /// reached, because being offline must not sign anyone out.
  Future<bool> refresh();

  /// Ends the session locally after the server has rejected it for good.
  Future<void> expire();
}

/// JSON over HTTP against the EchipaMea API.
///
/// - Every non-2xx response becomes an [ApiException] carrying the server's
///   error envelope; transport failures become [ApiException.network].
/// - A 401 triggers one refresh and one retry. If that does not help, or the
///   account was disabled, the session is expired, which sends the router back
///   to the sign-in screen.
class ApiClient {
  ApiClient({
    required http.Client httpClient,
    required String baseUrl,
    this.tokens,
    this.timeout = const Duration(seconds: 20),
  }) : _http = httpClient,
       _baseUrl = baseUrl;

  final http.Client _http;
  final String _baseUrl;
  final SessionTokens? tokens;
  final Duration timeout;

  /// Resolves [path] against the base URL. An absolute `http(s)://` URL is used
  /// as-is, for the few endpoints a deployment can override.
  Uri uri(String path, [Map<String, String>? query]) {
    final absolute = path.startsWith('http://') || path.startsWith('https://');
    if (!absolute && _baseUrl.isEmpty) {
      throw const ApiException.network('No API base URL is configured.');
    }
    final parsed = Uri.parse(absolute ? path : '$_baseUrl$path');
    if (query == null || query.isEmpty) return parsed;
    return parsed.replace(
      queryParameters: {...parsed.queryParameters, ...query},
    );
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _json((headers) => _http.get(uri(path, query), headers: headers));

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => _json(
    (h) => _http.post(
      uri(path),
      headers: _withJsonBody(h, headers, body),
      body: body == null ? null : jsonEncode(body),
    ),
  );

  Future<dynamic> patch(String path, {Object? body}) => _json(
    (h) => _http.patch(
      uri(path),
      headers: _withJsonBody(h, null, body),
      body: body == null ? null : jsonEncode(body),
    ),
  );

  Future<dynamic> put(String path, {Object? body}) => _json(
    (h) => _http.put(
      uri(path),
      headers: _withJsonBody(h, null, body),
      body: body == null ? null : jsonEncode(body),
    ),
  );

  Future<dynamic> delete(String path) =>
      _json((h) => _http.delete(uri(path), headers: h));

  /// Fetches every page of a cursor-paginated list (`{items, page: {nextCursor}}`).
  ///
  /// Lists in this product are a small contractor's clients, crew and jobs, so
  /// loading them whole is cheaper than teaching every screen to page.
  Future<List<Json>> getAllPages(
    String path, {
    Map<String, String>? query,
  }) async {
    final items = <Json>[];
    String? cursor;
    do {
      final page = await get(
        path,
        query: {...?query, 'limit': '200', 'cursor': ?cursor},
      );
      if (page is! Json || page['items'] is! List) {
        throw ApiException(status: 200, code: 'INVALID_RESPONSE');
      }
      items.addAll((page['items'] as List).whereType<Json>());
      final meta = page['page'];
      cursor = meta is Json ? meta['nextCursor'] as String? : null;
    } while (cursor != null && cursor.isNotEmpty);
    return items;
  }

  /// Posts multipart/form-data. [files] is a factory because a part's byte
  /// stream can be read only once, and the request may be sent twice (401 →
  /// refresh → retry).
  Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> fields,
    required Future<List<http.MultipartFile>> Function() files,
    Duration? timeout,
  }) => _json((headers) async {
    final request = http.MultipartRequest('POST', uri(path))
      ..headers.addAll(headers)
      ..fields.addAll(fields)
      ..files.addAll(await files());
    final streamed = await _http.send(request);
    return http.Response.fromStream(streamed);
  }, timeout: timeout);

  Map<String, String> _withJsonBody(
    Map<String, String> base,
    Map<String, String>? extra,
    Object? body,
  ) => {
    ...base,
    if (body != null) 'Content-Type': 'application/json',
    ...?extra,
  };

  Future<dynamic> _json(
    Future<http.Response> Function(Map<String, String> headers) send, {
    Duration? timeout,
  }) async {
    final response = await _send(send, timeout ?? this.timeout);
    if (response.statusCode == 204 || response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(status: response.statusCode, code: 'INVALID_RESPONSE');
    }
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) send,
    Duration timeout,
  ) async {
    final tokens = this.tokens;
    var sentToken = tokens?.accessToken;
    var response = await _attempt(send, sentToken, timeout);

    if (response.statusCode == 401 && tokens != null && sentToken != null) {
      if (await tokens.refresh()) {
        sentToken = tokens.accessToken;
        response = await _attempt(send, sentToken, timeout);
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    final error = ApiException.fromResponse(
      response.statusCode,
      response.body,
      traceIdHeader: response.headers['x-trace-id'],
    );
    if (tokens != null &&
        sentToken != null &&
        (error.status == 401 || error.code == 'ACCOUNT_DISABLED')) {
      await tokens.expire();
    }
    throw error;
  }

  Future<http.Response> _attempt(
    Future<http.Response> Function(Map<String, String> headers) send,
    String? token,
    Duration timeout,
  ) async {
    final headers = {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    try {
      return await send(headers).timeout(timeout);
    } on ApiException {
      rethrow;
    } catch (_) {
      // SocketException, TimeoutException, ClientException, a failed TLS
      // handshake: from the caller's point of view, all "offline".
      throw const ApiException.network();
    }
  }
}

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Riverpod's retry policy for providers that load from the API. A failure
/// that may be transient (no response, 5xx) retries with Riverpod's default
/// backoff; a 4xx answer will not change by asking again.
Duration? apiRetry(int retryCount, Object error) {
  if (error is ApiException && !error.isNetwork && error.status < 500) {
    return null;
  }
  return ProviderContainer.defaultRetry(retryCount, error);
}

/// For the few unauthenticated calls: login, token refresh, ticket redeem.
final publicApiProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    httpClient: ref.watch(httpClientProvider),
    baseUrl: AppEnv.apiBaseUrl,
  ),
);
