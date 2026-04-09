import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionProvider = NotifierProvider<SessionNotifier, WorkerSession?>(
  SessionNotifier.new,
);

class SessionNotifier extends Notifier<WorkerSession?> {
  @override
  WorkerSession? build() => null;

  bool connectFromQrPayload(String payload) {
    try {
      final normalizedPayload = _extractJsonPayload(payload);
      final data = jsonDecode(normalizedPayload);
      if (data is! Map<String, dynamic>) return false;
      if (data['type'] != 'employee_login') return false;
      final employeeId = data['employeeId'] as String?;
      final employeeName = data['employeeName'] as String?;
      if (employeeId == null || employeeId.isEmpty) return false;
      if (employeeName == null || employeeName.isEmpty) return false;
      state = WorkerSession(employeeId: employeeId, employeeName: employeeName);
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
}

class WorkerSession {
  const WorkerSession({required this.employeeId, required this.employeeName});

  final String employeeId;
  final String employeeName;
}
