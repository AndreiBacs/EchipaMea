import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_session_controller.dart';
import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/util/day_key.dart';
import '../domain/entities/daily_worker_sequence.dart';
import '../domain/entities/project.dart';
import 'projects_repository.dart';

final sequencesRepositoryProvider = Provider<SequencesRepository>(
  (ref) => AppEnv.hasBackend
      ? ApiSequencesRepository(ref.watch(foremanApiProvider))
      : InMemorySequencesRepository(ref.watch(projectsRepositoryProvider)),
);

/// Daily worker sequences. Only a foreman's manual orders are stored; a
/// suggestion is worked out from the phases on every read, so it follows
/// changes to their dates and assignments.
abstract interface class SequencesRepository {
  /// Every (project, worker) pair with something to do on [dayKey], plus any
  /// pair with a saved order.
  Future<DaySequences> forDay(String dayKey);

  /// Saves a manual order for the day.
  Future<void> save({
    required String projectId,
    required String workerId,
    required String dayKey,
    required List<String> orderedPhaseIds,
  });

  /// Drops the manual order, so the suggestion applies again.
  Future<void> reset({
    required String projectId,
    required String workerId,
    required String dayKey,
  });
}

class ApiSequencesRepository implements SequencesRepository {
  ApiSequencesRepository(this._api);

  final ApiClient _api;

  static String _path(String projectId, String workerId, String dayKey) =>
      '/projects/${Uri.encodeComponent(projectId)}'
      '/workers/${Uri.encodeComponent(workerId)}/sequence?day=$dayKey';

  @override
  Future<DaySequences> forDay(String dayKey) async {
    final json = await _api.get('/sequences', query: {'day': dayKey});
    return daySequencesFromJson(json as Json, dayKey);
  }

  @override
  Future<void> save({
    required String projectId,
    required String workerId,
    required String dayKey,
    required List<String> orderedPhaseIds,
  }) => _api.put(
    _path(projectId, workerId, dayKey),
    body: {'orderedPhaseIds': orderedPhaseIds},
  );

  @override
  Future<void> reset({
    required String projectId,
    required String workerId,
    required String dayKey,
  }) => _api.delete(_path(projectId, workerId, dayKey));
}

/// Parses the server's `DaySequencesDto`, which both the company-wide day and
/// one worker's day use.
DaySequences daySequencesFromJson(Json json, String dayKey) {
  List<String> strings(Object? value) => [
    for (final item in value as List? ?? const []) item as String,
  ];
  return DaySequences(
    dayKey: json['dayKey'] as String? ?? dayKey,
    sequences: [
      for (final item in json['sequences'] as List? ?? const [])
        DailyWorkerSequence(
          projectId: (item as Json)['projectId'] as String,
          dayKey: item['dayKey'] as String,
          workerId: item['workerId'] as String,
          orderedPhaseIds: strings(item['orderedPhaseIds']),
          suggestedPhaseIds: strings(item['suggestedPhaseIds']),
          isManual: item['isManual'] as bool? ?? false,
        ),
    ],
  );
}

/// Mock mode: manual orders kept for as long as the app runs, with
/// suggestions worked out the way the server does.
class InMemorySequencesRepository implements SequencesRepository {
  InMemorySequencesRepository(this._projects);

  final ProjectsRepository _projects;
  final _manual = <String, List<String>>{};

  static String _key(String projectId, String workerId, String dayKey) =>
      '$projectId|$dayKey|$workerId';

  @override
  Future<DaySequences> forDay(String dayKey) async {
    final day = dayFromKey(dayKey);
    final sequences = <DailyWorkerSequence>[];
    for (final project in await _projects.list()) {
      final workerIds = <String>{
        for (final phase in project.phases) ...phase.assignedEmployeeIds,
        for (final key in _manual.keys)
          if (key.startsWith('${project.id}|$dayKey|')) key.split('|').last,
      };
      for (final workerId in workerIds) {
        final suggested = _suggest(project, workerId, day);
        final stored = _manual[_key(project.id, workerId, dayKey)];
        if (suggested.isEmpty && stored == null) continue;
        sequences.add(
          DailyWorkerSequence(
            projectId: project.id,
            dayKey: dayKey,
            workerId: workerId,
            orderedPhaseIds: stored == null
                ? suggested
                : _reconcile(stored, suggested, {
                    for (final phase in project.phases) phase.id,
                  }),
            suggestedPhaseIds: suggested,
            isManual: stored != null,
          ),
        );
      }
    }
    return DaySequences(dayKey: dayKey, sequences: sequences);
  }

  @override
  Future<void> save({
    required String projectId,
    required String workerId,
    required String dayKey,
    required List<String> orderedPhaseIds,
  }) async {
    _manual[_key(projectId, workerId, dayKey)] = [...orderedPhaseIds];
  }

  @override
  Future<void> reset({
    required String projectId,
    required String workerId,
    required String dayKey,
  }) async {
    _manual.remove(_key(projectId, workerId, dayKey));
  }

  /// The worker's phases whose window covers [day], by start then name.
  static List<String> _suggest(Project project, String workerId, DateTime day) {
    bool covers(ProjectPhase phase) {
      final start = DateTime(
        phase.startDate.year,
        phase.startDate.month,
        phase.startDate.day,
      );
      final end = DateTime(
        phase.endDate.year,
        phase.endDate.month,
        phase.endDate.day,
      );
      return !day.isBefore(start) && !day.isAfter(end);
    }

    final phases =
        [
          for (final phase in project.phases)
            if (phase.assignedEmployeeIds.contains(workerId) && covers(phase))
              phase,
        ]..sort((a, b) {
          final byStart = a.startDate.compareTo(b.startDate);
          return byStart != 0 ? byStart : a.name.compareTo(b.name);
        });
    return [for (final phase in phases) phase.id];
  }

  /// A saved order drifts as phases change: ids of deleted phases are
  /// dropped, and newly suggested phases are appended rather than hidden, so
  /// no newly assigned work disappears from the worker's day.
  static List<String> _reconcile(
    List<String> stored,
    List<String> suggested,
    Set<String> knownPhaseIds,
  ) {
    final result = <String>[];
    for (final id in stored) {
      if (knownPhaseIds.contains(id) && !result.contains(id)) result.add(id);
    }
    for (final id in suggested) {
      if (!result.contains(id)) result.add(id);
    }
    return result;
  }
}
