import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/project.dart';
export '../../domain/entities/project.dart';

final projectsProvider = NotifierProvider<ProjectsNotifier, List<Project>>(
  ProjectsNotifier.new,
);

class ProjectsNotifier extends Notifier<List<Project>> {
  @override
  List<Project> build() {
    return const [
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
            assignedEmployeeIds: ['e2'],
            status: PhaseStatus.done,
            submittedByEmployeeIds: ['e2'],
            reviewedByForemanId: 'foreman_local',
          ),
        ],
      ),
    ];
  }

  void addProject({
    required String name,
    required String clientId,
    required ProjectStatus status,
    required List<String> workers,
    List<String> assignedEmployeeIds = const [],
    bool useClientAddress = true,
    required String addressLine1,
    required String city,
    required String stateProvince,
    required String zipCode,
    double? latitude,
    double? longitude,
    List<ProjectPhase> phases = const [],
  }) {
    final nextId =
        'p${state.length + 1}_${DateTime.now().millisecondsSinceEpoch}';
    state = [
      ...state,
      Project(
        id: nextId,
        name: name,
        clientId: clientId,
        status: status,
        workers: workers,
        assignedEmployeeIds: assignedEmployeeIds,
        useClientAddress: useClientAddress,
        addressLine1: addressLine1,
        city: city,
        state: stateProvince,
        zipCode: zipCode,
        latitude: latitude,
        longitude: longitude,
        phases: phases,
      ),
    ];
  }

  void updateProject({
    required String id,
    required String name,
    required String clientId,
    required ProjectStatus status,
    required List<String> workers,
    List<String> assignedEmployeeIds = const [],
    bool useClientAddress = true,
    required String addressLine1,
    required String city,
    required String stateProvince,
    required String zipCode,
    double? latitude,
    double? longitude,
    List<ProjectPhase> phases = const [],
  }) {
    state = [
      for (final project in state)
        if (project.id == id)
          project.copyWith(
            name: name,
            clientId: clientId,
            status: status,
            workers: workers,
            assignedEmployeeIds: assignedEmployeeIds,
            useClientAddress: useClientAddress,
            addressLine1: addressLine1,
            city: city,
            state: stateProvince,
            zipCode: zipCode,
            latitude: latitude,
            longitude: longitude,
            phases: phases,
          )
        else
          project,
    ];
  }

  Project? findById(String id) {
    for (final project in state) {
      if (project.id == id) return project;
    }
    return null;
  }

  void markProjectDone(String id) {
    state = [
      for (final project in state)
        if (project.id == id)
          project.copyWith(status: ProjectStatus.done)
        else
          project,
    ];
  }

  void addPhase({
    required String projectId,
    required String name,
    required List<String> assignedEmployeeIds,
    String description = '',
    List<PhaseWorkInstruction> workInstructions = const [],
  }) {
    final phaseId = '${projectId}_phase_${DateTime.now().millisecondsSinceEpoch}';
    final newPhase = ProjectPhase(
      id: phaseId,
      name: name,
      description: description,
      workInstructions: workInstructions,
      assignedEmployeeIds: assignedEmployeeIds,
      status: PhaseStatus.notStarted,
    );
    state = [
      for (final project in state)
        if (project.id == projectId)
          project.copyWith(
            phases: [
              ...project.phases,
              newPhase,
            ],
            status: projectStatusFromPhases([
              ...project.phases,
              newPhase,
            ]),
          )
        else
          project,
    ];
  }

  void submitPhaseForReview({
    required String projectId,
    required String phaseId,
    required String employeeId,
  }) {
    final normalizedEmployeeId = employeeId.trim();

    state = [
      for (final project in state)
        if (project.id == projectId)
          () {
            var didUpdatePhase = false;

            final updatedPhases = [
              for (final phase in project.phases)
                if (phase.id == phaseId)
                  () {
                    didUpdatePhase = true;
                    return phase.copyWith(
                      status: PhaseStatus.pendingReview,
                      submittedAt: DateTime.now(),
                      submittedByEmployeeIds: [
                        ...phase.submittedByEmployeeIds,
                        if (normalizedEmployeeId.isNotEmpty &&
                            !phase.submittedByEmployeeIds
                                .contains(normalizedEmployeeId))
                          normalizedEmployeeId,
                      ],
                    );
                  }()
                else
                  phase,
            ];

            if (!didUpdatePhase) {
              return project;
            }

            return project.copyWith(
              phases: updatedPhases,
              status: ProjectStatus.inProgress,
            );
          }()
        else
          project,
    ];
  }

  void updatePhase({
    required String projectId,
    required String phaseId,
    required String name,
    required List<String> assignedEmployeeIds,
    String description = '',
    List<PhaseWorkInstruction>? workInstructions,
  }) {
    state = [
      for (final project in state)
        if (project.id == projectId)
          project.copyWith(
            phases: [
              for (final phase in project.phases)
                if (phase.id == phaseId)
                  phase.copyWith(
                    name: name,
                    description: description,
                    assignedEmployeeIds: assignedEmployeeIds,
                    workInstructions: workInstructions,
                  )
                else
                  phase,
            ],
          )
        else
          project,
    ];
  }

  void removePhase({
    required String projectId,
    required String phaseId,
  }) {
    state = [
      for (final project in state)
        if (project.id == projectId)
          () {
            final nextPhases = [
              for (final phase in project.phases)
                if (phase.id != phaseId) phase,
            ];
            return project.copyWith(
              phases: nextPhases,
              status: projectStatusFromPhases(nextPhases),
            );
          }()
        else
          project,
    ];
  }

  void reviewPhase({
    required String projectId,
    required String phaseId,
    required bool approved,
    required String foremanId,
    String? reviewNotes,
  }) {
    state = [
      for (final project in state)
        if (project.id == projectId)
          () {
            final nextPhases = [
              for (final phase in project.phases)
                if (phase.id == phaseId)
                  phase.copyWith(
                    status: approved ? PhaseStatus.done : PhaseStatus.inProgress,
                    reviewedAt: DateTime.now(),
                    reviewedByForemanId: foremanId,
                    reviewNotes: reviewNotes,
                  )
                else
                  phase,
            ];
            return project.copyWith(
              phases: nextPhases,
              status: projectStatusFromPhases(nextPhases),
            );
          }()
        else
          project,
    ];
  }
}

