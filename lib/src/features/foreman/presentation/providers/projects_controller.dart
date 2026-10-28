import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_session_controller.dart';
import '../../../../core/util/day_key.dart';
import '../../application/foreman_workflow_progress_controller.dart';
import '../../data/projects_repository.dart';
import '../../domain/entities/foreman_workflow_step.dart';
import '../../domain/entities/project.dart';
export '../../domain/entities/project.dart';

final projectsProvider = AsyncNotifierProvider<ProjectsNotifier, List<Project>>(
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

/// The company's projects with their phases. Every change waits for the
/// server and then replaces the project with the one it returned, so status
/// and worker list are always the server's; a refused change throws and
/// leaves the list as it was.
///
/// Daily worker sequences are still kept on this device only.
class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  final Map<String, DailyWorkerSequence> _dailySequences = {};

  ProjectsRepository get _repository => ref.read(projectsRepositoryProvider);

  @override
  Future<List<Project>> build() async {
    final repository = ref.watch(projectsRepositoryProvider);
    if (!await watchForemanScope(ref)) return const [];
    return repository.list();
  }

  /// [status] can only close the project ([ProjectStatus.done]); any other
  /// status is derived from the phases.
  Future<Project> addProject({
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
  }) async {
    var created = await _repository.create(
      Project(
        id: '',
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
    );
    if (status == ProjectStatus.done) {
      created = await _repository.markDone(created.id);
    }
    _upsert(created);
    final workflowNotifier = ref.read(foremanWorkflowProgressProvider.notifier);
    unawaited(workflowNotifier.markComplete(ForemanWorkflowStep.createProject));
    if (phases.isNotEmpty) {
      unawaited(
        workflowNotifier.markComplete(ForemanWorkflowStep.configurePhase),
      );
    }
    return created;
  }

  /// Saves the project's own fields; its phases change through the phase
  /// methods. Choosing [ProjectStatus.done] closes the project, and choosing
  /// anything else for a closed project reopens it, so that its status is
  /// derived from the phases again.
  Future<Project> updateProject({
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
  }) async {
    var updated = await _repository.update(
      Project(
        id: id,
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
      ),
    );
    if (status == ProjectStatus.done && updated.status != ProjectStatus.done) {
      updated = await _repository.markDone(id);
    } else if (status != ProjectStatus.done &&
        updated.status == ProjectStatus.done) {
      updated = await _repository.reopen(id);
    }
    _upsert(updated);
    return updated;
  }

  Project? findById(String id) {
    for (final project in state.value ?? const <Project>[]) {
      if (project.id == id) return project;
    }
    return null;
  }

  Future<void> markProjectDone(String id) async {
    _upsert(await _repository.markDone(id));
  }

  Future<void> addPhase({
    required String projectId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> assignedEmployeeIds,
    String description = '',
    List<PhaseWorkInstruction> workInstructions = const [],
  }) async {
    final project = await _repository.addPhase(
      projectId,
      ProjectPhase(
        id: '',
        name: name,
        startDate: startDate,
        endDate: endDate,
        description: description,
        workInstructions: workInstructions,
        assignedEmployeeIds: assignedEmployeeIds,
        status: PhaseStatus.notStarted,
      ),
    );
    _upsert(project);
    unawaited(
      ref
          .read(foremanWorkflowProgressProvider.notifier)
          .markComplete(ForemanWorkflowStep.configurePhase),
    );
  }

  /// Records that a worker submitted [phaseId] for review with their report.
  /// With a backend the report upload has already done this on the server,
  /// so this only fetches the project.
  Future<void> submitPhaseForReview({
    required String projectId,
    required String phaseId,
    required String employeeId,
  }) async {
    _upsert(await _repository.phaseSubmitted(projectId, phaseId, employeeId));
  }

  /// A null [workInstructions] keeps the current ones.
  Future<void> updatePhase({
    required String projectId,
    required String phaseId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> assignedEmployeeIds,
    String description = '',
    List<PhaseWorkInstruction>? workInstructions,
  }) async {
    final current =
        findById(projectId)?.phases.where((p) => p.id == phaseId).firstOrNull ??
        ProjectPhase(
          id: phaseId,
          name: name,
          startDate: startDate,
          endDate: endDate,
          assignedEmployeeIds: assignedEmployeeIds,
          status: PhaseStatus.notStarted,
        );
    final phase = current.copyWith(
      name: name,
      startDate: startDate,
      endDate: endDate,
      description: description,
      workInstructions: workInstructions,
      assignedEmployeeIds: assignedEmployeeIds,
    );
    _upsert(await _repository.updatePhase(projectId, phase));
  }

  Future<void> removePhase({
    required String projectId,
    required String phaseId,
  }) async {
    final project = await _repository.removePhase(projectId, phaseId);
    final prefixesToRemove = <String>[];
    for (final entry in _dailySequences.entries.toList()) {
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
    _upsert(project);
  }

  /// The server records the signed-in foreman as the reviewer.
  Future<void> reviewPhase({
    required String projectId,
    required String phaseId,
    required bool approved,
    String? reviewNotes,
  }) async {
    _upsert(
      await _repository.reviewPhase(
        projectId,
        phaseId,
        approved: approved,
        reviewNotes: reviewNotes,
      ),
    );
  }

  /// Puts [project] into the list in place of the one with its id. If the
  /// list has not loaded yet, reloads it instead; the reload includes
  /// [project].
  void _upsert(Project project) {
    final current = state.value;
    if (current == null) return ref.invalidateSelf();
    final index = current.indexWhere((p) => p.id == project.id);
    state = AsyncData(
      index < 0 ? [...current, project] : ([...current]..[index] = project),
    );
  }

  /// Notifies listeners after a local sequence change; the projects are the
  /// same, but the sequences read through this notifier are not.
  void _sequencesChanged() {
    final current = state.value;
    if (current != null) state = AsyncData([...current]);
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
    _sequencesChanged();
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
    _sequencesChanged();
  }

  String _sequenceKey({
    required String projectId,
    required String workerId,
    required String dayKey,
  }) {
    return '$projectId|$dayKey|$workerId';
  }
}
