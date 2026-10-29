import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_session_controller.dart';
import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/project.dart';
import 'project_json.dart';

final projectsRepositoryProvider = Provider<ProjectsRepository>(
  (ref) => AppEnv.hasBackend
      ? ApiProjectsRepository(ref.watch(foremanApiProvider))
      : InMemoryProjectsRepository(),
);

/// Projects and their phases. Every change returns the whole project as
/// stored, because one phase changing can change the project's derived status
/// and worker list.
abstract interface class ProjectsRepository {
  Future<List<Project>> list();

  /// Saves a new project with its phases; ids in [draft] are ignored.
  Future<Project> create(Project draft);

  /// Saves the project's own fields. Its phases are left as they are; they
  /// change through the phase methods.
  Future<Project> update(Project project);

  /// Closes the project, whatever its phases say.
  Future<Project> markDone(String projectId);

  /// Undoes [markDone]: the status is derived from the phases again.
  Future<Project> reopen(String projectId);

  /// Appends a phase; [draft]'s id and status are ignored.
  Future<Project> addPhase(String projectId, ProjectPhase draft);

  Future<Project> updatePhase(String projectId, ProjectPhase phase);

  Future<Project> removePhase(String projectId, String phaseId);

  /// A worker submitted [phaseId] for review with their report.
  Future<Project> phaseSubmitted(
    String projectId,
    String phaseId,
    String employeeId,
  );

  /// Approves the phase (done) or rejects it (back to in progress).
  Future<Project> reviewPhase(
    String projectId,
    String phaseId, {
    required bool approved,
    String? reviewNotes,
  });
}

class ApiProjectsRepository implements ProjectsRepository {
  ApiProjectsRepository(this._api);

  final ApiClient _api;

  static String _project(String id) => '/projects/${Uri.encodeComponent(id)}';

  static String _phase(String projectId, String phaseId) =>
      '${_project(projectId)}/phases/${Uri.encodeComponent(phaseId)}';

  Future<Project> _get(String projectId) async =>
      projectFromJson(await _api.get(_project(projectId)));

  @override
  Future<List<Project>> list() async => [
    for (final json in await _api.getAllPages(
      '/projects',
      query: {'include': 'phases'},
    ))
      projectFromJson(json),
  ];

  @override
  Future<Project> create(Project draft) async => projectFromJson(
    await _api.post('/projects', body: projectCreateToJson(draft)),
  );

  @override
  Future<Project> update(Project project) async => projectFromJson(
    await _api.patch(_project(project.id), body: projectFieldsToJson(project)),
  );

  @override
  Future<Project> markDone(String projectId) async =>
      projectFromJson(await _api.post('${_project(projectId)}/done'));

  @override
  Future<Project> reopen(String projectId) async =>
      projectFromJson(await _api.post('${_project(projectId)}/reopen'));

  @override
  Future<Project> addPhase(String projectId, ProjectPhase draft) async {
    await _api.post('${_project(projectId)}/phases', body: phaseToJson(draft));
    return _get(projectId);
  }

  @override
  Future<Project> updatePhase(String projectId, ProjectPhase phase) async {
    await _api.patch(_phase(projectId, phase.id), body: phaseToJson(phase));
    return _get(projectId);
  }

  @override
  Future<Project> removePhase(String projectId, String phaseId) async {
    await _api.delete(_phase(projectId, phaseId));
    return _get(projectId);
  }

  /// The worker's report upload already moved the phase on the server, so
  /// this only fetches the result.
  @override
  Future<Project> phaseSubmitted(
    String projectId,
    String phaseId,
    String employeeId,
  ) => _get(projectId);

  @override
  Future<Project> reviewPhase(
    String projectId,
    String phaseId, {
    required bool approved,
    String? reviewNotes,
  }) async => projectFromJson(
    await _api.post(
      '${_phase(projectId, phaseId)}/review',
      body: {'approved': approved, 'reviewNotes': ?reviewNotes},
    ),
  );
}

/// Mock mode: the demo projects, kept for as long as the app runs. It applies
/// the server's rules: statuses are derived from the phases, and unknown ids
/// are NOT_FOUND.
class InMemoryProjectsRepository implements ProjectsRepository {
  final _projects = _demoProjects();

  static const _notFound = ApiException(status: 404, code: 'NOT_FOUND');

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  Project _change(String projectId, Project Function(Project) apply) {
    final index = _projects.indexWhere((p) => p.id == projectId);
    if (index < 0) throw _notFound;
    return _projects[index] = apply(_projects[index]);
  }

  static List<ProjectPhase> _changePhase(
    Project project,
    String phaseId,
    ProjectPhase Function(ProjectPhase) apply,
  ) {
    if (!project.phases.any((p) => p.id == phaseId)) throw _notFound;
    return [
      for (final phase in project.phases)
        if (phase.id == phaseId) apply(phase) else phase,
    ];
  }

  @override
  Future<List<Project>> list() async => List.unmodifiable(_projects);

  @override
  Future<Project> create(Project draft) async {
    final created = draft.copyWith(
      id: 'p${_projects.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
      status: projectStatusFromPhases(draft.phases),
    );
    _projects.add(created);
    return created;
  }

  @override
  Future<Project> update(Project project) async => _change(
    project.id,
    (current) =>
        project.copyWith(phases: current.phases, status: current.status),
  );

  @override
  Future<Project> markDone(String projectId) async =>
      _change(projectId, (p) => p.copyWith(status: ProjectStatus.done));

  @override
  Future<Project> reopen(String projectId) async => _change(
    projectId,
    (p) => p.copyWith(status: projectStatusFromPhases(p.phases)),
  );

