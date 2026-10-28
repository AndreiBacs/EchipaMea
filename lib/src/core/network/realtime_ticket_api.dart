import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_session_controller.dart';
import '../auth/session_controller.dart';
import '../config/app_env.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Tickets for the foreman notification socket, minted with the foreman's token.
final foremanRealtimeTicketApiProvider = Provider<RealtimeTicketApi>(
  (ref) => RealtimeTicketApi(ref.watch(foremanApiProvider)),
);

/// Tickets for the worker telemetry socket, minted with the worker's token.
final workerRealtimeTicketApiProvider = Provider<RealtimeTicketApi>(
  (ref) => RealtimeTicketApi(ref.watch(workerApiProvider)),
);

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
  RealtimeTicketApi(this._api);

  final ApiClient _api;

  /// Returns a ticket, or null when one cannot be obtained.
  ///
  /// Null is a normal outcome, not an error to surface: there may be no backend
  /// (mock mode), the device may be offline, or the session may have ended.
  /// Callers treat it as "do not connect" rather than as a failure to show the
  /// user -- a missing notification badge is not worth a dialog. An expired
  /// access token is refreshed by the client first, like any other call.
  Future<String?> fetchTicket() async {
    if (!AppEnv.hasBackend) return null;
    try {
      final decoded = await _api.post('/realtime/tickets');
      if (decoded is! Map<String, dynamic>) return null;
      final ticket = decoded['ticket'];
      return ticket is String && ticket.isNotEmpty ? ticket : null;
    } on ApiException {
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
