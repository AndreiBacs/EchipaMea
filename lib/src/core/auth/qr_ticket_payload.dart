import 'dart:convert';

/// The QR payload a foreman device displays for a worker to scan.
class WorkerLoginTicketPayload {
  const WorkerLoginTicketPayload({
    required this.ticketId,
    required this.employeeId,
    required this.employeeName,
    required this.expiresAt,
  });

  final String ticketId;
  final String employeeId;
  final String employeeName;
  final DateTime expiresAt;

  bool get hasExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());
}

const workerLoginTicketType = 'foreman_worker_login_ticket';

/// Parses a scanned code, tolerating the three shapes it can arrive in.
///
/// Pure and synchronous on purpose: it is the part worth testing exhaustively,
/// and separating it from the network call keeps those tests as fast unit tests.
/// Returns null for anything that is not one of our tickets.
WorkerLoginTicketPayload? parseWorkerLoginTicket(String rawPayload) {
  try {
    final normalized = extractJsonPayload(rawPayload);
    final data = jsonDecode(normalized);
    if (data is! Map<String, dynamic>) return null;
    if (data['type'] != workerLoginTicketType) return null;

    final ticketId = data['ticketId'] as String?;
    final employeeId = data['employeeId'] as String?;
    final employeeName = data['employeeName'] as String?;
    final expiresAtRaw = data['expiresAt'] as String?;
    if (ticketId == null || ticketId.isEmpty) return null;
    if (employeeId == null || employeeId.isEmpty) return null;
    if (employeeName == null || employeeName.isEmpty) return null;
    if (expiresAtRaw == null || expiresAtRaw.isEmpty) return null;

    final expiresAt = DateTime.tryParse(expiresAtRaw);
    if (expiresAt == null) return null;

    return WorkerLoginTicketPayload(
      ticketId: ticketId,
      employeeId: employeeId,
      employeeName: employeeName,
      expiresAt: expiresAt,
    );
  } catch (_) {
    return null;
  }
}

/// Unwraps the payload from whichever form the scanner produced.
///
/// Accepts raw JSON, a URL carrying `?payload=<json>`, and a URL carrying
/// `?payload=<base64>` — a printed code, a deep link and a shared link all end
/// up here.
String extractJsonPayload(String rawPayload) {
  final trimmed = rawPayload.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.startsWith('{')) return trimmed;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return trimmed;

  final queryPayload = uri.queryParameters['payload'];
  if (queryPayload == null || queryPayload.isEmpty) return trimmed;

  final maybeJson = Uri.decodeComponent(queryPayload);
  if (maybeJson.startsWith('{')) return maybeJson;

  try {
    return utf8.decode(base64Decode(maybeJson));
  } catch (_) {
    return maybeJson;
  }
}
