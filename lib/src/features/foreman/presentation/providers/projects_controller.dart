import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/foreman_workflow_progress_controller.dart';
import '../../domain/entities/foreman_workflow_step.dart';
import '../../domain/entities/project.dart';
export '../../domain/entities/project.dart';

final projectsProvider = NotifierProvider<ProjectsNotifier, List<Project>>(
  ProjectsNotifier.new,
);

class DailyWorkerSequence {
  const DailyWorkerSequence({
    required this.projectId,
    required this.dayKey,
    required this.workerId,
    required this.orderedPhaseIds,
    this.isManual = false,
  });

  final String projectId;
  final String dayKey;
  final String workerId;
  final List<String> orderedPhaseIds;
  final bool isManual;

  DailyWorkerSequence copyWith({
    List<String>? orderedPhaseIds,
    bool? isManual,
  }) {
    return DailyWorkerSequence(
      projectId: projectId,
      dayKey: dayKey,
      workerId: workerId,
      orderedPhaseIds: orderedPhaseIds ?? this.orderedPhaseIds,
      isManual: isManual ?? this.isManual,
    );
  }
}

class ProjectsNotifier extends Notifier<List<Project>> {
  final Map<String, DailyWorkerSequence> _dailySequences = {};

  static String dayKey(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$dd';
  }

  static DateTime dayFromKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return DateTime.now();
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;
    final day = int.tryParse(parts[2]) ?? DateTime.now().day;
    return DateTime(year, month, day);
  }

  @override
  List<Project> build() {
    return [
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
    final workflowNotifier = ref.read(foremanWorkflowProgressProvider.notifier);
    unawaited(workflowNotifier.markComplete(ForemanWorkflowStep.createProject));
    if (phases.isNotEmpty) {
      unawaited(
        workflowNotifier.markComplete(ForemanWorkflowStep.configurePhase),
      );
    }
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
    required DateTime startDate,
    required DateTime endDate,
    required List<String> assignedEmployeeIds,
    String description = '',
    List<PhaseWorkInstruction> workInstructions = const [],
  }) {
    final phaseId =
        '${projectId}_phase_${DateTime.now().millisecondsSinceEpoch}';
    final newPhase = ProjectPhase(
      id: phaseId,
      name: name,
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      endDate: DateTime(endDate.year, endDate.month, endDate.day),
      description: description,
      workInstructions: workInstructions,
      assignedEmployeeIds: assignedEmployeeIds,
      status: PhaseStatus.notStarted,
    );
    state = [
      for (final project in state)
        if (project.id == projectId)
          project.copyWith(
            phases: [...project.phases, newPhase],
            status: projectStatusFromPhases([...project.phases, newPhase]),
          )
        else
          project,
    ];
    unawaited(
      ref
          .read(foremanWorkflowProgressProvider.notifier)
          .markComplete(ForemanWorkflowStep.configurePhase),
    );
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
                            !phase.submittedByEmployeeIds.contains(
                              normalizedEmployeeId,
                            ))
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
    required DateTime startDate,
    required DateTime endDate,
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
                    startDate: DateTime(
                      startDate.year,
                      startDate.month,
                      startDate.day,
                    ),
                    endDate: DateTime(endDate.year, endDate.month, endDate.day),
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

  void removePhase({required String projectId, required String phaseId}) {
    final prefixesToRemove = <String>[];
    for (final entry in _dailySequences.entries) {
      if (entry.value.projectId != projectId) continue;
      if (entry.value.orderedPhaseIds.contains(phaseId)) {
        final filteredIds = [
          for (final id in entry.value.orderedPhaseIds)
            if (id != phaseId) id,
        ];
        if (filteredIds.isEmpty) {
          prefixesToRemove.add(entry.key);
        } else {
          _dailySequences[entry.key] = entry.value.copyWith(
            orderedPhaseIds: filteredIds,
          );
        }
      }
    }
    for (final key in prefixesToRemove) {
      _dailySequences.remove(key);
    }
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
                    status: approved
                        ? PhaseStatus.done
                        : PhaseStatus.inProgress,
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

  DailyWorkerSequence sequenceForDay({
    required String projectId,
    required String workerId,
    required DateTime day,
  }) {
    final key = _sequenceKey(
      projectId: projectId,
      workerId: workerId,
      dayKey: dayKey(day),
    );
    final existing = _dailySequences[key];
    if (existing != null) return existing;
    return suggestedSequenceForDay(
      projectId: projectId,
      workerId: workerId,
      day: day,
    );
  }

  DailyWorkerSequence suggestedSequenceForDay({
    required String projectId,
    required String workerId,
    required DateTime day,
  }) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final project = findById(projectId);
    if (project == null) {
      return DailyWorkerSequence(
        projectId: projectId,
        dayKey: dayKey(normalizedDay),
        workerId: workerId,
        orderedPhaseIds: const [],
      );
    }
    final ordered =
        [
          for (final phase in project.phases)
            if (phase.assignedEmployeeIds.contains(workerId) &&
                !normalizedDay.isBefore(
                  DateTime(
                    phase.startDate.year,
                    phase.startDate.month,
                    phase.startDate.day,
                  ),
                ) &&
                !normalizedDay.isAfter(
                  DateTime(
                    phase.endDate.year,
                    phase.endDate.month,
                    phase.endDate.day,
                  ),
                ))
              phase,
        ]..sort((a, b) {
          final byStart = a.startDate.compareTo(b.startDate);
          if (byStart != 0) return byStart;
          return a.name.compareTo(b.name);
        });

    return DailyWorkerSequence(
      projectId: projectId,
      dayKey: dayKey(normalizedDay),
      workerId: workerId,
      orderedPhaseIds: ordered.map((p) => p.id).toList(),
    );
  }

  void saveDailySequence({
    required String projectId,
    required String workerId,
    required DateTime day,
    required List<String> orderedPhaseIds,
  }) {
    final key = _sequenceKey(
      projectId: projectId,
      workerId: workerId,
      dayKey: dayKey(day),
    );
    _dailySequences[key] = DailyWorkerSequence(
      projectId: projectId,
      dayKey: dayKey(day),
      workerId: workerId,
      orderedPhaseIds: orderedPhaseIds,
      isManual: true,
    );
    state = [...state];
  }

  void resetDailySequence({
    required String projectId,
    required String workerId,
    required DateTime day,
  }) {
    final key = _sequenceKey(
      projectId: projectId,
      workerId: workerId,
      dayKey: dayKey(day),
    );
    _dailySequences.remove(key);
    state = [...state];
  }

  String _sequenceKey({
    required String projectId,
    required String workerId,
    required String dayKey,
  }) {
    return '$projectId|$dayKey|$workerId';
  }
}
