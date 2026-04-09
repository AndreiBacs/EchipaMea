import 'package:flutter_riverpod/flutter_riverpod.dart';

final workerForemanInboxProvider =
    NotifierProvider<WorkerForemanInboxNotifier, List<WorkerForemanEvent>>(
      WorkerForemanInboxNotifier.new,
    );

// TODO: Persist arrival/report events when app storage or backend sync exists.
class WorkerForemanInboxNotifier extends Notifier<List<WorkerForemanEvent>> {
  @override
  List<WorkerForemanEvent> build() => const [];

  void announceArrival({
    required String projectId,
    required String projectName,
    required String employeeId,
    required String employeeName,
  }) {
    state = [
      ...state,
      WorkerArrivalEvent(
        at: DateTime.now().toUtc(),
        projectId: projectId,
        projectName: projectName,
        employeeId: employeeId,
        employeeName: employeeName,
      ),
    ];
  }

  void submitReport(WorkerReportSubmittedEvent event) {
    state = [...state, event];
  }
}

sealed class WorkerForemanEvent {
  const WorkerForemanEvent({required this.at});

  final DateTime at;
}

final class WorkerArrivalEvent extends WorkerForemanEvent {
  const WorkerArrivalEvent({
    required super.at,
    required this.projectId,
    required this.projectName,
    required this.employeeId,
    required this.employeeName,
  });

  final String projectId;
  final String projectName;
  final String employeeId;
  final String employeeName;
}

final class WorkerReportSubmittedEvent extends WorkerForemanEvent {
  const WorkerReportSubmittedEvent({
    required super.at,
    required this.projectId,
    required this.projectName,
    required this.employeeId,
    required this.employeeName,
    required this.description,
    required this.photoCount,
    required this.hasVoiceMemo,
  });

  final String projectId;
  final String projectName;
  final String employeeId;
  final String employeeName;
  final String description;
  final int photoCount;
  final bool hasVoiceMemo;
}
