import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/config/app_env.dart';
import '../../../core/domain/entities/worker_role.dart';
import '../../../core/network/api_client.dart';
import '../../foreman/data/employees_repository.dart';
import '../../foreman/data/project_json.dart';
import '../../foreman/data/projects_repository.dart';
import '../../foreman/data/sequences_repository.dart';
import '../../foreman/domain/entities/daily_worker_sequence.dart';
import '../../foreman/domain/entities/employee.dart';
import '../../foreman/domain/entities/project.dart';

final workerRepositoryProvider = Provider<WorkerRepository>(
  (ref) => AppEnv.hasBackend
      ? ApiWorkerRepository(ref.watch(workerApiProvider))
      : InMemoryWorkerRepository(
          projects: ref.watch(projectsRepositoryProvider),
          employees: ref.watch(employeesRepositoryProvider),
          sequences: ref.watch(sequencesRepositoryProvider),
        ),
);

/// What the signed-in worker sees and does. With a backend every call uses
/// the worker's own token and the worker endpoints, so a worker phone never
/// holds the company's whole roster or project list.
abstract interface class WorkerRepository {
  /// The worker's own record, including the working schedule that gates
  /// location telemetry. Null if the roster no longer has them.
  Future<Employee?> me(WorkerSession session);

  /// Unfinished projects assigned to the worker: in progress first, then
  /// planned, then by name.
  Future<List<Project>> projects(WorkerSession session);

  /// The worker's phase order on every project for [dayKey].
  Future<DaySequences> day(WorkerSession session, String dayKey);

  /// Tells the foremen the worker is on site.
  Future<void> announceArrival(WorkerSession session, String projectId);

  /// Submits a phase for review without a report. Returns the project after.
  Future<Project> submitPhase(
    WorkerSession session,
    String projectId,
    String phaseId,
  );
}

class ApiWorkerRepository implements WorkerRepository {
  ApiWorkerRepository(this._api);

  final ApiClient _api;

  static String _encode(String id) => Uri.encodeComponent(id);

  @override
  Future<Employee?> me(WorkerSession session) async {
    final json = await _api.get('/worker/me') as Json;
    return Employee(
      id: json['employeeId'] as String,
      name: json['name'] as String,
      role:
          WorkerRole.values.asNameMap()[json['role']] ??
          WorkerRole.generalWorker,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      workStartHour: (json['workStartHour'] as num).toInt(),
      workEndHour: (json['workEndHour'] as num).toInt(),
      workingDays: {
        for (final day in json['workingDays'] as List) (day as num).toInt(),
      },
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  @override
  Future<List<Project>> projects(WorkerSession session) async {
    final json = await _api.get('/worker/projects') as Json;
    return [
      for (final item in json['items'] as List? ?? const [])
        projectFromJson(item as Json),
    ];
  }

  @override
  Future<DaySequences> day(WorkerSession session, String dayKey) async {
    final json = await _api.get(
      '/workers/${_encode(session.employeeId)}/sequence',
      query: {'day': dayKey},
    );
    return daySequencesFromJson(json as Json, dayKey);
  }

  @override
  Future<void> announceArrival(WorkerSession session, String projectId) =>
      _api.post(
        '/worker/arrivals',
        body: {
          'projectId': projectId,
          'arrivedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );

  /// The server takes the submitting employee from the token.
  @override
  Future<Project> submitPhase(
    WorkerSession session,
    String projectId,
    String phaseId,
  ) async {
    await _api.post(
      '/projects/${_encode(projectId)}/phases/${_encode(phaseId)}/submit',
      body: const <String, dynamic>{},
    );
    return projectFromJson(
      await _api.get('/worker/projects/${_encode(projectId)}'),
    );
  }
}

/// Mock mode: the worker side of the foreman's demo data.
class InMemoryWorkerRepository implements WorkerRepository {
  InMemoryWorkerRepository({
    required ProjectsRepository projects,
    required EmployeesRepository employees,
    required SequencesRepository sequences,
  }) : _projects = projects,
       _employees = employees,
       _sequences = sequences;

  final ProjectsRepository _projects;
  final EmployeesRepository _employees;
  final SequencesRepository _sequences;

  @override
  Future<Employee?> me(WorkerSession session) async {
    for (final employee in await _employees.list()) {
      if (employee.id == session.employeeId) return employee;
    }
    return null;
  }

  /// Matches by the project's or a phase's employee ids, then by display
  /// name, because older demo projects have no employee ids. The server
  /// matches by assignment only.
  @override
  Future<List<Project>> projects(WorkerSession session) async {
    final displayName = ((await me(session))?.name ?? session.employeeName)
        .trim()
        .toLowerCase();
    final mine = [
      for (final p in await _projects.list())
        if (p.status != ProjectStatus.done &&
            (p.assignedEmployeeIds.contains(session.employeeId) ||
                p.phases.any(
                  (phase) =>
                      phase.assignedEmployeeIds.contains(session.employeeId),
                ) ||
                p.workers.any((w) => w.trim().toLowerCase() == displayName)))
          p,
    ];
    int rank(Project p) => switch (p.status) {
      ProjectStatus.inProgress => 0,
      ProjectStatus.planned => 1,
      ProjectStatus.done => 2,
    };
    return mine..sort((a, b) {
      final byStatus = rank(a).compareTo(rank(b));
      return byStatus != 0 ? byStatus : a.name.compareTo(b.name);
    });
  }

  @override
  Future<DaySequences> day(WorkerSession session, String dayKey) async {
    final all = await _sequences.forDay(dayKey);
    return DaySequences(
      dayKey: dayKey,
      sequences: [
        for (final sequence in all.sequences)
          if (sequence.workerId == session.employeeId) sequence,
      ],
    );
  }

  /// Nobody receives it: mock mode has no foreman notifications.
  @override
  Future<void> announceArrival(WorkerSession session, String projectId) async {}

  @override
  Future<Project> submitPhase(
    WorkerSession session,
    String projectId,
    String phaseId,
  ) => _projects.phaseSubmitted(projectId, phaseId, session.employeeId);
}
