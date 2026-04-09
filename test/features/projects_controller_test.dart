import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echipa_mea/src/features/foreman/presentation/providers/projects_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  group('ProjectsNotifier initial state', () {
    test('starts with 3 demo projects', () {
      expect(container.read(projectsProvider).length, 3);
    });

    test('first demo project has id p1', () {
      expect(container.read(projectsProvider).first.id, 'p1');
    });

    test('demo projects have required fields populated', () {
      for (final project in container.read(projectsProvider)) {
        expect(project.id, isNotEmpty);
        expect(project.name, isNotEmpty);
        expect(project.workers, isNotEmpty);
      }
    });
  });

  group('ProjectsNotifier.addProject', () {
    test('increases project count by one', () {
      container.read(projectsProvider.notifier).addProject(
            name: 'New Project',
            status: ProjectStatus.planned,
            workers: ['Worker A'],
          );
      expect(container.read(projectsProvider).length, 4);
    });

    test('added project is appended to the end', () {
      container.read(projectsProvider.notifier).addProject(
            name: 'Last Project',
            status: ProjectStatus.done,
            workers: ['Worker B'],
          );
      expect(container.read(projectsProvider).last.name, 'Last Project');
    });

    test('added project has all fields set correctly', () {
      container.read(projectsProvider.notifier).addProject(
            name: 'Full Fields',
            status: ProjectStatus.inProgress,
            workers: ['Alice', 'Bob'],
            latitude: 46.77,
            longitude: 23.62,
          );
      final added = container.read(projectsProvider).last;
      expect(added.name, 'Full Fields');
      expect(added.status, ProjectStatus.inProgress);
      expect(added.workers, ['Alice', 'Bob']);
      expect(added.latitude, 46.77);
      expect(added.longitude, 23.62);
    });

    test('added project without coordinates has null lat/long', () {
      container.read(projectsProvider.notifier).addProject(
            name: 'No Coords',
            status: ProjectStatus.planned,
            workers: [],
          );
      final added = container.read(projectsProvider).last;
      expect(added.latitude, isNull);
      expect(added.longitude, isNull);
    });

    test('generated ids are unique for successive adds', () {
      container.read(projectsProvider.notifier).addProject(
            name: 'A',
            status: ProjectStatus.planned,
            workers: [],
          );
      container.read(projectsProvider.notifier).addProject(
            name: 'B',
            status: ProjectStatus.planned,
            workers: [],
          );
      final projects = container.read(projectsProvider);
      final ids = projects.map((p) => p.id).toSet();
      expect(ids.length, projects.length);
    });
  });

  group('ProjectsNotifier.updateProject', () {
    test('updates name for existing project', () {
      container.read(projectsProvider.notifier).updateProject(
            id: 'p1',
            name: 'Updated Name',
            status: ProjectStatus.inProgress,
            workers: ['Andrei D.', 'Vlad P.'],
          );
      final updated = container
          .read(projectsProvider)
          .firstWhere((p) => p.id == 'p1');
      expect(updated.name, 'Updated Name');
    });

    test('updates status for existing project', () {
      container.read(projectsProvider.notifier).updateProject(
            id: 'p2',
            name: 'Roof repair - Industrial Hall',
            status: ProjectStatus.done,
            workers: ['Ioana R.'],
          );
      final updated = container
          .read(projectsProvider)
          .firstWhere((p) => p.id == 'p2');
      expect(updated.status, ProjectStatus.done);
    });

    test('updates workers list for existing project', () {
      container.read(projectsProvider.notifier).updateProject(
            id: 'p3',
            name: 'Kitchen fit-out - Cafe Luna',
            status: ProjectStatus.done,
            workers: ['Worker X', 'Worker Y'],
          );
      final updated = container
          .read(projectsProvider)
          .firstWhere((p) => p.id == 'p3');
      expect(updated.workers, ['Worker X', 'Worker Y']);
    });

    test('does not change total count on update', () {
      final before = container.read(projectsProvider).length;
      container.read(projectsProvider.notifier).updateProject(
            id: 'p1',
            name: 'X',
            status: ProjectStatus.planned,
            workers: [],
          );
      expect(container.read(projectsProvider).length, before);
    });

    test('does not affect other projects when updating one', () {
      container.read(projectsProvider.notifier).updateProject(
            id: 'p1',
            name: 'Changed',
            status: ProjectStatus.planned,
            workers: [],
          );
      final p2 = container
          .read(projectsProvider)
          .firstWhere((p) => p.id == 'p2');
      expect(p2.name, 'Roof repair - Industrial Hall');
    });

    test('unknown id does not change state', () {
      final before =
          container.read(projectsProvider).map((p) => p.name).toList();
      container.read(projectsProvider.notifier).updateProject(
            id: 'nonexistent',
            name: 'Ghost',
            status: ProjectStatus.planned,
            workers: [],
          );
      final after =
          container.read(projectsProvider).map((p) => p.name).toList();
      expect(after, before);
    });
  });

  group('ProjectsNotifier.findById', () {
    test('returns correct project for valid id', () {
      final project =
          container.read(projectsProvider.notifier).findById('p1');
      expect(project, isNotNull);
      expect(project!.id, 'p1');
    });

    test('returns null for unknown id', () {
      final project =
          container.read(projectsProvider.notifier).findById('unknown');
      expect(project, isNull);
    });

    test('returns null for empty id', () {
      final project = container.read(projectsProvider.notifier).findById('');
      expect(project, isNull);
    });
  });

  group('ProjectStatus enum', () {
    test('planned has label "Planned"', () {
      expect(ProjectStatus.planned.label, 'Planned');
    });

    test('inProgress has label "In Progress"', () {
      expect(ProjectStatus.inProgress.label, 'In Progress');
    });

    test('done has label "Done"', () {
      expect(ProjectStatus.done.label, 'Done');
    });

    test('has exactly 3 values', () {
      expect(ProjectStatus.values.length, 3);
    });
  });

  group('Project.workersLabel', () {
    test('returns "No workers assigned" for empty list', () {
      const project = Project(
        id: 'x',
        name: 'X',
        status: ProjectStatus.planned,
        workers: [],
      );
      expect(project.workersLabel, 'No workers assigned');
    });

    test('returns single worker name', () {
      const project = Project(
        id: 'x',
        name: 'X',
        status: ProjectStatus.planned,
        workers: ['Alice'],
      );
      expect(project.workersLabel, 'Alice');
    });

    test('returns comma-separated worker names', () {
      const project = Project(
        id: 'x',
        name: 'X',
        status: ProjectStatus.planned,
        workers: ['Alice', 'Bob', 'Carol'],
      );
      expect(project.workersLabel, 'Alice, Bob, Carol');
    });
  });

  group('Project.copyWith', () {
    const original = Project(
      id: 'orig',
      name: 'Original',
      status: ProjectStatus.planned,
      workers: ['W1'],
      latitude: 46.77,
      longitude: 23.62,
    );

    test('copies all fields when no overrides given', () {
      final copy = original.copyWith();
      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.status, original.status);
      expect(copy.workers, original.workers);
      expect(copy.latitude, original.latitude);
      expect(copy.longitude, original.longitude);
    });

    test('overrides name only', () {
      final copy = original.copyWith(name: 'New Name');
      expect(copy.name, 'New Name');
      expect(copy.status, original.status);
    });

    test('overrides status only', () {
      final copy = original.copyWith(status: ProjectStatus.done);
      expect(copy.status, ProjectStatus.done);
      expect(copy.name, original.name);
    });

    test('overrides workers only', () {
      final copy = original.copyWith(workers: ['X', 'Y']);
      expect(copy.workers, ['X', 'Y']);
      expect(copy.name, original.name);
    });

    test('preserves id on copy', () {
      final copy = original.copyWith(name: 'Changed');
      expect(copy.id, 'orig');
    });

    test('overrides coordinates', () {
      final copy = original.copyWith(latitude: 1.0, longitude: 2.0);
      expect(copy.latitude, 1.0);
      expect(copy.longitude, 2.0);
    });
  });
}
