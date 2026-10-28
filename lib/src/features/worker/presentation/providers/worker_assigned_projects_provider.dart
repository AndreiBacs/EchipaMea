import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/session_controller.dart';
import '../../../../core/config/app_env.dart';
import '../../../foreman/presentation/providers/projects_controller.dart';
import '../../data/worker_repository.dart';

/// Unfinished projects assigned to the signed-in worker, in progress first.
final workerAssignedProjectsProvider =
    AsyncNotifierProvider<WorkerProjectsNotifier, List<Project>>(
      WorkerProjectsNotifier.new,
    );

class WorkerProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    final repository = ref.watch(workerRepositoryProvider);
    // In mock mode the worker's jobs are the foreman's demo projects, so a
    // foreman edit reloads them. Awaiting their first load (selectAsync), not
    // watching their value, keeps that first load from restarting this one.
    final demoProjects = AppEnv.hasBackend
        ? null
        : ref.watch(projectsProvider.selectAsync((projects) => projects));
    final session = await watchWorkerSession(ref);
    await demoProjects;
    if (session == null) return const [];
    return repository.projects(session);
  }

  /// Submits a phase for review without a report. Throws if the server
  /// refuses, e.g. PHASE_INVALID_TRANSITION for a phase already done.
  Future<void> submitPhase({
    required String projectId,
    required String phaseId,
  }) async {
    final session = ref.read(sessionProvider).value;
    if (session == null) return;
    final project = await ref
        .read(workerRepositoryProvider)
        .submitPhase(session, projectId, phaseId);
    final current = state.value;
    if (current != null) {
      state = AsyncData([
        for (final p in current)
          if (p.id == project.id) project else p,
      ]);
    }
    // The foreman's copy on this device is stale now.
    ref.invalidate(projectsProvider);
  }
}
