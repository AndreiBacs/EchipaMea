import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echipa_mea/src/features/foreman/presentation/providers/projects_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('addProject adds project with address fields', () {
    container
        .read(projectsProvider.notifier)
        .addProject(
          name: 'New Project',
          clientId: 'c1',
          status: ProjectStatus.planned,
          workers: const ['Worker A'],
          addressLine1: 'Street 1',
          city: 'City',
          stateProvince: 'State',
          zipCode: '12345',
        );
    final added = container.read(projectsProvider).last;
    expect(added.addressLine1, 'Street 1');
    expect(added.city, 'City');
    expect(added.state, 'State');
    expect(added.zipCode, '12345');
  });

  test('removePhase drops phase and updates derived status', () {
    final notifier = container.read(projectsProvider.notifier);
    final project = notifier.findById('p2')!;
    final phaseId = project.phases.first.id;

    notifier.removePhase(projectId: project.id, phaseId: phaseId);

    final updated = notifier.findById(project.id)!;
    expect(updated.phases, isEmpty);
    expect(updated.status, ProjectStatus.planned);
  });

  test('submit and approve phase updates derived project status', () {
    final notifier = container.read(projectsProvider.notifier);
    final project = notifier.findById('p1')!;
    final firstPhase = project.phases.first;

    notifier.submitPhaseForReview(
      projectId: project.id,
      phaseId: firstPhase.id,
      employeeId: 'e1',
    );

    var updated = notifier.findById(project.id)!;
    expect(updated.phases.first.status, PhaseStatus.pendingReview);
    expect(updated.status, ProjectStatus.inProgress);

    for (final phase in updated.phases) {
      notifier.reviewPhase(
        projectId: updated.id,
        phaseId: phase.id,
        approved: true,
        foremanId: 'foreman_local',
      );
    }

    updated = notifier.findById(project.id)!;
    expect(updated.status, ProjectStatus.done);
  });
}
