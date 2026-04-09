import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echipa_mea/src/core/setup/setup_flow_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  group('SetupFlowNotifier.build', () {
    test('returns false when no preference is stored', () async {
      final container = makeContainer();
      final completed = await container.read(setupFlowCompletedProvider.future);
      expect(completed, isFalse);
    });

    test('returns true when preference is stored as true', () async {
      SharedPreferences.setMockInitialValues({
        'app_initial_setup_completed': true,
      });
      final container = makeContainer();
      final completed = await container.read(setupFlowCompletedProvider.future);
      expect(completed, isTrue);
    });

    test('returns false when preference is stored as false', () async {
      SharedPreferences.setMockInitialValues({
        'app_initial_setup_completed': false,
      });
      final container = makeContainer();
      final completed = await container.read(setupFlowCompletedProvider.future);
      expect(completed, isFalse);
    });
  });

  group('SetupFlowNotifier.complete', () {
    test('sets state to true', () async {
      final container = makeContainer();
      await container.read(setupFlowCompletedProvider.future);

      await container.read(setupFlowCompletedProvider.notifier).complete();

      expect(container.read(setupFlowCompletedProvider).value, isTrue);
    });

    test('persists true to SharedPreferences', () async {
      final container = makeContainer();
      await container.read(setupFlowCompletedProvider.future);

      await container.read(setupFlowCompletedProvider.notifier).complete();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('app_initial_setup_completed'), isTrue);
    });

    test('can be called multiple times without error', () async {
      final container = makeContainer();
      await container.read(setupFlowCompletedProvider.future);

      await container.read(setupFlowCompletedProvider.notifier).complete();
      await container.read(setupFlowCompletedProvider.notifier).complete();

      expect(container.read(setupFlowCompletedProvider).value, isTrue);
    });
  });
}
