import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_session_controller.dart';
import '../../data/sequences_repository.dart';
import '../../domain/entities/daily_worker_sequence.dart';
import 'projects_controller.dart';
export '../../domain/entities/daily_worker_sequence.dart';

/// Every worker's sequence for one day, keyed by `YYYY-MM-DD` (see
/// `dayKey`). Disposed when no screen shows that day.
final daySequencesProvider = AsyncNotifierProvider.autoDispose
    .family<DaySequencesNotifier, DaySequences, String>(
      DaySequencesNotifier.new,
    );

class DaySequencesNotifier extends AsyncNotifier<DaySequences> {
  DaySequencesNotifier(this.dayKey);

  final String dayKey;

  SequencesRepository get _repository => ref.read(sequencesRepositoryProvider);

  @override
  Future<DaySequences> build() async {
    final repository = ref.watch(sequencesRepositoryProvider);
    // Suggestions follow the phases, so any project change reloads them.
    // Waiting for the projects' first load also avoids fetching twice.
    final projectsLoaded = ref.watch(
      projectsProvider.selectAsync((projects) => projects),
    );
    if (!await watchForemanScope(ref)) return DaySequences(dayKey: dayKey);
    await projectsLoaded;
    return repository.forDay(dayKey);
  }

  /// Saves the foreman's order for one worker on one project. Throws if the
  /// server refuses it, leaving the state alone.
  Future<void> save({
    required String projectId,
    required String workerId,
    required List<String> orderedPhaseIds,
  }) async {
    await _repository.save(
      projectId: projectId,
      workerId: workerId,
      dayKey: dayKey,
      orderedPhaseIds: orderedPhaseIds,
    );
    state = AsyncData(await _repository.forDay(dayKey));
  }

  /// Goes back to the suggested order.
  Future<void> reset({
    required String projectId,
    required String workerId,
  }) async {
    await _repository.reset(
      projectId: projectId,
      workerId: workerId,
      dayKey: dayKey,
    );
    state = AsyncData(await _repository.forDay(dayKey));
  }
}