  @override
  Future<Project> addPhase(String projectId, ProjectPhase draft) async {
    final phase = draft.copyWith(
      id: '${projectId}_phase_${DateTime.now().millisecondsSinceEpoch}',
      startDate: _day(draft.startDate),
      endDate: _day(draft.endDate),
      status: PhaseStatus.notStarted,
    );
    return _change(projectId, (p) {
      final phases = [...p.phases, phase];
      return p.copyWith(
        phases: phases,
        status: projectStatusFromPhases(phases),
      );
    });
  }

  @override
  Future<Project> updatePhase(String projectId, ProjectPhase phase) async =>
      _change(
        projectId,
        (p) => p.copyWith(
          phases: _changePhase(
            p,
            phase.id,
            (_) => phase.copyWith(
              startDate: _day(phase.startDate),
              endDate: _day(phase.endDate),
            ),
          ),
        ),
      );

  @override
  Future<Project> removePhase(String projectId, String phaseId) async =>
      _change(projectId, (p) {
        if (!p.phases.any((phase) => phase.id == phaseId)) throw _notFound;
        final phases = [
          for (final phase in p.phases)
            if (phase.id != phaseId) phase,
        ];
        return p.copyWith(
          phases: phases,
          status: projectStatusFromPhases(phases),
        );
      });

  @override
  Future<Project> phaseSubmitted(
    String projectId,
    String phaseId,
    String employeeId,
  ) async {
    final submitter = employeeId.trim();
    return _change(
      projectId,
      (p) => p.copyWith(
        status: ProjectStatus.inProgress,
        phases: _changePhase(p, phaseId, (phase) {
          if (phase.status == PhaseStatus.done) {
            throw const ApiException(
              status: 409,
              code: 'PHASE_INVALID_TRANSITION',
            );
          }
          return phase.copyWith(
            status: PhaseStatus.pendingReview,
            submittedAt: DateTime.now(),
            submittedByEmployeeIds: [
              ...phase.submittedByEmployeeIds,
              if (submitter.isNotEmpty &&
                  !phase.submittedByEmployeeIds.contains(submitter))
                submitter,
            ],
          );
        }),
      ),
    );
  }

  @override
  Future<Project> reviewPhase(
    String projectId,
    String phaseId, {
    required bool approved,
    String? reviewNotes,
  }) async => _change(projectId, (p) {
    final phases = _changePhase(
      p,
      phaseId,
      (phase) => phase.copyWith(
        status: approved ? PhaseStatus.done : PhaseStatus.inProgress,
        reviewedAt: DateTime.now(),
        reviewedByForemanId: 'foreman_local',
        reviewNotes: reviewNotes,
      ),
    );
    return p.copyWith(phases: phases, status: projectStatusFromPhases(phases));
  });
}

List<Project> _demoProjects() => [
  Project(
    id: 'p1',
    name: 'Renovation - Main Street 15',
    clientId: 'c1',
    status: ProjectStatus.inProgress,
    workers: ['Andrei D.', 'Vlad P.'],
    assignedEmployeeIds: ['e1'],
    useClientAddress: true,
    addressLine1: 'Str. Victoriei 12',
    city: 'Bucuresti',
    state: 'Bucuresti',
    zipCode: '010072',
    latitude: 46.7723,
    longitude: 23.6236,
    phases: [
      ProjectPhase(
        id: 'p1_phase_1',
        name: 'Demolition',
        startDate: DateTime(2026, 4, 13),
        endDate: DateTime(2026, 4, 16),
        description: 'Strip interior down to studs; dispose debris.',
        workInstructions: [
          PhaseWorkInstruction(
            id: 'p1_wi_1',
            text: 'Disconnect utilities before starting.',
          ),
          PhaseWorkInstruction(
            id: 'p1_wi_2',
            text: 'Bag and label hazardous debris separately.',
          ),
        ],
        assignedEmployeeIds: ['e1'],
        status: PhaseStatus.inProgress,
      ),
      ProjectPhase(
        id: 'p1_phase_2',
        name: 'Finishing',
        startDate: DateTime(2026, 4, 17),
        endDate: DateTime(2026, 4, 24),
        assignedEmployeeIds: ['e1'],
        status: PhaseStatus.notStarted,
      ),
    ],
  ),
  Project(
    id: 'p2',
    name: 'Roof repair - Industrial Hall',
    clientId: 'c2',
    status: ProjectStatus.planned,
    workers: ['Ioana R.'],
    assignedEmployeeIds: ['e3'],
    useClientAddress: true,
    addressLine1: 'Bd. Independentei 7',
    city: 'Cluj-Napoca',
    state: 'Cluj',
    zipCode: '400015',
    latitude: 46.7609,
    longitude: 23.5902,
    phases: [
      ProjectPhase(
        id: 'p2_phase_1',
        name: 'Inspection',
        startDate: DateTime(2026, 4, 14),
        endDate: DateTime(2026, 4, 15),
        assignedEmployeeIds: ['e3'],
        status: PhaseStatus.notStarted,
      ),
    ],
  ),
  Project(
    id: 'p3',
    name: 'Kitchen fit-out - Cafe Luna',
    clientId: 'c3',
    status: ProjectStatus.done,
    workers: ['Mihai S.'],
    assignedEmployeeIds: ['e2'],
    useClientAddress: true,
    addressLine1: 'Piata Unirii 3',
    city: 'Timisoara',
    state: 'Timis',
    zipCode: '300085',
    latitude: 46.7692,
    longitude: 23.6034,
    phases: [
      ProjectPhase(
        id: 'p3_phase_1',
        name: 'Install',
        startDate: DateTime(2026, 4, 10),
        endDate: DateTime(2026, 4, 12),
        assignedEmployeeIds: ['e2'],
        status: PhaseStatus.done,
        submittedByEmployeeIds: ['e2'],
        reviewedByForemanId: 'foreman_local',
      ),
    ],
  ),
];
