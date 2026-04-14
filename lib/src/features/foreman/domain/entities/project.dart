import 'project_enums.dart';
export 'project_enums.dart';

/// One checklist line for a phase, with its own reference photos and voice memos.
class PhaseWorkInstruction {
  const PhaseWorkInstruction({
    required this.id,
    required this.text,
    this.photoPaths = const [],
    this.audioPaths = const [],
  });

  final String id;
  final String text;
  final List<String> photoPaths;
  final List<String> audioPaths;

  PhaseWorkInstruction copyWith({
    String? id,
    String? text,
    List<String>? photoPaths,
    List<String>? audioPaths,
  }) {
    return PhaseWorkInstruction(
      id: id ?? this.id,
      text: text ?? this.text,
      photoPaths: photoPaths ?? this.photoPaths,
      audioPaths: audioPaths ?? this.audioPaths,
    );
  }
}

class ProjectPhase {
  const ProjectPhase({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.description = '',
    required this.assignedEmployeeIds,
    required this.status,
    this.submittedAt,
    this.submittedByEmployeeIds = const [],
    this.reviewedAt,
    this.reviewedByForemanId,
    this.reviewNotes,
    this.workInstructions = const [],
  });

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  /// Foreman notes / scope for this phase (optional).
  final String description;

  /// Ordered work instructions; each may include photos and voice memos.
  final List<PhaseWorkInstruction> workInstructions;
  final List<String> assignedEmployeeIds;
  final PhaseStatus status;
  final DateTime? submittedAt;
  final List<String> submittedByEmployeeIds;
  final DateTime? reviewedAt;
  final String? reviewedByForemanId;
  final String? reviewNotes;

  ProjectPhase copyWith({
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    String? description,
    List<PhaseWorkInstruction>? workInstructions,
    List<String>? assignedEmployeeIds,
    PhaseStatus? status,
    DateTime? submittedAt,
    List<String>? submittedByEmployeeIds,
    DateTime? reviewedAt,
    String? reviewedByForemanId,
    String? reviewNotes,
  }) {
    return ProjectPhase(
      id: id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      description: description ?? this.description,
      workInstructions: workInstructions ?? this.workInstructions,
      assignedEmployeeIds: assignedEmployeeIds ?? this.assignedEmployeeIds,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      submittedByEmployeeIds:
          submittedByEmployeeIds ?? this.submittedByEmployeeIds,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedByForemanId: reviewedByForemanId ?? this.reviewedByForemanId,
      reviewNotes: reviewNotes ?? this.reviewNotes,
    );
  }
}

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.clientId,
    required this.status,
    required this.workers,
    this.assignedEmployeeIds = const [],
    this.useClientAddress = true,
    required this.addressLine1,
    required this.city,
    required this.state,
    required this.zipCode,
    this.latitude,
    this.longitude,
    this.phases = const [],
  });

  final String id;
  final String name;
  final String clientId;
  final ProjectStatus status;
  final List<String> workers;

  /// When non-empty, prefer matching the signed-in worker by [Employee.id].
  final List<String> assignedEmployeeIds;
  final bool useClientAddress;
  final String addressLine1;
  final String city;
  final String state;
  final String zipCode;
  final double? latitude;
  final double? longitude;
  final List<ProjectPhase> phases;

  String get fullAddress => '$addressLine1, $city, $state, $zipCode';

  String get workersLabel {
    if (workers.isEmpty) return 'No workers assigned';
    return workers.join(', ');
  }

  Project copyWith({
    String? name,
    String? clientId,
    ProjectStatus? status,
    List<String>? workers,
    List<String>? assignedEmployeeIds,
    bool? useClientAddress,
    String? addressLine1,
    String? city,
    String? state,
    String? zipCode,
    double? latitude,
    double? longitude,
    List<ProjectPhase>? phases,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      clientId: clientId ?? this.clientId,
      status: status ?? this.status,
      workers: workers ?? this.workers,
      assignedEmployeeIds: assignedEmployeeIds ?? this.assignedEmployeeIds,
      useClientAddress: useClientAddress ?? this.useClientAddress,
      addressLine1: addressLine1 ?? this.addressLine1,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phases: phases ?? this.phases,
    );
  }
}

ProjectStatus projectStatusFromPhases(List<ProjectPhase> phases) {
  if (phases.isEmpty) return ProjectStatus.planned;
  final allDone = phases.every((p) => p.status == PhaseStatus.done);
  if (allDone) return ProjectStatus.done;
  final hasStarted = phases.any((p) => p.status != PhaseStatus.notStarted);
  return hasStarted ? ProjectStatus.inProgress : ProjectStatus.planned;
}
