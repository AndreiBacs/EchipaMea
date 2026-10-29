import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_env.dart';

/// Fetches a single-use ticket for a WebSocket handshake.
///
/// Dart cannot set headers on a WebSocket from Flutter web, so the credential
/// has to travel in the query string. Putting the access token there would
/// write it into every proxy and access log along the way; a ticket is valid
/// once and for about a minute, so a copy in a log is worthless by the time
/// anyone reads it.
///
/// Single-use means one fetch per connection attempt, reconnects included.
class RealtimeTicketApi {
  RealtimeTicketApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  /// Returns a ticket, or null when one cannot be obtained.
  ///
  /// Null is a normal outcome, not an error to surface: the base URL may be
  /// unset (mock mode), the device may be offline, or the token may have
  /// expired. Callers treat it as "do not connect" rather than as a failure to
  /// show the user -- a missing notification badge is not worth a dialog.
  Future<String?> fetchTicket({required String accessToken}) async {
    final base = AppEnv.authApiBaseUrl.trim();
    if (base.isEmpty || accessToken.isEmpty) return null;

    final uri = Uri.tryParse(
      '${base.replaceAll(RegExp(r'/+$'), '')}/realtime/tickets',
    );
    if (uri == null) return null;

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Accept': 'application/json',
            },
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final ticket = decoded['ticket'];
      return ticket is String && ticket.isNotEmpty ? ticket : null;
    } catch (_) {
      return null;
    }
  }
}

/// Appends `?ticket=` to a configured socket URL, preserving anything already
/// in its query string -- the deployment may already carry a bootstrap key
/// there.
Uri? socketUriWithTicket(String configuredUrl, String? ticket) {
  final uri = Uri.tryParse(configuredUrl.trim());
  if (uri == null || !(uri.scheme == 'ws' || uri.scheme == 'wss')) return null;
  if (ticket == null || ticket.isEmpty) return uri;
  return uri.replace(
    queryParameters: {...uri.queryParameters, 'ticket': ticket},
  );
}
