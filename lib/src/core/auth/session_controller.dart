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
      final data = jsonDecode(payload);
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
}

class WorkerSession {
  const WorkerSession({required this.employeeId, required this.employeeName});

  final String employeeId;
  final String employeeName;
}
