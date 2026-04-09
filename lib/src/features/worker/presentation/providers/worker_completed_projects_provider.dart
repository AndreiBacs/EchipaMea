import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Project IDs the current worker has finished locally (report submitted).
///
/// Keeps the worker queue accurate without the worker feature mutating the
/// shared foreman projects list. Foreman UI is updated when a
/// `worker_report_submitted` websocket event is handled in the foreman
/// notifications layer.
final workerCompletedProjectIdsProvider =
    NotifierProvider<WorkerCompletedProjectIdsNotifier, Set<String>>(
  WorkerCompletedProjectIdsNotifier.new,
);

class WorkerCompletedProjectIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void markCompleted(String projectId) {
    if (projectId.isEmpty) return;
    state = {...state, projectId};
  }
}
