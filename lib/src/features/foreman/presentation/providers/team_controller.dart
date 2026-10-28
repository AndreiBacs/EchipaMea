import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_session_controller.dart';
import '../../../../core/domain/entities/worker_role.dart';
import '../../application/foreman_workflow_progress_controller.dart';
import '../../data/employees_repository.dart';
import '../../domain/entities/foreman_workflow_step.dart';
import '../../domain/entities/employee.dart';
export '../../domain/entities/employee.dart';

final teamProvider = AsyncNotifierProvider<TeamNotifier, List<Employee>>(
  TeamNotifier.new,
);

/// The company's crew. Saves wait for the server and then replace the local
/// copy with what it returned; a failed save throws and leaves the list as it
/// was.
class TeamNotifier extends AsyncNotifier<List<Employee>> {
  EmployeesRepository get _repository => ref.read(employeesRepositoryProvider);

  @override
  Future<List<Employee>> build() async {
    final repository = ref.watch(employeesRepositoryProvider);
    if (!await watchForemanScope(ref)) return const [];
    return repository.list();
  }

  Future<Employee> addEmployee({
    required String name,
    required WorkerRole role,
    required String email,
    required String phone,
    required int workStartHour,
    required int workEndHour,
    required Set<int> workingDays,
    double? latitude,
    double? longitude,
  }) async {
    final created = await _repository.create(
      Employee(
        id: '',
        name: name,
        role: role,
        email: email,
        phone: phone,
        workStartHour: workStartHour,
        workEndHour: workEndHour,
        workingDays: workingDays,
        latitude: latitude,
        longitude: longitude,
      ),
    );
    _upsert(created);
    unawaited(
      ref
          .read(foremanWorkflowProgressProvider.notifier)
          .markComplete(ForemanWorkflowStep.addEmployee),
    );
    return created;
  }

  /// A null [latitude], [longitude] or [isActive] keeps the current value.
  Future<Employee> updateEmployee({
    required String id,
    required String name,
    required WorkerRole role,
    required String email,
    required String phone,
    required int workStartHour,
    required int workEndHour,
    required Set<int> workingDays,
    double? latitude,
    double? longitude,
    bool? isActive,
  }) async {
    final base =
        findById(id) ??
        Employee(
          id: id,
          name: name,
          role: role,
          email: email,
          phone: phone,
          workStartHour: workStartHour,
          workEndHour: workEndHour,
          workingDays: workingDays,
        );
    final updated = await _repository.update(
      base.copyWith(
        name: name,
        role: role,
        email: email,
        phone: phone,
        workStartHour: workStartHour,
        workEndHour: workEndHour,
        workingDays: workingDays,
        latitude: latitude,
        longitude: longitude,
        isActive: isActive,
      ),
    );
    _upsert(updated);
    return updated;
  }

  /// Puts [employee] into the list in place of the one with its id. If the
  /// list has not loaded yet, reloads it instead; the reload includes
  /// [employee].
  void _upsert(Employee employee) {
    final current = state.value;
    if (current == null) return ref.invalidateSelf();
    final index = current.indexWhere((e) => e.id == employee.id);
    state = AsyncData(
      index < 0 ? [...current, employee] : ([...current]..[index] = employee),
    );
  }

  Employee? findById(String id) {
    for (final employee in state.value ?? const <Employee>[]) {
      if (employee.id == id) return employee;
    }
    return null;
  }
}
