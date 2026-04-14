import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echipa_mea/src/features/foreman/application/foreman_workflow_progress_controller.dart';
import 'package:echipa_mea/src/features/foreman/domain/entities/foreman_workflow_step.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  group('ForemanWorkflowProgressNotifier.build', () {
    test('loads empty state when no preferences exist', () async {
      final container = makeContainer();
      final state = await container.read(
        foremanWorkflowProgressProvider.future,
      );

      expect(state.completedSteps, isEmpty);
      expect(state.cardDismissed, isFalse);
      expect(state.allStepsCompleted, isFalse);
    });

    test('loads persisted completed steps and card dismissal', () async {
      SharedPreferences.setMockInitialValues({
        'foreman_workflow_completed_steps': ['add_client', 'create_project'],
        'foreman_workflow_card_dismissed': true,
      });
      final container = makeContainer();
      final state = await container.read(
        foremanWorkflowProgressProvider.future,
      );

      expect(
        state.completedSteps,
        containsAll([
          ForemanWorkflowStep.addClient,
          ForemanWorkflowStep.createProject,
        ]),
      );
      expect(state.cardDismissed, isTrue);
    });
  });

  group('ForemanWorkflowProgressNotifier mutations', () {
    test('markComplete stores step and stays idempotent', () async {
      final container = makeContainer();
      await container.read(foremanWorkflowProgressProvider.future);

      await container
          .read(foremanWorkflowProgressProvider.notifier)
          .markComplete(ForemanWorkflowStep.addClient);
      await container
          .read(foremanWorkflowProgressProvider.notifier)
          .markComplete(ForemanWorkflowStep.addClient);

      final state = container.read(foremanWorkflowProgressProvider).value;
      expect(state, isNotNull);
      expect(state?.completedSteps, {ForemanWorkflowStep.addClient});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('foreman_workflow_completed_steps'), [
        'add_client',
      ]);
    });

    test('dismissCard and restoreCard persist value', () async {
      final container = makeContainer();
      await container.read(foremanWorkflowProgressProvider.future);

      await container
          .read(foremanWorkflowProgressProvider.notifier)
          .dismissCard();
      expect(
        container.read(foremanWorkflowProgressProvider).value?.cardDismissed,
        isTrue,
      );

      await container
          .read(foremanWorkflowProgressProvider.notifier)
          .restoreCard();
      expect(
        container.read(foremanWorkflowProgressProvider).value?.cardDismissed,
        isFalse,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('foreman_workflow_card_dismissed'), isFalse);
    });
  });
}
