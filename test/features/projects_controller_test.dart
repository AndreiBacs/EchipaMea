import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echipa_mea/src/core/network/api_exception.dart';
import 'package:echipa_mea/src/features/foreman/presentation/providers/projects_controller.dart';

void main() {
  late ProviderContainer container;
  late ProjectsNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(projectsProvider.future);
    notifier = container.read(projectsProvider.notifier);
  });

  Future<Project> saveP2({required ProjectStatus status}) {
    final p2 = notifier.findById('p2')!;
    return notifier.updateProject(
      id: p2.id,
      name: p2.name,
      clientId: p2.clientId,
      status: status,
      workers: p2.workers,
      assignedEmployeeIds: p2.assignedEmployeeIds,
      addressLine1: p2.addressLine1,
      city: p2.city,
      stateProvince: p2.state,
      zipCode: p2.zipCode,
    );
  }

  test('addProject adds project with address fields', () async {
    await notifier.addProject(
      name: 'New Project',
      clientId: 'c1',
      status: ProjectStatus.planned,
      workers: const ['Worker A'],
      addressLine1: 'Street 1',
      city: 'City',
      stateProvince: 'State',
      zipCode: '12345',
    );
    final added = container.read(projectsProvider).requireValue.last;
    expect(added.id, isNotEmpty);
    expect(added.addressLine1, 'Street 1');
    expect(added.city, 'City');
    expect(added.state, 'State');
    expect(added.zipCode, '12345');
  });

  test('a new project takes its status from its phases', () async {
    final created = await notifier.addProject(
      name: 'Asked to be in progress',
      clientId: 'c1',
      status: ProjectStatus.inProgress,
      workers: const [],
      addressLine1: 'a',
      city: 'b',
      stateProvince: 'c',
      zipCode: 'd',
    );
    expect(created.status, ProjectStatus.planned);
  });

  test('removePhase drops phase and updates derived status', () async {
    final project = notifier.findById('p2')!;
    final phaseId = project.phases.first.id;

    await notifier.removePhase(projectId: project.id, phaseId: phaseId);

    final updated = notifier.findById(project.id)!;
    expect(updated.phases, isEmpty);
    expect(updated.status, ProjectStatus.planned);
  });

  test('submit and approve phase updates derived project status', () async {
    final project = notifier.findById('p1')!;
    final firstPhase = project.phases.first;

    await notifier.submitPhaseForReview(
      projectId: project.id,
      phaseId: firstPhase.id,
      employeeId: 'e1',
    );

    var updated = notifier.findById(project.id)!;
    expect(updated.phases.first.status, PhaseStatus.pendingReview);
    expect(updated.phases.first.submittedByEmployeeIds, ['e1']);
    expect(updated.status, ProjectStatus.inProgress);

    for (final phase in updated.phases) {
      await notifier.reviewPhase(
        projectId: updated.id,
        phaseId: phase.id,
        approved: true,
      );
    }

    updated = notifier.findById(project.id)!;
    expect(updated.status, ProjectStatus.done);
  });

  test(
    'choosing done closes a project, and any other status reopens it',
    () async {
      expect(
        (await saveP2(status: ProjectStatus.done)).status,
        ProjectStatus.done,
      );
      expect(notifier.findById('p2')!.status, ProjectStatus.done);

      final reopened = await saveP2(status: ProjectStatus.inProgress);
      // Back to what the phases say, not to what was chosen.
      expect(reopened.status, ProjectStatus.planned);
    },
  );

  test('updateProject leaves the phases alone', () async {
    final before = notifier.findById('p2')!.phases;
    await saveP2(status: ProjectStatus.planned);
    expect(notifier.findById('p2')!.phases, before);
  });

  test('updatePhase keeps the review state and normalizes dates', () async {
    final phase = notifier.findById('p3')!.phases.single;

    await notifier.updatePhase(
      projectId: 'p3',
      phaseId: phase.id,
      name: 'Install, renamed',
      startDate: DateTime(2026, 4, 10, 15, 30),
      endDate: DateTime(2026, 4, 12, 9),
      assignedEmployeeIds: phase.assignedEmployeeIds,
    );

    final updated = notifier.findById('p3')!.phases.single;
    expect(updated.name, 'Install, renamed');
    expect(updated.status, PhaseStatus.done);
    expect(updated.startDate, DateTime(2026, 4, 10));
    expect(updated.endDate, DateTime(2026, 4, 12));
  });

  test('unknown ids are NOT_FOUND, like the server', () async {
    await expectLater(
      notifier.removePhase(projectId: 'p1', phaseId: 'nope'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'NOT_FOUND')),
    );
    await expectLater(
      notifier.markProjectDone('nope'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
    );
  });

  test('a done phase cannot be submitted again', () async {
    final phase = notifier.findById('p3')!.phases.single;
    await expectLater(
      notifier.submitPhaseForReview(
        projectId: 'p3',
        phaseId: phase.id,
        employeeId: 'e2',
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'PHASE_INVALID_TRANSITION',
        ),
      ),
    );
    expect(notifier.findById('p3')!.phases.single.status, PhaseStatus.done);
  });
}
