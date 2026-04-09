import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/app_user_role.dart';

final selectedRoleProvider =
    NotifierProvider<SelectedRoleNotifier, AppUserRole>(
      SelectedRoleNotifier.new,
    );

class SelectedRoleNotifier extends Notifier<AppUserRole> {
  @override
  AppUserRole build() => AppUserRole.foreman;

  void setRole(AppUserRole role) {
    state = role;
  }
}

final homeControllerProvider = Provider<HomeViewModel>((ref) {
  final selectedRole = ref.watch(selectedRoleProvider);
  return HomeViewModel(selectedRole: selectedRole);
});

class HomeViewModel {
  HomeViewModel({required this.selectedRole});

  final AppUserRole selectedRole;

  String get roleDescription {
    return switch (selectedRole) {
      AppUserRole.foreman =>
        'Foreman manages crews, assigns jobs, and tracks progress.',
      AppUserRole.worker =>
        'Worker views assigned jobs, updates status, and logs completed work.',
    };
  }
}
