import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        status: ProjectStatus.inProgress,
        workers: ['Andrei D.', 'Vlad P.'],
        assignedEmployeeIds: ['e1'],
        latitude: 46.7723,
        longitude: 23.6236,
      ),
      Project(
        id: 'p2',
        name: 'Roof repair - Industrial Hall',
        status: ProjectStatus.planned,
        workers: ['Ioana R.'],
        assignedEmployeeIds: ['e3'],
        latitude: 46.7609,
        longitude: 23.5902,
      ),
      Project(
        id: 'p3',
        name: 'Kitchen fit-out - Cafe Luna',
        status: ProjectStatus.done,
        workers: ['Mihai S.'],
        assignedEmployeeIds: ['e2'],
        latitude: 46.7692,
        longitude: 23.6034,
      ),
    ];
  }

  void addProject({
    required String name,
    required ProjectStatus status,
    required List<String> workers,
    List<String> assignedEmployeeIds = const [],
    double? latitude,
    double? longitude,
  }) {
    final nextId =
        'p${state.length + 1}_${DateTime.now().millisecondsSinceEpoch}';
    state = [
      ...state,
      Project(
        id: nextId,
        name: name,
        status: status,
        workers: workers,
        assignedEmployeeIds: assignedEmployeeIds,
        latitude: latitude,
        longitude: longitude,
      ),
    ];
  }

  void updateProject({
    required String id,
    required String name,
    required ProjectStatus status,
    required List<String> workers,
    List<String> assignedEmployeeIds = const [],
    double? latitude,
    double? longitude,
  }) {
    state = [
      for (final project in state)
        if (project.id == id)
          project.copyWith(
            name: name,
            status: status,
            workers: workers,
            assignedEmployeeIds: assignedEmployeeIds,
            latitude: latitude,
            longitude: longitude,
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
}

enum ProjectStatus {
  planned(label: 'Planned'),
  inProgress(label: 'In Progress'),
  done(label: 'Done');

  const ProjectStatus({required this.label});
  final String label;
}

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.status,
    required this.workers,
    this.assignedEmployeeIds = const [],
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final ProjectStatus status;
  final List<String> workers;
  /// When non-empty, prefer matching the signed-in worker by [Employee.id].
  final List<String> assignedEmployeeIds;
  final double? latitude;
  final double? longitude;

  String get workersLabel {
    if (workers.isEmpty) return 'No workers assigned';
    return workers.join(', ');
  }

  Project copyWith({
    String? name,
    ProjectStatus? status,
    List<String>? workers,
    List<String>? assignedEmployeeIds,
    double? latitude,
    double? longitude,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      workers: workers ?? this.workers,
      assignedEmployeeIds: assignedEmployeeIds ?? this.assignedEmployeeIds,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
