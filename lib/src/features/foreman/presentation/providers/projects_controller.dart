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
      ),
      Project(
        id: 'p2',
        name: 'Roof repair - Industrial Hall',
        status: ProjectStatus.planned,
        workers: ['Ioana R.'],
      ),
      Project(
        id: 'p3',
        name: 'Kitchen fit-out - Cafe Luna',
        status: ProjectStatus.done,
        workers: ['Mihai S.'],
      ),
    ];
  }

  void addProject({
    required String name,
    required ProjectStatus status,
    required List<String> workers,
  }) {
    final nextId =
        'p${state.length + 1}_${DateTime.now().millisecondsSinceEpoch}';
    state = [
      ...state,
      Project(id: nextId, name: name, status: status, workers: workers),
    ];
  }

  void updateProject({
    required String id,
    required String name,
    required ProjectStatus status,
    required List<String> workers,
  }) {
    state = [
      for (final project in state)
        if (project.id == id)
          project.copyWith(name: name, status: status, workers: workers)
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
  });

  final String id;
  final String name;
  final ProjectStatus status;
  final List<String> workers;

  String get workersLabel {
    if (workers.isEmpty) return 'No workers assigned';
    return workers.join(', ');
  }

  Project copyWith({
    String? name,
    ProjectStatus? status,
    List<String>? workers,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      workers: workers ?? this.workers,
    );
  }
}
