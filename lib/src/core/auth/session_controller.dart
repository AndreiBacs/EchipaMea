import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionProvider = NotifierProvider<SessionNotifier, WorkerSession?>(
  SessionNotifier.new,
);

class SessionNotifier extends Notifier<WorkerSession?> {
  static const _workerLoginTicketType = 'foreman_worker_login_ticket';
  static const _mockWorkerTokenPrefix = 'mock-worker-session';

  @override
  WorkerSession? build() => null;

  void disconnect() {
    state = null;
  }

  bool connectFromQrPayload(String payload) {
    try {
      final normalizedPayload = _extractJsonPayload(payload);
      final data = jsonDecode(normalizedPayload);
      if (data is! Map<String, dynamic>) return false;
      if (data['type'] != _workerLoginTicketType) return false;
      final ticketId = data['ticketId'] as String?;
      final employeeId = data['employeeId'] as String?;
      final employeeName = data['employeeName'] as String?;
      final expiresAtRaw = data['expiresAt'] as String?;
      if (ticketId == null || ticketId.isEmpty) return false;
      if (employeeId == null || employeeId.isEmpty) return false;
      if (employeeName == null || employeeName.isEmpty) return false;
      if (expiresAtRaw == null || expiresAtRaw.isEmpty) return false;
      final expiresAt = DateTime.tryParse(expiresAtRaw);
      if (expiresAt == null) return false;
      if (DateTime.now().isAfter(expiresAt.toUtc())) return false;

      state = WorkerSession(
        employeeId: employeeId,
        employeeName: employeeName,
        sessionToken: _buildMockSessionToken(ticketId, employeeId),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String _extractJsonPayload(String rawPayload) {
    final trimmed = rawPayload.trim();
    if (trimmed.isEmpty) return trimmed;

    // Allow direct JSON payloads and URL-wrapped payloads:
    // https://.../login?payload=<json or base64>
    // echipamea://worker-login?payload=<json or base64>
    if (trimmed.startsWith('{')) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;

    final queryPayload = uri.queryParameters['payload'];
    if (queryPayload == null || queryPayload.isEmpty) {
      return trimmed;
    }

    final maybeJson = Uri.decodeComponent(queryPayload);
    if (maybeJson.startsWith('{')) {
      return maybeJson;
    }

    try {
      return utf8.decode(base64Decode(maybeJson));
    } catch (_) {
      return maybeJson;
    }
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
  });

  final String employeeId;
  final String employeeName;
  final String sessionToken;
}
