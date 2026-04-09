import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echipa_mea/src/core/domain/entities/app_user_role.dart';
import 'package:echipa_mea/src/features/home/presentation/providers/home_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  group('SelectedRoleNotifier initial state', () {
    test('defaults to foreman', () {
      expect(container.read(selectedRoleProvider), AppUserRole.foreman);
    });
  });

  group('SelectedRoleNotifier.setRole', () {
    test('sets role to worker', () {
      container.read(selectedRoleProvider.notifier).setRole(AppUserRole.worker);
      expect(container.read(selectedRoleProvider), AppUserRole.worker);
    });

    test('sets role to foreman after worker', () {
      container.read(selectedRoleProvider.notifier).setRole(AppUserRole.worker);
      container
          .read(selectedRoleProvider.notifier)
          .setRole(AppUserRole.foreman);
      expect(container.read(selectedRoleProvider), AppUserRole.foreman);
    });

    test('setting same role twice keeps state unchanged', () {
      container
          .read(selectedRoleProvider.notifier)
          .setRole(AppUserRole.foreman);
      container
          .read(selectedRoleProvider.notifier)
          .setRole(AppUserRole.foreman);
      expect(container.read(selectedRoleProvider), AppUserRole.foreman);
    });
  });

  group('HomeViewModel.roleDescription', () {
    test('returns foreman description when role is foreman', () {
      final vm = HomeViewModel(selectedRole: AppUserRole.foreman);
      expect(
        vm.roleDescription,
        'Foreman manages crews, assigns jobs, and tracks progress.',
      );
    });

    test('returns worker description when role is worker', () {
      final vm = HomeViewModel(selectedRole: AppUserRole.worker);
      expect(
        vm.roleDescription,
        'Worker views assigned jobs, updates status, and logs completed work.',
      );
    });

    test('description is non-empty for all roles', () {
      for (final role in AppUserRole.values) {
        final vm = HomeViewModel(selectedRole: role);
        expect(vm.roleDescription, isNotEmpty);
      }
    });
  });

  group('homeControllerProvider', () {
    test('returns HomeViewModel with default foreman role', () {
      final vm = container.read(homeControllerProvider);
      expect(vm.selectedRole, AppUserRole.foreman);
    });

    test('updates when selectedRoleProvider changes', () {
      container.read(selectedRoleProvider.notifier).setRole(AppUserRole.worker);
      final vm = container.read(homeControllerProvider);
      expect(vm.selectedRole, AppUserRole.worker);
    });
  });
}
